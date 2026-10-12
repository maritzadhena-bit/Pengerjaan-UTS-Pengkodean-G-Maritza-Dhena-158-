"""Formulir Streamlit untuk entri Voucher Kas Keluar."""

import pandas as pd
import streamlit as st


st.set_page_config(page_title="Voucher Kas Keluar", layout="wide")
st.title("🧾 Voucher Kas Keluar")
st.caption("Isi informasi voucher dan rincian jurnal. Total debit harus sama dengan total kredit.")

# Header voucher.
header_left, header_right = st.columns(2)
with header_left:
    trx_date = st.date_input("Tanggal transaksi")
    reference_no = st.text_input("Nomor bukti")
with header_right:
    description = st.text_input("Deskripsi")

st.subheader("Detail jurnal")

# Baris awal kosong; pengguna dapat menambah atau menghapus baris dari editor.
if "journal_lines" not in st.session_state:
    st.session_state.journal_lines = pd.DataFrame(
        [
            {
                "account_id": "",
                "account_name": "",
                "debit": 0.0,
                "credit": 0.0,
            }
        ]
    )

edited_lines = st.data_editor(
    st.session_state.journal_lines,
    key="journal_lines_editor",
    num_rows="dynamic",
    use_container_width=True,
    hide_index=True,
    column_config={
        "account_id": st.column_config.TextColumn("Account ID"),
        "account_name": st.column_config.TextColumn("Nama akun"),
        "debit": st.column_config.NumberColumn(
            "Debit",
            min_value=0.0,
            step=0.01,
            format="%.2f",
        ),
        "credit": st.column_config.NumberColumn(
            "Kredit",
            min_value=0.0,
            step=0.01,
            format="%.2f",
        ),
    },
)
st.session_state.journal_lines = edited_lines

# Nilai kosong pada sel numerik diperlakukan sebagai nol untuk perhitungan.
debit_values = pd.to_numeric(edited_lines["debit"], errors="coerce").fillna(0)
credit_values = pd.to_numeric(edited_lines["credit"], errors="coerce").fillna(0)
total_debit = float(debit_values.sum())
total_credit = float(credit_values.sum())
difference = total_debit - total_credit
is_balanced = total_debit > 0 and abs(difference) < 0.005

# Metrik dan status diperbarui setiap kali editor berubah.
metric_debit, metric_credit, metric_difference = st.columns(3)
metric_debit.metric("Total Debit", f"Rp {total_debit:,.2f}")
metric_credit.metric("Total Kredit", f"Rp {total_credit:,.2f}")
metric_difference.metric("Selisih (Debit - Kredit)", f"Rp {difference:,.2f}")

if is_balanced:
    st.success("✅ Seimbang — voucher siap disubmit.")
else:
    st.error("❌ Belum seimbang — total debit dan kredit harus sama, serta lebih besar dari nol.")

if st.button("Submit Voucher", type="primary", disabled=not is_balanced):
    st.success(
        f"Voucher {reference_no or '(tanpa nomor bukti)'} berhasil divalidasi "
        f"untuk tanggal {trx_date:%d-%m-%Y}."
    )
    st.info("Formulir ini belum mengirim data ke backend atau menyimpannya ke database.")