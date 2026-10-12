-- Menjaga kuantitas persediaan tetap sinkron dengan transaksi yang dimasukkan.
-- ADJUSTMENT menggunakan qty bertanda: positif untuk penambahan, negatif untuk pengurangan.

CREATE OR REPLACE FUNCTION trg_update_stock_and_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock_qty inventory_items.stock_qty%TYPE;
    v_new_stock_qty inventory_items.stock_qty%TYPE;
BEGIN
    IF NEW.item_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '23502',
            MESSAGE = 'item_id wajib diisi pada inventory_transactions';
    END IF;

    IF NEW.trx_type IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '23502',
            MESSAGE = 'trx_type wajib diisi pada inventory_transactions';
    END IF;

    IF NEW.qty IS NULL OR NEW.qty = 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'qty tidak boleh NULL atau 0';
    END IF;

    IF NEW.trx_type IN ('PURCHASE', 'SALE') AND NEW.qty < 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'qty PURCHASE dan SALE harus positif';
    END IF;

    -- Mengunci item sampai transaksi pemanggil selesai agar transaksi bersamaan
    -- pada item yang sama membaca dan memperbarui saldo secara berurutan.
    SELECT stock_qty
      INTO v_stock_qty
      FROM inventory_items
     WHERE item_id = NEW.item_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = format('Item %s tidak ditemukan', NEW.item_id);
    END IF;

    CASE NEW.trx_type
        WHEN 'PURCHASE' THEN
            v_new_stock_qty := v_stock_qty + NEW.qty;
        WHEN 'SALE' THEN
            v_new_stock_qty := v_stock_qty - NEW.qty;
        WHEN 'ADJUSTMENT' THEN
            v_new_stock_qty := v_stock_qty + NEW.qty;
        ELSE
            RAISE EXCEPTION USING
                ERRCODE = '22023',
                MESSAGE = format('trx_type tidak valid: %s', NEW.trx_type);
    END CASE;

    IF v_new_stock_qty < 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = format(
                'Stok item %s tidak mencukupi: stok %s, transaksi %s %s',
                NEW.item_id,
                v_stock_qty,
                NEW.trx_type,
                NEW.qty
            );
    END IF;

    UPDATE inventory_items
       SET stock_qty = v_new_stock_qty
     WHERE item_id = NEW.item_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inventory_transactions_update_stock
    ON inventory_transactions;

CREATE TRIGGER inventory_transactions_update_stock
AFTER INSERT ON inventory_transactions
FOR EACH ROW
EXECUTE FUNCTION trg_update_stock_and_journal();

-- Contoh oversell yang ditolak (jalankan setelah membuat fungsi dan trigger):
-- INSERT INTO inventory_transactions (item_id, trx_type, qty)
-- VALUES ('ITEM-001', 'SALE', 999999);
-- Jika stok ITEM-001 kurang dari 999999, PostgreSQL melempar exception dan
-- membatalkan INSERT beserta perubahan stok dari statement tersebut.