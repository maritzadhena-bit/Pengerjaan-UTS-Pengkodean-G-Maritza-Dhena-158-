"""API prototipe untuk posting voucher kas keluar dan membuat jurnal pembalik.

Memerlukan FastAPI, psycopg (v3), dan DATABASE_URL yang menunjuk ke PostgreSQL.
Identitas pengguna pada request sebaiknya diisi dari autentikasi server, bukan
dipercayai langsung dari input klien pada sistem produksi.

Reversing entry mempertahankan voucher POSTED asli sebagai jejak yang tidak
berubah dan membukukan dampak koreksi sebagai voucher baru dengan debit/kredit
tertukar. SHA-256 mendeteksi perubahan payload jika checksum yang tersimpan
dapat dipercaya; checksum bukan tanda tangan digital dan tidak mencegah aktor
yang dapat mengubah data sekaligus checksum. Audit trail lengkap juga memerlukan
identitas terautentikasi, stempel waktu, riwayat posting/reversal, kontrol akses,
retensi, serta bukti dan persetujuan yang diwajibkan kebijakan entitas.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from datetime import date, datetime
from decimal import Decimal
from typing import Any

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from psycopg.rows import dict_row


app = FastAPI(title="Voucher Kas Keluar API", version="1.0.0")


class LockRequest(BaseModel):
    posted_by: str = Field(min_length=1, max_length=100)


class ReverseRequest(BaseModel):
    trx_date: date
    reference_no: str = Field(min_length=1, max_length=50)
    created_by: str = Field(min_length=1, max_length=100)
    posted_by: str = Field(min_length=1, max_length=100)


def _database_url() -> str:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise HTTPException(status_code=503, detail="DATABASE_URL belum dikonfigurasi")
    return database_url


def _as_iso(value: date | datetime) -> str:
    """Serialisasi tanggal/waktu yang konsisten untuk payload checksum."""
    return value.isoformat()


def hash_checksum(
    header: dict[str, Any],
    lines: list[dict[str, Any]],
    posted_by: str,
    posted_at: datetime,
) -> str:
    """Buat fingerprint SHA-256 dari data header dan baris jurnal kanonis."""
    canonical_lines = [
        {
            "account_id": int(line["account_id"]),
            "debit": format(Decimal(line["debit"]), ".2f"),
            "credit": format(Decimal(line["credit"]), ".2f"),
        }
        for line in lines
    ]
    payload = {
        "journal_id": int(header["journal_id"]),
        "trx_date": _as_iso(header["trx_date"]),
        "reference_no": header["reference_no"],
        "description": header["description"],
        "created_by": header["created_by"],
        "created_at": _as_iso(header["created_at"]),
        "posting_status": "POSTED",
        "posted_by": posted_by,
        "posted_at": _as_iso(posted_at),
        "reversal_of_journal_id": header.get("reversal_of_journal_id"),
        "lines": canonical_lines,
    }
    serialized = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(serialized).hexdigest()


def _fetch_lines(conn: psycopg.Connection[Any], journal_id: int) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT line_id, account_id, debit, credit
          FROM journal_lines
         WHERE journal_id = %s
         ORDER BY line_id
        """,
        (journal_id,),
    ).fetchall()
    return [
        {
            "line_id": row["line_id"],
            "account_id": row["account_id"],
            "debit": row["debit"],
            "credit": row["credit"],
        }
        for row in rows
    ]


def _require_balanced(lines: list[dict[str, Any]]) -> None:
    if not lines:
        raise HTTPException(status_code=422, detail="Jurnal tidak memiliki baris")
    total_debit = sum((Decimal(line["debit"]) for line in lines), Decimal("0"))
    total_credit = sum((Decimal(line["credit"]) for line in lines), Decimal("0"))
    if total_debit <= 0 or total_debit != total_credit:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "Total debit harus sama dengan total kredit dan lebih besar dari nol",
                "total_debit": str(total_debit),
                "total_credit": str(total_credit),
            },
        )


@app.post("/journals/{journal_id}/lock")
def lock_posted_journal(journal_id: int, request: LockRequest) -> dict[str, Any]:
    """Validasi dan posting DRAFT secara atomik; setelah itu trigger mengunci data."""
    try:
        with psycopg.connect(_database_url(), row_factory=dict_row) as conn:
            header = conn.execute(
                """
                SELECT journal_id, trx_date, reference_no, description,
                       posting_status, created_by, created_at, reversal_of_journal_id
                  FROM journal_headers
                 WHERE journal_id = %s
                 FOR UPDATE
                """,
                (journal_id,),
            ).fetchone()
            if header is None:
                raise HTTPException(status_code=404, detail="Voucher tidak ditemukan")
            if header["posting_status"] != "DRAFT":
                raise HTTPException(
                    status_code=409,
                    detail="Hanya voucher DRAFT yang dapat diposting/dikunci",
                )

            lines = _fetch_lines(conn, journal_id)
            _require_balanced(lines)
            posted_by = request.posted_by.strip()
            if not posted_by:
                raise HTTPException(status_code=422, detail="posted_by tidak boleh kosong")
            posted_at = conn.execute(
                "SELECT CURRENT_TIMESTAMP AS posted_at"
            ).fetchone()["posted_at"]
            checksum = hash_checksum(header, lines, posted_by, posted_at)
            updated = conn.execute(
                """
                UPDATE journal_headers
                   SET posting_status = 'POSTED',
                       posted_by = %s,
                       posted_at = %s,
                       hash_checksum = %s
                 WHERE journal_id = %s
                   AND posting_status = 'DRAFT'
                RETURNING journal_id, posting_status, posted_by, posted_at, hash_checksum
                """,
                (posted_by, posted_at, checksum, journal_id),
            ).fetchone()
            if updated is None:
                raise HTTPException(status_code=409, detail="Status voucher berubah; coba ulangi")
            return dict(updated)
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail="Operasi database gagal") from exc


@app.post("/journals/{journal_id}/reverse", status_code=201)
def create_reversing_entry(
    journal_id: int,
    request: ReverseRequest,
) -> dict[str, Any]:
    """Buat voucher baru POSTED dengan debit/kredit sumber yang dibalik."""
    try:
        with psycopg.connect(_database_url(), row_factory=dict_row) as conn:
            original = conn.execute(
                """
                SELECT journal_id, trx_date, reference_no, description,
                       posting_status, created_by, created_at, reversal_of_journal_id
                  FROM journal_headers
                 WHERE journal_id = %s
                 FOR UPDATE
                """,
                (journal_id,),
            ).fetchone()
            if original is None:
                raise HTTPException(status_code=404, detail="Voucher asal tidak ditemukan")
            if original["posting_status"] != "POSTED":
                raise HTTPException(
                    status_code=409,
                    detail="Hanya voucher POSTED yang dapat dibuatkan jurnal pembalik",
                )

            original_lines = _fetch_lines(conn, journal_id)
            _require_balanced(original_lines)

            # Draft dibentuk dahulu agar baris reversal dapat dimasukkan sebelum diposting.
            created_by = request.created_by.strip()
            posted_by = request.posted_by.strip()
            reference_no = request.reference_no.strip()
            if not created_by or not posted_by or not reference_no:
                raise HTTPException(
                    status_code=422,
                    detail="Nomor bukti, created_by, dan posted_by tidak boleh kosong",
                )

            reversal_header = conn.execute(
                """
                INSERT INTO journal_headers (
                    trx_date, reference_no, description, posting_status,
                    created_by, created_at, reversal_of_journal_id
                )
                VALUES (%s, %s, %s, 'DRAFT', %s, CURRENT_TIMESTAMP, %s)
                RETURNING journal_id, trx_date, reference_no, description,
                          created_by, created_at, reversal_of_journal_id
                """,
                (
                    request.trx_date,
                    reference_no,
                    f"Jurnal pembalik voucher {journal_id}: {original['description']}",
                    created_by,
                    journal_id,
                ),
            ).fetchone()

            # Setiap debit sumber menjadi kredit reversal dan sebaliknya.
            reversed_lines = [
                {
                    "account_id": line["account_id"],
                    "debit": line["credit"],
                    "credit": line["debit"],
                }
                for line in original_lines
            ]
            conn.executemany(
                """
                INSERT INTO journal_lines (journal_id, account_id, debit, credit)
                VALUES (%s, %s, %s, %s)
                """,
                [
                    (
                        reversal_header["journal_id"],
                        line["account_id"],
                        line["debit"],
                        line["credit"],
                    )
                    for line in reversed_lines
                ],
            )
            _require_balanced(reversed_lines)
            posted_at = conn.execute(
                "SELECT CURRENT_TIMESTAMP AS posted_at"
            ).fetchone()["posted_at"]
            checksum = hash_checksum(
                reversal_header,
                reversed_lines,
                posted_by,
                posted_at,
            )
            posted = conn.execute(
                """
                UPDATE journal_headers
                   SET posting_status = 'POSTED',
                       posted_by = %s,
                       posted_at = %s,
                       hash_checksum = %s
                 WHERE journal_id = %s
                   AND posting_status = 'DRAFT'
                RETURNING journal_id, posting_status, posted_by, posted_at,
                          hash_checksum, reversal_of_journal_id
                """,
                (
                    posted_by,
                    posted_at,
                    checksum,
                    reversal_header["journal_id"],
                ),
            ).fetchone()
            if posted is None:
                raise HTTPException(status_code=409, detail="Jurnal pembalik gagal diposting")
            return dict(posted)
    except psycopg.errors.UniqueViolation as exc:
        raise HTTPException(
            status_code=409,
            detail="Voucher ini sudah memiliki jurnal pembalik",
        ) from exc
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail="Operasi database gagal") from exc


@app.get("/journals/{journal_id}/verify-checksum")
def verify_journal_checksum(journal_id: int) -> dict[str, Any]:
    """Bandingkan checksum tersimpan dengan fingerprint payload jurnal saat ini."""
    try:
        with psycopg.connect(_database_url(), row_factory=dict_row) as conn:
            header = conn.execute(
                """
                SELECT journal_id, trx_date, reference_no, description,
                       posting_status, created_by, created_at,
                       posted_by, posted_at, hash_checksum, reversal_of_journal_id
                  FROM journal_headers
                 WHERE journal_id = %s
                """,
                (journal_id,),
            ).fetchone()
            if header is None:
                raise HTTPException(status_code=404, detail="Voucher tidak ditemukan")
            if header["posting_status"] != "POSTED":
                raise HTTPException(
                    status_code=409,
                    detail="Checksum hanya tersedia untuk voucher POSTED",
                )

            lines = _fetch_lines(conn, journal_id)
            computed = hash_checksum(
                header,
                lines,
                header["posted_by"],
                header["posted_at"],
            )
            stored_checksum = (header["hash_checksum"] or "").strip()
            matches = hmac.compare_digest(computed, stored_checksum)
            return {
                "journal_id": journal_id,
                "checksum_valid": matches,
                "stored_checksum": stored_checksum,
                "computed_checksum": computed,
            }
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail="Operasi database gagal") from exc