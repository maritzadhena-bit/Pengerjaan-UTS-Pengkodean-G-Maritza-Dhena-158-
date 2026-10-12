# Dokumentasi Prompt AI — UTS Coding Akuntansi

## Pengantar

AI generatif digunakan sebagai alat bantu untuk menyusun rancangan, menghasilkan draf kode, dan merangkum bahan yang relevan dengan soal UTS. Prinsip **AI terpandu** diterapkan dengan memberikan konteks dan batasan yang jelas, memeriksa hasil terhadap kebutuhan soal dan struktur proyek, serta tidak menerima keluaran AI sebagai pengganti pemahaman, pengujian, atau verifikasi sumber resmi.

Tabel berikut merangkum tahap, tujuan prompt, berkas keluaran, dan tanggal permintaan yang tercatat pada riwayat pengerjaan. Atribusi tool dibedakan dari tool yang diminta sebagai alat bantu: pekerjaan coding dalam riwayat sesi ini dikerjakan menggunakan Copilot SDK di VS Code. Jika Gemini Canvas atau NotebookLM digunakan di luar riwayat ini, lampirkan bukti penggunaan dan sesuaikan atribusi berdasarkan riwayat aktual.

## Daftar Prompt dan Hasil

| No | Tahap | Prompt (ringkas) | Tool AI | Hasil | Tanggal |
|----|-------|------------------|---------|-------|---------|
| 1 | Soal 1.1 | Rancang ERD relasional tiga tabel General Ledger dengan kardinalitas, penjelasan relasi, dan alasan 3NF. | Copilot SDK di VS Code; Gemini **belum terverifikasi** | [`soal1/erd.mermaid`](../soal1/erd.mermaid), penjelasan pada [`soal1/analisis.md`](../soal1/analisis.md) | 13 Oktober 2026 |
| 2 | Soal 1.2 | Buat DDL PostgreSQL tiga tabel beserta PK, FK `RESTRICT`/`CASCADE`, CHECK debit-kredit, indeks, kolom audit, dan komentar constraint. | Copilot SDK di VS Code; Gemini **belum terverifikasi** | [`soal1/ddl.sql`](../soal1/ddl.sql) | 13 Oktober 2026 |
| 3 | Soal 1.3 | Bandingkan model Header-Line dan flat dari sisi audit trail, 3NF, anomali, serta constraint database. | Copilot SDK di VS Code; Gemini **belum terverifikasi** | [`soal1/analisis.md`](../soal1/analisis.md) | 13 Oktober 2026 |
| 4 | Soal 2.1 | Buat trigger PostgreSQL untuk mutasi stok, lock baris, menolak overselling, dan sertakan contoh uji. | Copilot SDK di VS Code; Gemini **belum terverifikasi** | [`soal2/trigger.sql`](../soal2/trigger.sql), [`soal2/test_trigger.sql`](../soal2/test_trigger.sql) | 13 Oktober 2026 |
| 5 | Soal 2.2 | Jelaskan race condition dan bandingkan contoh `SELECT ... FOR UPDATE` dengan isolasi `SERIALIZABLE`. | Copilot SDK di VS Code; Gemini **belum terverifikasi** | [`soal2/concurrency.md`](../soal2/concurrency.md) | 13 Oktober 2026 |
| 6 | Soal 3.1a | Buat formulir Streamlit Voucher Kas Keluar dengan editor baris dinamis, indikator saldo debit-kredit, dan validasi submit. | Copilot SDK di VS Code dalam riwayat proyek; Gemini Canvas **belum terverifikasi** | [`frontend/app.py`](./frontend/app.py) | 13 Oktober 2026 |
| 7 | Soal 3.1b | Verifikasi ringkasan PSAK 2 terkait kas/setara kas, klasifikasi arus kas, transaksi kas keluar, serta audit trail. | NotebookLM **sesuai alat yang dinyatakan; log prompt/sumber belum dilampirkan** | [`psak_verification.md`](./psak_verification.md) | Tidak tercatat; isi tanggal aktual |
| 8 | Soal 3.2 | Buat backend FastAPI untuk lock/posting, reversing entry, checksum SHA-256, dan trigger pelindung transaksi `POSTED`. | Copilot SDK di VS Code; Gemini **belum terverifikasi** | [`backend/main.py`](./backend/main.py), [`backend/audit_lock.sql`](./backend/audit_lock.sql) | 13 Oktober 2026 |

**Catatan tanggal:** tanggal 1–6 dan 8 menunjukkan tanggal permintaan pada riwayat sesi (WIB); jam yang lebih terperinci dapat dicatat dari riwayat chat asli jika diperlukan. Tanggal penggunaan NotebookLM tidak tersedia dalam catatan yang diperiksa dan harus diisi berdasarkan bukti aktual.

**Catatan tool:** PostgreSQL Sandbox (Neon.tech) adalah lingkungan untuk menjalankan SQL, bukan tool AI generatif. Catat sebagai lingkungan verifikasi apabila memang dipakai; jangan dicatat sebagai model pembuat prompt/kode. Riwayat proyek menyebut Copilot SDK sebagai tool untuk pekerjaan coding pada sesi ini, jadi baris berlabel Gemini harus dikoreksi bila tidak ada bukti penggunaan Gemini Canvas yang terpisah.

## Cuplikan Prompt UI (Soal 3.1a)

Berikut ringkasan prompt yang tercatat untuk pembuatan formulir:

> Buatkan kode Python Streamlit untuk formulir entri jurnal “Voucher Kas Keluar” dengan tanggal transaksi, nomor bukti, deskripsi, tabel dinamis `account_id`, `account_name`, `debit`, dan `credit`, debit/kredit minimum nol, total debit/kredit serta selisih real-time, indikator hijau jika seimbang dan merah jika tidak, serta tombol submit yang aktif hanya jika total debit sama dengan total kredit dan lebih besar dari nol. Gunakan wide layout, emoji secukupnya, dan komentar penjelasan.

Hasil merupakan draf UI dan tetap perlu ditinjau. Tombol submit pada implementasi saat ini hanya menampilkan pesan validasi; data belum dikirim atau disimpan ke backend.

## Refleksi Orkestrasi AI

Orkestrasi AI membantu memecah tugas besar menjadi tahap yang memiliki keluaran dan kriteria pemeriksaan tersendiri. Prompt dengan nama file, bentuk keluaran, serta batasan teknis yang jelas menghasilkan draf yang lebih mudah dibandingkan dengan kebutuhan UTS. Pemisahan tahap desain, DDL, trigger, concurrency, UI, dan backend juga memudahkan penelusuran hubungan antarkomponen.

Pelajaran pentingnya adalah keluaran AI tidak selalu konsisten dengan skema atau alat yang digunakan pada tahap lain. Karena itu, nama kolom, tipe data, transaksi database, dan klaim tool harus dicocokkan kembali dengan berkas proyek dan riwayat penggunaan. AI mempercepat pembuatan draf, tetapi keputusan akuntansi, keamanan, dan tanggung jawab atas hasil tetap berada pada mahasiswa.

## Catatan Verifikasi Hasil

### Pemeriksaan yang dilakukan

- Membandingkan keluaran terhadap ketentuan soal dan skema terkait, termasuk nama kolom serta hubungan foreign key.
- Memeriksa secara statis bahwa trigger persediaan menggunakan `SELECT ... FOR UPDATE`, dan meninjau contoh penjualan berlebih pada skrip uji.
- Meninjau bahwa backend memeriksa keseimbangan saat posting, reversal membalik debit/kredit, dan trigger audit melindungi header serta baris `POSTED`.
- Menyatakan batasan implementasi secara eksplisit: frontend belum tersambung ke backend; keseimbangan lintas-baris belum menjadi constraint dalam `soal1/ddl.sql`; trigger Soal 2 belum membuat jurnal Persediaan/HPP.

### Rencana uji di PostgreSQL Sandbox (Neon.tech)

1. Buat tabel `inventory_items` dan `inventory_transactions` sesuai spesifikasi soal.
2. Jalankan `soal2/trigger.sql`, lalu `soal2/test_trigger.sql`; pastikan pembelian/penjualan valid memperbarui stok dan penjualan berlebih menghasilkan exception tanpa perubahan stok.
3. Jalankan `soal1/ddl.sql`, kemudian `soal3/backend/audit_lock.sql` pada database uji yang masih kosong.
4. Siapkan akun dan voucher jurnal uji. Uji posting seimbang/tidak seimbang, upaya mengubah/menghapus header dan baris yang `POSTED`, pembuatan reversal, serta endpoint verifikasi checksum.
5. Simpan tangkapan layar hasil aktual pada folder `bukti/` dan catat versi PostgreSQL, waktu, serta hasil setiap uji.

**Status uji sandbox:** skrip SQL dan backend belum dieksekusi terhadap Neon/PostgreSQL dalam riwayat pengerjaan yang tercatat. Karena itu, langkah di atas adalah rencana verifikasi, bukan klaim bahwa uji telah berhasil. Lengkapi status dan bukti setelah eksekusi nyata.

**Bukti penggunaan alat:** [Lampirkan tangkapan layar/riwayat prompt Gemini Canvas dan NotebookLM, serta hasil query Neon jika digunakan. Hapus atau samarkan token, URL rahasia, dan data pribadi.]
