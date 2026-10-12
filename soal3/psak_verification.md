Berikut adalah ringkasan dan analisis verifikasi kepatuhan sistem modul **"Voucher Entri Transaksi Kas Keluar"** terhadap **PSAK 2 (Laporan Arus Kas)** dan **Kerangka Konseptual Pelaporan Keuangan**.

---

### **1. Logika Double-Entry dan Aturan Immutability Status POSTED**

**Penilaian Kepatuhan: Sesuai dengan Kerangka Konseptual & PSAK 2**

* **Prinsip Double-Entry (Total Debit = Total Kredit):**
  Dalam akuntansi, setiap transaksi yang memengaruhi kas dan setara kas diakui dan diukur berdasarkan mutasi pasangan akunnya. Logika pembatasan keseimbangan Debit = Kredit memastikan bahwa setiap pengeluaran kas (kredit pada kas/bank) diimbangi oleh pengakuan beban, pelunasan liabilitas, atau perolehan aset lain secara tepat di posisi debit.
* **Status POSTED Tidak Boleh Diubah/Dihapus (Harus Melalui Reversing Entry):**
  Penerapan aturan ini sangat sejalan dengan karakteristik kualitatif **Representasi Tepat (*Faithful Representation*)** dan **Keterverifikasian (*Verifiability*)** pada **Kerangka Konseptual Pelaporan Keuangan Paragraf 2.13 & 2.30**. Laporan keuangan yang andal harus bebas dari manipulasi dan kesalahan material. Penghapusan atau pengubahan langsung transaksi yang telah dibukukan (*posted*) akan merusak jejak audit. Mekanisme jurnal pembalik (*reversing entry/storno*) menjaga transparansi penyajian secara wajar (*fair presentation*) sesuai PSAK 1/PSAK 201 Paragraf 15.

**Rekomendasi / Potensi Ketidaksesuaian di Level Sistem:**
Meskipun logika dasar *double-entry* sudah benar secara pembukuan umum, **modul voucher kas keluar belum sepenuhnya memenuhi kebutuhan PSAK 2 jika hanya memvalidasi Total Debit = Total Kredit.**
* **Perbaikan:** Untuk dapat menyajikan Laporan Arus Kas sesuai PSAK 2, sistem harus menambahkan **atribut metadata/tagging aktivitas arus kas** pada formulir entri voucher (apakah transaksi tersebut masuk kategori *Aktivitas Operasi, Investasi,* atau *Pendanaan*).

---

### **2. Definisi dan Kriteria Kas & Setara Kas Menurut PSAK 2**

Berdasarkan **PSAK 2 Paragraf 06** (dan PSAK 207), definisi serta kriteria kas dan setara kas adalah sebagai berikut:

* **Definisi Kas (*Cash*):**
  Terdiri atas saldo kas di tangan (*cash on hand*) dan rekening giro (*demand deposits*).
* **Definisi Setara Kas (*Cash Equivalent*):**
  Investasi yang sifatnya sangat likuid, berjangka pendek, dan dengan cepat dapat dikonversi menjadi kas dalam jumlah tertentu yang dapat ditentukan tanpa menghadapi risiko perubahan nilai yang signifikan.

**Kriteria Setara Kas yang Harus Dipenuhi (PSAK 2 Paragraf 06–07):**
1. **Tujuan Kepemilikan:** Dimiliki khusus untuk memenuhi komitmen kas jangka pendek, bukan untuk tujuan investasi jangka panjang atau tujuan lainnya.
2. **Kemudahan Konversi:** Harus dapat segera diubah menjadi kas dalam jumlah yang diketahui.
3. **Jatuh Tempo Singkat:** Suatu investasi umumnya memenuhi syarat sebagai setara kas hanya jika segera akan jatuh tempo dalam waktu **3 (tiga) bulan atau kurang** dari tanggal perolehannya.
4. **Risiko Rendah:** Tidak menghadapi risiko perubahan nilai atau perubahan suku bunga yang signifikan.

*(Catatan khusus: Cerukan/bank overdraft yang dapat ditarik sewaktu-waktu dan menjadi bagian integral dari pengelolaan kas entitas juga dapat dimasukkan sebagai komponen kas dan setara kas).*

---

### **3. Aturan Khusus Pencatatan Transaksi Kas Keluar dalam Sistem**

Dalam merancang modul transaksi kas keluar berbasis web, terdapat beberapa aturan khusus dalam **PSAK 2** yang wajib diperhatikan oleh sistem:

1. **Pengklasifikasian Tiga Aktivitas Utama (PSAK 2 Paragraf 10, 12, 17):**
   Setiap entri kas keluar harus dipetakan ke salah satu dari tiga klasifikasi arus kas:
   * **Aktivitas Operasi:** Pengeluaran untuk kas operasional utama, seperti pembayaran kepada pemasok barang/jasa, pembayaran gaji karyawan, pembayaran bunga, serta pembayaran pajak penghasilan.
   * **Aktivitas Investasi:** Pengeluaran kas untuk memperoleh aset tetap, aset tidak berwujud, atau aset jangka panjang lainnya, serta pembelian instrumen ekuitas/utang entitas lain.
   * **Aktivitas Pendanaan:** Pengeluaran kas kepada pemilik (misalnya dividen/penarikan saham), pelunasan pokok pinjaman/utang jangka panjang, dan pembayaran liabilitas sewa pembiayaan (*finance lease*).
2. **Prinsip Pencatatan Jumlah Bruto (PSAK 2 Paragraf 21):**
   Sistem harus mencatat pengeluaran kas sebesar nilai **bruto** (*gross cash flows*) dan tidak memperkenankan saling-hapus (*netting*) dengan penerimaan kas, kecuali untuk pos-pos tertentu berperputaran cepat dengan jumlah besar dan jangka pendek.
3. **Pemisahan Transaksi Non-Kas (PSAK 2 Paragraf 43):**
   Sistem harus memastikan bahwa transaksi yang tidak melibatkan kas aktual (misalnya pembelian aset tetap dengan menerbitkan utang/saham) **dikeluarkan dari perhitungan arus kas** dan disajikan terpisah dalam pengungkapan laporan keuangan.
4. **Pencatatan Pajak Penghasilan (PSAK 2 Paragraf 35):**
   Pengeluaran kas untuk pajak penghasilan wajib disajikan terpisah dan diklasifikasikan sebagai aktivitas operasi, kecuali dapat diidentifikasikan secara spesifik ke aktivitas investasi atau pendanaan.

---

### **4. Evaluasi Praktik Audit Trail terhadap Prinsip Keterlacakan (*Traceability*)**

**Penilaian Kepatuhan: Sangat Sejalan dengan Kerangka Konseptual Pelaporan Keuangan**

Praktik penggunaan atribut `created_by`, `created_at`, dan `hash_checksum` sangat sejalan dengan standar akuntansi dan kerangka pelaporan keuangan:

* **Keterverifikasian (*Verifiability* - Kerangka Konseptual Paragraf 2.30–2.31):**
  Keterverifikasian berarti pengobservasi independen dapat mencapai konsensus bahwa penggambaran transaksi merupakan representasi tepat. Verifikasi tidak langsung (*indirect verification*) dilakukan dengan memeriksa input data, metodologi, dan log sejarah transaksi. Atribut `created_by` dan `created_at` menyediakan jejak audit kronologis yang dapat diverifikasi secara tidak langsung.
* **Penatagunaan Manajemen (*Stewardship* - Kerangka Konseptual Paragraf 1.13 & Bab 1):**
  Informasi akuntansi berfungsi untuk menilai pertanggungjawaban dan penatagunaan oleh manajemen (*stewardship*) atas sumber daya entitas. Penggunaan `created_by` menegaskan otorisasi dan akuntabilitas personal dalam entri data.
* **Ketepatwaktuan (*Timeliness* - Kerangka Konseptual Paragraf 2.33):**
  Pencatatan stempel waktu (`created_at`) menjamin bahwa data transaksi kas keluar dicatat dan tersedia secara tepat waktu sesuai periode kejadiannya.
* **Integritas Data dan Pengendalian Internal Kas (`hash_checksum`):**
  Kas merupakan aset yang paling likuid dan paling rentan terhadap risiko penyelewengan. Implementasi `hash_checksum` memastikan kekedapan data (*tamper-proof / tamper-evident*), sehingga mencegah perubahan data secara tidak sah di tingkat *database*. Hal ini mendukung pencapaian informasi yang **bebas dari kesalahan material** (*free from error*).

---

### **Ringkasan Catatan Evaluasi & Rekomendasi Sistem (`[link mencurigakan dihapus]`)**

| Komponen Logika Sistem | Status Kepatuhan PSAK / Kerangka Konseptual | Catatan & Rekomendasi Perbaikan |
| :--- | :--- | :--- |
| **Validasi Total Debit = Total Kredit** | **Sesuai** (*Dasar Pembukuan*) | Perlu ditambahkan field/kategori **Klasifikasi Arus Kas** (Operasi, Investasi, Pendanaan) pada formulir agar modul dapat menghasilkan laporan sesuai PSAK 2 Paragraf 10–17. |
| **Pencegahan Edit/Hapus Status POSTED (Jurnal Pembalik)** | **Sesuai** (*PSAK 1 & KK Paragraf 2.13*) | Menjamin *Faithful Representation* dan keandalan data transaksi. |
| **Audit Trail (`created_by`, `created_at`, `hash_checksum`)** | **Sesuai** (*KK Paragraf 2.30–2.31*) | Memenuhi kriteria *Verifiability*, *Timeliness*, *Stewardship*, dan Pengendalian Internal Aset Likuid. |

---
