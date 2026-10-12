# UTS Coding Akuntansi — FEB Universitas Diponegoro

[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Python](https://img.shields.io/badge/Language-Python-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Streamlit](https://img.shields.io/badge/UI-Streamlit-FF4B4B?logo=streamlit&logoColor=white)](https://streamlit.io/)
[![FastAPI](https://img.shields.io/badge/API-FastAPI-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)

Repositori Ujian Tengah Semester untuk mata kuliah Pemrograman/Coding Akuntansi, Program Studi S1 Akuntansi, Fakultas Ekonomika dan Bisnis, Universitas Diponegoro.

| Identitas | Keterangan |
|---|---|
| Nama | **[ISI NAMA]** |
| NIM | **[ISI NIM]** |
| Kelas | **[ISI KELAS]** |
| Dosen | Totok Dewayanto |
| Tanggal ujian | 19 Oktober 2026 |

> Ganti placeholder identitas dan tautan sebelum memublikasikan repositori.

## Deskripsi

Proyek ini membahas perancangan skema General Ledger dengan model header-line, otomasi mutasi persediaan menggunakan PostgreSQL trigger, serta purwarupa formulir Voucher Kas Keluar berbasis Streamlit. Backend FastAPI menyediakan alur posting, reversal, dan verifikasi checksum untuk mendukung jejak audit. Proyek bersifat akademik dan belum ditujukan untuk penggunaan produksi.

## Daftar Soal

| Soal | Ringkasan |
|---|---|
| **Soal 1 — Desain Arsitektur Data** | Merancang ERD dan DDL PostgreSQL untuk Chart of Accounts, journal headers, dan journal lines serta menganalisis 3NF dan audit trail. |
| **Soal 2 — Otomasi Bisnis & Trigger** | Memutakhirkan stok secara transaksional dan membahas pencegahan overselling dengan row-level lock serta `SERIALIZABLE`. |
| **Soal 3 — Web Full-Stack & AI** | Membuat formulir jurnal Streamlit, catatan verifikasi PSAK, dan backend audit FastAPI dengan reversal serta SHA-256. |

## Struktur Repositori

```text
UTS-Coding-Akuntansi/
├── README.md
├── jawaban_final.md
├── soal1/
│   ├── ddl.sql
│   ├── erd.mermaid
│   └── analisis.md
├── soal2/
│   ├── trigger.sql
│   ├── test_trigger.sql
│   └── concurrency.md
└── soal3/
    ├── frontend/
    │   └── app.py
    ├── backend/
    │   ├── main.py
    │   └── audit_lock.sql
    ├── prompt_ai.md
    └── psak_verification.md
```

- **Root:** README petunjuk proyek dan laporan jawaban akhir.
- **`soal1/`:** ERD, DDL, dan analisis desain relasional.
- **`soal2/`:** trigger mutasi persediaan, skrip uji, dan pembahasan concurrency.
- **`soal3/frontend/`:** formulir Streamlit untuk Voucher Kas Keluar.
- **`soal3/backend/`:** API FastAPI, checksum, serta trigger audit lock.
- **Berkas dokumentasi Soal 3:** prompt AI dan catatan verifikasi PSAK.

## Teknologi

- **PostgreSQL** — database relasional, PL/pgSQL trigger, dan kontrol transaksi.
- **Python** — bahasa untuk antarmuka dan backend.
- **Streamlit** — purwarupa UI formulir jurnal.
- **FastAPI** — endpoint backend untuk posting, reversing entry, dan pemeriksaan checksum.
- **Gemini Canvas** dan **NotebookLM** — alat bantu AI yang dicantumkan untuk proses desain UI dan telaah sumber; lihat [dokumentasi prompt](soal3/prompt_ai.md) serta pastikan atribusi sesuai riwayat penggunaan aktual.
- **Neon.tech** — sandbox PostgreSQL yang dapat digunakan untuk menjalankan skrip database.

## Cara Menjalankan

### 1. Siapkan PostgreSQL Sandbox di Neon

1. Buat proyek PostgreSQL pada [Neon](https://neon.tech/).
2. Salin connection string dari dashboard Neon. Simpan sebagai rahasia lokal pada `DATABASE_URL`; jangan commit connection string, password, atau token ke GitHub.
3. Pastikan Anda bekerja pada database uji yang benar. Untuk menjalankan SQL dapat menggunakan `psql` atau ekstensi SQLTools di VS Code yang terhubung ke database Neon.

Contoh mengatur variabel koneksi di Bash:

```bash
export DATABASE_URL="<connection-string-Neon>"
```

Di Windows PowerShell:

```powershell
$env:DATABASE_URL = "<connection-string-Neon>"
```

### 2. Jalankan DDL dan trigger

Jalankan skrip General Ledger secara berurutan:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f soal1/ddl.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f soal3/backend/audit_lock.sql
```

Dengan SQLTools, buka setiap berkas SQL, pilih koneksi Neon yang benar, lalu jalankan skrip dari editor. Jalankan `soal1/ddl.sql` sebelum `soal3/backend/audit_lock.sql`.

Trigger persediaan mengharapkan tabel `inventory_items` dan `inventory_transactions`. Skema tersebut berasal dari spesifikasi soal dan belum menjadi berkas DDL terpisah di repositori. Buat tabel berikut terlebih dahulu:

```sql
CREATE TABLE inventory_items (
    item_id VARCHAR(10) PRIMARY KEY,
    item_name VARCHAR(100),
    stock_qty INTEGER NOT NULL DEFAULT 0,
    unit_cost NUMERIC(15, 2) NOT NULL
);

CREATE TABLE inventory_transactions (
    trx_id SERIAL PRIMARY KEY,
    item_id VARCHAR(10) REFERENCES inventory_items(item_id),
    trx_type VARCHAR(10)
        CHECK (trx_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT')),
    qty INTEGER NOT NULL,
    trx_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Setelah itu, pasang trigger dan jalankan skrip uji:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f soal2/trigger.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f soal2/test_trigger.sql
```

> `test_trigger.sql` membuat data sementara untuk pengujian. Jalankan hanya pada database uji.

### 3. Jalankan Streamlit

Dari root repositori:

```bash
python -m venv .venv
```

Aktifkan virtual environment:

```bash
# Linux/macOS
source .venv/bin/activate

# Windows PowerShell
.venv\Scripts\Activate.ps1
```

Pasang dependensi dan mulai aplikasi:

```bash
python -m pip install streamlit pandas
streamlit run soal3/frontend/app.py
```

Formulir menyediakan validasi keseimbangan di UI. Tombol submit saat ini hanya menampilkan konfirmasi dan **belum mengirim atau menyimpan voucher ke backend/database**.

### 4. Jalankan FastAPI

Pasang dependensi backend:

```bash
python -m pip install fastapi "uvicorn[standard]" "psycopg[binary]"
```

Pastikan `DATABASE_URL` sudah diatur seperti pada langkah Neon, kemudian jalankan dari root proyek:

```bash
uvicorn soal3.backend.main:app --reload
```

Dokumentasi interaktif tersedia di [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). Endpoint prototipe:

- `POST /journals/{journal_id}/lock` — memvalidasi dan mem-posting voucher `DRAFT`.
- `POST /journals/{journal_id}/reverse` — membuat jurnal pembalik dengan debit dan kredit ditukar.
- `GET /journals/{journal_id}/verify-checksum` — membandingkan checksum dengan data jurnal saat ini.

API menggunakan tabel jurnal yang dibuat oleh dua skrip General Ledger. Voucher `DRAFT` harus sudah tersedia dan berisi baris jurnal karena endpoint pembuatan voucher belum diimplementasikan. Untuk penggunaan nyata, identitas pengguna harus berasal dari autentikasi server dan akses endpoint harus diotorisasi.

## Referensi

- Ikatan Akuntan Indonesia, [Informasi Standar Akuntansi Keuangan (SAK)](https://web.iaiglobal.or.id/SAK-IAI) — rujuk PSAK 2 edisi resmi yang berlaku.
- PostgreSQL, [Dokumentasi resmi](https://www.postgresql.org/docs/).
- PostgreSQL, [Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html).
- PostgreSQL, [Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html).
- Streamlit, [Dokumentasi resmi](https://docs.streamlit.io/).
- FastAPI, [Dokumentasi resmi](https://fastapi.tiangolo.com/).

## Author

- **Nama:** [Maritza Dhena Alifya]
- **NIM:** [12030124130158]
- **GitHub:** [ISI LINK GITHUB]

## Catatan Proyek

Lengkapi placeholder identitas sebelum publikasi. Tambahkan screenshot hasil uji hanya setelah pengujian benar-benar dilakukan dan pastikan gambar tidak memuat kredensial atau data pribadi. DDL saat ini membatasi nilai setiap baris jurnal, tetapi belum menegakkan keseimbangan total debit-kredit lintas baris sebagai constraint database. SHA-256 membantu mendeteksi perubahan data, tetapi bukan pengganti kontrol akses dan audit log independen.
