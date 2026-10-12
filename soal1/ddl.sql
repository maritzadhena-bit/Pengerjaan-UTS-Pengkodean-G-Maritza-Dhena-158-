-- Skema General Ledger PostgreSQL untuk pencatatan double-entry.

CREATE TABLE chart_of_accounts (
    account_id BIGINT GENERATED ALWAYS AS IDENTITY,
    account_code VARCHAR(30) NOT NULL,
    account_name VARCHAR(150) NOT NULL,
    normal_balance VARCHAR(6) NOT NULL,
    report_classification VARCHAR(20) NOT NULL,
    CONSTRAINT pk_chart_of_accounts
        PRIMARY KEY (account_id),
    CONSTRAINT uq_chart_of_accounts_account_code
        UNIQUE (account_code),
    CONSTRAINT ck_chart_of_accounts_normal_balance
        CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_chart_of_accounts_report_classification
        CHECK (report_classification IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'))
);

COMMENT ON CONSTRAINT pk_chart_of_accounts ON chart_of_accounts
    IS 'Menjamin setiap akun memiliki identitas unik sebagai primary key.';
COMMENT ON CONSTRAINT uq_chart_of_accounts_account_code ON chart_of_accounts
    IS 'Mencegah kode akun yang sama digunakan lebih dari satu kali.';
COMMENT ON CONSTRAINT ck_chart_of_accounts_normal_balance ON chart_of_accounts
    IS 'Membatasi saldo normal akun ke DEBIT atau CREDIT.';
COMMENT ON CONSTRAINT ck_chart_of_accounts_report_classification ON chart_of_accounts
    IS 'Membatasi klasifikasi akun ke kelompok laporan keuangan yang dikenal.';

CREATE TABLE journal_headers (
    journal_id BIGINT GENERATED ALWAYS AS IDENTITY,
    trx_date DATE NOT NULL,
    reference_no VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    posting_status VARCHAR(10) NOT NULL DEFAULT 'DRAFT',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_journal_headers
        PRIMARY KEY (journal_id),
    CONSTRAINT ck_journal_headers_posting_status
        CHECK (posting_status IN ('DRAFT', 'POSTED'))
);

COMMENT ON CONSTRAINT pk_journal_headers ON journal_headers
    IS 'Menjamin setiap transaksi jurnal memiliki identitas header yang unik.';
COMMENT ON CONSTRAINT ck_journal_headers_posting_status ON journal_headers
    IS 'Memastikan status posting hanya bernilai DRAFT atau POSTED.';

CREATE TABLE journal_lines (
    line_id BIGINT GENERATED ALWAYS AS IDENTITY,
    journal_id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    debit NUMERIC(18, 2) NOT NULL DEFAULT 0,
    credit NUMERIC(18, 2) NOT NULL DEFAULT 0,
    CONSTRAINT pk_journal_lines
        PRIMARY KEY (line_id),
    CONSTRAINT fk_journal_lines_journal
        FOREIGN KEY (journal_id)
        REFERENCES journal_headers (journal_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_journal_lines_account
        FOREIGN KEY (account_id)
        REFERENCES chart_of_accounts (account_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_journal_lines_debit_nonnegative
        CHECK (debit >= 0),
    CONSTRAINT ck_journal_lines_credit_nonnegative
        CHECK (credit >= 0),
    CONSTRAINT ck_journal_lines_not_both_zero
        CHECK (debit > 0 OR credit > 0),
    CONSTRAINT ck_journal_lines_one_side_only
        CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
);

COMMENT ON CONSTRAINT pk_journal_lines ON journal_lines
    IS 'Menjamin setiap baris jurnal memiliki identitas unik.';
COMMENT ON CONSTRAINT fk_journal_lines_journal ON journal_lines
    IS 'Mengaitkan baris ke header yang ada; RESTRICT menjaga audit trail dan CASCADE menyelaraskan perubahan ID.';
COMMENT ON CONSTRAINT fk_journal_lines_account ON journal_lines
    IS 'Mengaitkan baris ke akun yang ada; RESTRICT mencegah penghapusan akun yang sudah dipakai.';
COMMENT ON CONSTRAINT ck_journal_lines_debit_nonnegative ON journal_lines
    IS 'Melarang nilai debit negatif.';
COMMENT ON CONSTRAINT ck_journal_lines_credit_nonnegative ON journal_lines
    IS 'Melarang nilai kredit negatif.';
COMMENT ON CONSTRAINT ck_journal_lines_not_both_zero ON journal_lines
    IS 'Memastikan setiap baris mencatat nilai debit atau kredit yang tidak nol.';
COMMENT ON CONSTRAINT ck_journal_lines_one_side_only ON journal_lines
    IS 'Memastikan satu baris jurnal hanya mencatat debit atau kredit, tidak keduanya sekaligus.';

-- Indeks untuk pencarian baris berdasarkan jurnal/akun dan transaksi berdasarkan tanggal.
CREATE INDEX idx_journal_lines_journal_id ON journal_lines (journal_id);
CREATE INDEX idx_journal_lines_account_id ON journal_lines (account_id);
CREATE INDEX idx_journal_headers_trx_date ON journal_headers (trx_date);