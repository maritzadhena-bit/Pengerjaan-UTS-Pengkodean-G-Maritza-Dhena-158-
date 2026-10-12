-- Jalankan sesudah soal1/ddl.sql.
-- Tambahkan metadata posting, checksum, dan relasi ke voucher asal saat reversal.
-- Jurnal pembalik lebih baik daripada edit langsung karena voucher POSTED asal
-- tetap utuh dan koreksi tercatat sebagai transaksi baru yang dapat ditelusuri.
-- SHA-256 membuat perubahan payload dapat terdeteksi saat checksum dipercaya;
-- penyimpanan hash di database yang sama bukan bukti anti-manipulasi absolut.
-- Audit trail memadai bila jejak transaksi dapat ditelusuri, diotorisasi,
-- diverifikasi, dipertahankan, dan didukung dokumen sesuai kebijakan serta
-- ketentuan akuntansi/peraturan yang berlaku; PSAK tidak menetapkan satu kolom
-- checksum sebagai pengganti pengendalian dan dokumentasi tersebut.
ALTER TABLE journal_headers
    ADD COLUMN posted_by VARCHAR(100),
    ADD COLUMN posted_at TIMESTAMPTZ,
    ADD COLUMN hash_checksum CHAR(64),
    ADD COLUMN reversal_of_journal_id BIGINT
        REFERENCES journal_headers (journal_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE;

ALTER TABLE journal_headers
    ADD CONSTRAINT uq_journal_headers_reversal_source
        UNIQUE (reversal_of_journal_id),
    ADD CONSTRAINT ck_journal_headers_posted_audit_fields
        CHECK (
            posting_status <> 'POSTED'
            OR (
                posted_by IS NOT NULL
                AND posted_at IS NOT NULL
                AND hash_checksum ~ '^[0-9a-f]{64}$'
            )
        );

COMMENT ON COLUMN journal_headers.posted_by
    IS 'Pengguna yang mengunci/mem-posting voucher.';
COMMENT ON COLUMN journal_headers.posted_at
    IS 'Waktu saat voucher beralih ke status POSTED.';
COMMENT ON COLUMN journal_headers.hash_checksum
    IS 'SHA-256 hex atas payload kanonis header dan baris saat posting; bukan pengganti audit log independen.';
COMMENT ON COLUMN journal_headers.reversal_of_journal_id
    IS 'Voucher POSTED asal yang dibalik oleh jurnal pembalik ini; UNIQUE membatasi satu reversal langsung per sumber.';
COMMENT ON CONSTRAINT ck_journal_headers_posted_audit_fields ON journal_headers
    IS 'Memastikan voucher POSTED memiliki aktor, waktu, dan checksum.';
COMMENT ON CONSTRAINT uq_journal_headers_reversal_source ON journal_headers
    IS 'Mencegah satu voucher asal memperoleh lebih dari satu jurnal pembalik langsung.';

-- Baris yang sudah POSTED tidak boleh diubah/dihapus; koreksi dibuat sebagai reversal.
CREATE OR REPLACE FUNCTION prevent_posted_journal_header_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.posting_status = 'POSTED' THEN
            RAISE EXCEPTION USING
                ERRCODE = '55000',
                MESSAGE = format(
                    'Voucher POSTED %s tidak boleh dihapus; buat jurnal pembalik',
                    OLD.journal_id
                );
        END IF;
        RETURN OLD;
    END IF;

    IF OLD.posting_status = 'POSTED' THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = format(
                'Voucher POSTED %s tidak boleh diubah; buat jurnal pembalik',
                OLD.journal_id
            );
    END IF;

    IF NEW.posting_status <> OLD.posting_status
       AND NEW.posting_status <> 'POSTED' THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = 'Transisi status yang diizinkan hanya DRAFT ke POSTED';
    END IF;

    IF NEW.posting_status = 'POSTED'
       AND (
           NEW.posted_by IS NULL
           OR NEW.posted_at IS NULL
           OR NEW.hash_checksum IS NULL
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Posting memerlukan posted_by, posted_at, dan hash_checksum';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lock_posted_journal_header
BEFORE UPDATE OR DELETE ON journal_headers
FOR EACH ROW
EXECUTE FUNCTION prevent_posted_journal_header_mutation();

-- Header immutability saja belum cukup: cegah perubahan detail voucher POSTED.
CREATE OR REPLACE FUNCTION prevent_posted_journal_line_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_journal_id BIGINT;
    v_status VARCHAR(10);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_journal_id := NEW.journal_id;
    ELSE
        v_journal_id := OLD.journal_id;
    END IF;

    SELECT posting_status
      INTO v_status
      FROM journal_headers
     WHERE journal_id = v_journal_id
     FOR UPDATE;

    IF v_status = 'POSTED' THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = format(
                'Baris voucher POSTED %s tidak boleh diubah atau dihapus; buat jurnal pembalik',
                v_journal_id
            );
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.journal_id <> OLD.journal_id THEN
        SELECT posting_status
          INTO v_status
          FROM journal_headers
         WHERE journal_id = NEW.journal_id
         FOR UPDATE;

        IF v_status = 'POSTED' THEN
            RAISE EXCEPTION USING
                ERRCODE = '55000',
                MESSAGE = format('Tidak dapat memindahkan baris ke voucher POSTED %s', NEW.journal_id);
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lock_posted_journal_line
BEFORE INSERT OR UPDATE OR DELETE ON journal_lines
FOR EACH ROW
EXECUTE FUNCTION prevent_posted_journal_line_mutation();