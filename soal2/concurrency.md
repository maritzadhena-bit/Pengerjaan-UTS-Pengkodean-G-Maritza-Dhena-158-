# Penanganan Concurrency pada Penjualan Persediaan

## Skenario race condition

Misalkan `inventory_items.stock_qty` untuk suatu barang bernilai 1. Dua kasir hampir bersamaan menjual masing-masing 1 unit. Tanpa pengamanan, keduanya dapat membaca stok awal 1 sebelum salah satunya memperbarui saldo, sehingga kedua transaksi diterima dan stok menjadi tidak sesuai. Ini merupakan race condition yang menyebabkan **overselling** atau phantom stock.

Tabel `inventory_transactions` dan trigger dari `trigger.sql` digunakan pada contoh. Trigger tersebut menerapkan mutasi stok dan menolak hasil stok negatif. Panggilan penjualan dan pembaruan stok harus berada pada satu transaksi database.

## 1. `SELECT ... FOR UPDATE` (row-level lock)

Kunci baris stok sebelum memeriksa kuantitas. Kasir kedua yang mengunci barang yang sama akan menunggu sampai transaksi pertama berakhir, lalu membaca saldo terbaru.

```sql
CREATE OR REPLACE PROCEDURE sell_item_for_update(
    p_item_id VARCHAR(10),
    p_qty INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock_qty inventory_items.stock_qty%TYPE;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Kuantitas penjualan harus lebih besar dari nol';
    END IF;

    SELECT stock_qty
      INTO v_stock_qty
      FROM inventory_items
     WHERE item_id = p_item_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = format('Item %s tidak ditemukan', p_item_id);
    END IF;

    IF v_stock_qty < p_qty THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = format(
                'Stok tidak cukup untuk item %s: tersedia %s, diminta %s',
                p_item_id,
                v_stock_qty,
                p_qty
            );
    END IF;

    -- Trigger inventory_transactions_update_stock mengurangi stok satu kali.
    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES (p_item_id, 'SALE', p_qty);
END;
$$;

-- Jalankan pada sesi kasir; commit melepaskan row lock.
BEGIN;
CALL sell_item_for_update('ITEM-001', 1);
COMMIT;
```

Dengan stok awal 1, satu kasir berhasil memasukkan penjualan dan trigger mengubah stok menjadi 0. Kasir kedua baru melanjutkan setelah lock dilepas; pemeriksaan membaca 0 dan prosedur menolak penjualan. Jika terjadi exception, transaksi gagal dan aplikasi harus melakukan `ROLLBACK` sebelum melanjutkan.

Trigger yang sudah ada juga memakai `SELECT ... FOR UPDATE`. Karena itu, transaksi tetap memiliki pemeriksaan stok di database meskipun ada klien yang tidak menggunakan prosedur di atas; prosedur menempatkan pemeriksaan sebelum `INSERT` agar kegagalan dapat dijelaskan lebih awal.

## 2. Transaction isolation level `SERIALIZABLE`

`SERIALIZABLE` meminta PostgreSQL memastikan transaksi yang berhasil memiliki hasil setara dengan suatu urutan serial. Salah satu transaksi yang berkonflik dapat dibatalkan dengan SQLSTATE `40001` (`serialization_failure`); aplikasi wajib mengulang **seluruh transaksi**, bukan hanya statement yang gagal.

Contoh prosedur berikut membaca stok tanpa row lock eksplisit. Jalankan dalam transaksi `SERIALIZABLE`. Trigger pada `INSERT` tetap mengunci dan memvalidasi stok sebagai perlindungan di database.

```sql
CREATE OR REPLACE PROCEDURE sell_item_serializable(
    p_item_id VARCHAR(10),
    p_qty INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock_qty inventory_items.stock_qty%TYPE;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Kuantitas penjualan harus lebih besar dari nol';
    END IF;

    SELECT stock_qty
      INTO v_stock_qty
      FROM inventory_items
     WHERE item_id = p_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = format('Item %s tidak ditemukan', p_item_id);
    END IF;

    IF v_stock_qty < p_qty THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = format(
                'Stok tidak cukup untuk item %s: tersedia %s, diminta %s',
                p_item_id,
                v_stock_qty,
                p_qty
            );
    END IF;

    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES (p_item_id, 'SALE', p_qty);
END;
$$;

-- Jalankan pada sesi kasir. SET TRANSACTION harus dilakukan sebelum query.
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
CALL sell_item_serializable('ITEM-001', 1);
COMMIT;
```

Apabila dua transaksi serializable sama-sama membaca stok 1, PostgreSQL dapat membatalkan salah satu dengan `40001` saat mendeteksi konflik. Aplikasi menangani error tersebut dengan rollback dan retry terbatas atas seluruh transaksi. Pada retry, stok yang sudah 0 menyebabkan penjualan ditolak sebagai stok tidak cukup. Exception stok tidak cukup (`23514`) adalah kegagalan bisnis dan bukan alasan untuk retry otomatis.

## Perbandingan dan rekomendasi

| Aspek | `SELECT ... FOR UPDATE` | `SERIALIZABLE` |
|---|---|---|
| Cakupan pengamanan | Mengunci baris item tertentu yang akan dijual. | Mendeteksi konflik transaksi untuk menjamin hasil setara serial, termasuk pola baca-tulis yang lebih luas. |
| Perilaku saat konflik | Transaksi lain yang meminta lock baris yang sama menunggu; sesudah itu memeriksa nilai stok terbaru. | Salah satu transaksi dapat gagal dengan `40001` dan perlu diulang seluruhnya. |
| Kelebihan | Sederhana dan terarah; cocok untuk mutasi stok berdasarkan satu `item_id`, dengan konflik yang mudah dipahami. | Perlindungan kuat untuk aturan yang melibatkan beberapa baris atau predikat yang tidak mudah dikunci satu per satu. |
| Kekurangan | Semua jalur yang mengubah stok harus mengikuti protokol lock/validasi; lock dipegang sampai commit dan dapat menimbulkan antrean atau deadlock bila banyak item dikunci dengan urutan berbeda. | Lebih banyak transaksi dapat dibatalkan; aplikasi harus memiliki mekanisme retry yang benar, dan konflik berulang dapat menurunkan throughput. |
| Penggunaan yang sesuai | Penjualan atau penerimaan yang mengubah saldo satu barang atau sejumlah baris barang yang diketahui. | Aturan bisnis kompleks yang bergantung pada beberapa baris/rentang data atau ketika serialisasi transaksi secara umum diperlukan. |

Untuk kasus ritel dengan stok tersisa satu unit, pendekatan yang paling tepat dan efisien adalah **`SELECT ... FOR UPDATE` pada baris `inventory_items`**, disertai pemeriksaan stok dan mutasi dalam transaksi database yang sama. Ini mengunci tepat barang yang bersaing tanpa membatasi penjualan barang lain. Pertahankan validasi stok di trigger/database agar API atau klien lain tidak dapat melewati aturan. `SERIALIZABLE` dapat dipilih bila transaksi penjualan juga bergantung pada aturan lintas banyak baris; jika dipilih, aplikasi harus menangani retry `40001`. Kedua pendekatan tidak boleh mengandalkan validasi UI saja.

## Hubungan dengan trigger dan batasan skema

`trg_update_stock_and_journal()` memakai row-level lock pada baris `inventory_items`, menghitung saldo baru, menolak saldo negatif, lalu memperbarui stok. Exception dari trigger membatalkan `INSERT` transaksi yang memicunya, sehingga catatan penjualan dan mutasi kuantitas tetap atomik. Pengujian pada `test_trigger.sql` memverifikasi penjualan berlebih ditolak dan saldo tidak berubah.

Trigger dalam soal hanya mengubah kuantitas. Ia belum membuat jurnal nilai Persediaan/HPP karena skema yang diberikan tidak mencakup tabel jurnal atau aturan pemetaan akun. Jika jurnal akuntansi ditambahkan, pencatatannya harus dilakukan dalam transaksi database yang sama agar saldo fisik dan buku besar tidak menyimpang.
