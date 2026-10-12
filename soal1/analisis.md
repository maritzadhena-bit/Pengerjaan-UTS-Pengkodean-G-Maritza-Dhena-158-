# Analisis Audit Trail dan Normalisasi Jurnal

## 1. Perbandingan model flat dan header-line dari sisi audit trail

Pada model **flat journal table**, setiap baris debit atau kredit menyimpan ulang informasi transaksi yang sama, seperti nomor voucher/bukti, tanggal, deskripsi, status posting, pengguna, dan waktu. Jika satu voucher memiliki beberapa baris akun, informasi header tersebut berulang pada setiap baris. Pengulangan ini mempersulit pemeriksaan konsistensi dan membuka peluang sebagian baris memiliki status atau nomor bukti yang berbeda.

Pada model **header-line**, `journal_headers` menyimpan satu identitas voucher (`journal_id`), nomor bukti, tanggal transaksi, deskripsi, status posting, serta informasi audit pada tingkat transaksi. `journal_lines` menyimpan akun dan nilai debit/kredit per baris, serta mengacu ke satu header melalui foreign key. Dengan demikian, auditor dapat menelusuri satu voucher beserta seluruh baris double-entry-nya melalui relasi yang jelas.

| Aspek audit | Tabel flat | Model header-line |
|---|---|---|
| Identitas voucher | `journal_id` atau identitas transaksi diulang pada setiap baris; duplikasi dapat menimbulkan ketidakkonsistenan. | Satu `journal_id` di header mengidentifikasi voucher; setiap baris terkait melalui foreign key. |
| Nomor bukti | Nomor bukti berulang pada baris debit dan kredit sehingga perubahan harus diterapkan konsisten. | `reference_no` disimpan sekali pada header dan berlaku untuk semua baris voucher. |
| Status posting | Status berulang dan dapat berbeda antarbaris, sehingga sulit memastikan seluruh voucher memiliki status yang sama. | Satu `posting_status` pada header mewakili status voucher secara keseluruhan. |
| Jejak pengguna dan waktu | Informasi pembuat dapat berulang per baris dan tidak selalu menunjukkan siapa yang membuat atau mem-posting voucher. | `created_by` dan `created_at` ditempatkan pada header untuk merekam pembuatan voucher. Untuk jejak posting lengkap, tambahkan `posted_by` dan `posted_at` yang dicatat saat transisi ke status `POSTED`. |
| Reversal/void | Penanda atau referensi pembalik dapat berulang dan berisiko tidak konsisten pada baris-baris voucher. | Reversal/void dapat dicatat pada tingkat voucher, misalnya dengan status/metadata void serta `reversal_of_journal_id` yang menunjuk voucher asal; voucher asal tetap dipertahankan. |

Pemisahan ini membuat audit trail lebih mudah ditelusuri dan mengurangi risiko perubahan parsial. Namun, pemisahan tabel saja tidak otomatis mencatat seluruh riwayat perubahan: untuk audit yang kuat, sistem juga perlu membatasi perubahan setelah posting dan mencatat aktor serta waktu posting, void, atau reversal. Pada DDL saat ini, `created_by` dan `created_at` mencatat pembuatan; data khusus posting dan reversal/void belum dimodelkan.

## 2. Bentuk normal ketiga (3NF) dan anomali

### Ketergantungan dan pelanggaran pada model flat

Misalkan setiap baris pada tabel flat memiliki `line_id` sebagai primary key sekaligus menyimpan `journal_id`, `trx_date`, `reference_no`, `description`, dan `posting_status`. Atribut header secara semantik ditentukan oleh identitas voucher: `journal_id → trx_date, reference_no, description, posting_status`. Karena `journal_id` bukan key tabel flat, atribut-atribut tersebut bergantung pada `line_id` secara transitif melalui `journal_id` (`line_id → journal_id → atribut header`). Ini melanggar 3NF. Jika tabel flat juga mengulang nama atau klasifikasi akun, ketergantungan `account_id → account_name, report_classification` menimbulkan redundansi serupa.

### Anomali yang dapat terjadi

- **Anomali update:** perubahan tanggal, nomor bukti, atau status harus diperbarui pada setiap baris voucher. Jika satu baris terlewat, satu voucher dapat memiliki informasi header yang saling bertentangan.
- **Anomali insert:** header voucher belum dapat direkam secara mandiri sebelum baris detail tersedia; atau informasi voucher harus disalin ke setiap baris saat transaksi dimasukkan.
- **Anomali delete:** menghapus baris terakhir suatu voucher sekaligus menghilangkan satu-satunya salinan informasi header transaksi tersebut.

### Cara header-line memenuhi 3NF

Dalam model header-line, atribut yang bergantung pada `journal_id` disimpan satu kali di `journal_headers`. Atribut baris—`journal_id`, `account_id`, `debit`, dan `credit`—disimpan di `journal_lines`, sedangkan atribut akun dikelola di `chart_of_accounts`. Setiap kelompok atribut bergantung pada key tabelnya sendiri, mengurangi duplikasi dan mencegah ketergantungan transitif lintas-level. Header dapat dibuat atau diperiksa tanpa menggandakan atributnya pada setiap baris, dan penghapusan baris detail tidak menghapus header secara otomatis. Foreign key menjaga agar setiap baris tetap terhubung ke header dan akun yang valid.

## 3. Kesimpulan: constraint pada level database

Pemisahan header-line memperjelas identitas voucher, hubungan antarbaris, kepemilikan status, dan lokasi data audit; normalisasi juga mengurangi anomali akibat duplikasi. Akan tetapi, rancangan tabel saja belum menjamin setiap jurnal seimbang. Constraint harus ditegakkan di PostgreSQL agar semua jalur akses—termasuk API dan proses langsung ke database, bukan hanya UI—mengikuti aturan yang sama. `NOT NULL`, primary key, foreign key, serta `CHECK` dapat menjaga kelengkapan referensi dan validitas nilai debit/kredit per baris. Persyaratan total debit sama dengan total kredit adalah aturan lintas-baris, sehingga perlu divalidasi secara atomik saat posting, misalnya melalui prosedur posting atau constraint trigger yang sesuai. Dengan begitu, jurnal yang tidak seimbang tidak dapat berstatus `POSTED`, sementara seluruh detail tetap dapat ditelusuri sebagai audit trail.
