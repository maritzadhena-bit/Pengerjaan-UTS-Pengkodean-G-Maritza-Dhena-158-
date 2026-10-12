-- Uji mandiri: membuat item sementara, memeriksa mutasi, lalu menghapusnya.
-- Jalankan setelah skema inventory_items/inventory_transactions dan trigger.sql.
DO $$
DECLARE
    v_item_id VARCHAR(10) := upper(substr(md5(random()::text), 1, 10));
    v_stock_qty INTEGER;
    v_rejected BOOLEAN := FALSE;
BEGIN
    INSERT INTO inventory_items (item_id, item_name, stock_qty, unit_cost)
    VALUES (v_item_id, 'Trigger test item', 5, 1000.00);

    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES (v_item_id, 'PURCHASE', 5);

    SELECT stock_qty INTO v_stock_qty
      FROM inventory_items
     WHERE item_id = v_item_id;

    IF v_stock_qty <> 10 THEN
        RAISE EXCEPTION 'Uji PURCHASE gagal: stok seharusnya 10, aktual %', v_stock_qty;
    END IF;

    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES (v_item_id, 'SALE', 3);

    SELECT stock_qty INTO v_stock_qty
      FROM inventory_items
     WHERE item_id = v_item_id;

    IF v_stock_qty <> 7 THEN
        RAISE EXCEPTION 'Uji SALE gagal: stok seharusnya 7, aktual %', v_stock_qty;
    END IF;

    BEGIN
        -- Contoh INSERT yang harus gagal karena akan membuat stok menjadi -1.
        INSERT INTO inventory_transactions (item_id, trx_type, qty)
        VALUES (v_item_id, 'SALE', 8);
    EXCEPTION
        WHEN SQLSTATE '23514' THEN
            v_rejected := TRUE;
            RAISE NOTICE 'Uji oversell berhasil: transaksi ditolak oleh trigger.';
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Uji oversell gagal: transaksi SALE yang melebihi stok diterima';
    END IF;

    SELECT stock_qty INTO v_stock_qty
      FROM inventory_items
     WHERE item_id = v_item_id;

    IF v_stock_qty <> 7 THEN
        RAISE EXCEPTION 'Stok berubah setelah INSERT ditolak: diharapkan 7, aktual %', v_stock_qty;
    END IF;

    DELETE FROM inventory_transactions WHERE item_id = v_item_id;
    DELETE FROM inventory_items WHERE item_id = v_item_id;
END;
$$;