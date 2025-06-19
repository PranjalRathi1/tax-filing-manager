-- -----------------------------------------------------
-- DATABASE SCHEMA: Tax Filing & Document Manager
-- -----------------------------------------------------
-- Dropping and recreating database just to keep things clean and fresh each time we run
DROP DATABASE IF EXISTS tax_filing_manager;
CREATE DATABASE tax_filing_manager;
USE tax_filing_manager;

-- Dropping tables if they already exist so we don't get errors when re-running the script
DROP TABLE IF EXISTS shared_documents, reminders, audit_logs, document_tag_map, document_tags,
    documents, tax_filings, users;

-- -----------------------------------------------------
-- USERS TABLE
-- Stores info about users like name, email, and password hash
-- -----------------------------------------------------
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------
-- DOCUMENTS TABLE
-- Stores tax document info like type, year, status etc.
-- -----------------------------------------------------
CREATE TABLE documents (
    document_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    document_name VARCHAR(100),
    document_type VARCHAR(50),
    year INT,
    status ENUM('uploaded', 'reviewed', 'approved') DEFAULT 'uploaded',
    version INT DEFAULT 1, -- versioning so we can track doc history
    is_deleted BOOLEAN DEFAULT FALSE, -- soft delete flag
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- -----------------------------------------------------
-- DOCUMENT TAGGING TABLES
-- Helps in tagging documents for easy search/filtering
-- -----------------------------------------------------
CREATE TABLE document_tags (
    tag_id INT AUTO_INCREMENT PRIMARY KEY,
    tag_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE document_tag_map (
    document_id INT,
    tag_id INT,
    PRIMARY KEY (document_id, tag_id),
    FOREIGN KEY (document_id) REFERENCES documents(document_id),
    FOREIGN KEY (tag_id) REFERENCES document_tags(tag_id)
);

-- -----------------------------------------------------
-- TAX FILINGS TABLE
-- Tracks filing status per year per user
-- -----------------------------------------------------
CREATE TABLE tax_filings (
    filing_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    filing_year INT,
    status ENUM('not_started', 'in_progress', 'filed') DEFAULT 'not_started',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- -----------------------------------------------------
-- AUDIT TRAIL TABLE
-- Logs all user actions like uploads and edits
-- -----------------------------------------------------
CREATE TABLE audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100),
    document_id INT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (document_id) REFERENCES documents(document_id)
);

-- -----------------------------------------------------
-- REMINDERS TABLE
-- For storing deadlines and reminders for users
-- -----------------------------------------------------
CREATE TABLE reminders (
    reminder_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    message VARCHAR(255),
    remind_date DATE,
    is_done BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- -----------------------------------------------------
-- SHARED DOCUMENTS TABLE (BONUS)
-- Allows sharing documents with other users with permission
-- -----------------------------------------------------
CREATE TABLE shared_documents (
    share_id INT AUTO_INCREMENT PRIMARY KEY,
    document_id INT,
    shared_with_user INT,
    permission ENUM('view', 'edit') DEFAULT 'view',
    FOREIGN KEY (document_id) REFERENCES documents(document_id),
    FOREIGN KEY (shared_with_user) REFERENCES users(user_id)
);

-- -----------------------------------------------------
-- INDEXES TO SPEED THINGS UP
-- -----------------------------------------------------
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_year ON documents(year);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_tax_filings_user_year ON tax_filings(user_id, filing_year);
CREATE INDEX idx_document_tag_map_doc ON document_tag_map(document_id);
CREATE INDEX idx_document_tag_map_tag ON document_tag_map(tag_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);

-- -----------------------------------------------------
-- TRIGGER TO AUTO UPDATE FILING STATUS AND LOG ACTION
-- -----------------------------------------------------
DELIMITER $$

CREATE TRIGGER trg_documents_insert AFTER INSERT ON documents
FOR EACH ROW
BEGIN
    -- If a doc is added, update filing status to in_progress
    UPDATE tax_filings
    SET status = 'in_progress'
    WHERE user_id = NEW.user_id AND filing_year = NEW.year;

    -- Also log that user uploaded a doc
    INSERT INTO audit_logs (user_id, action, document_id)
    VALUES (NEW.user_id, 'Uploaded document', NEW.document_id);
END$$

DELIMITER ;

-- -----------------------------------------------------
-- PROCEDURE TO CREATE A NEW VERSION OF A DOC
-- -----------------------------------------------------
DELIMITER $$

CREATE PROCEDURE add_document_version(
    IN doc_id INT, 
    IN new_name VARCHAR(100), 
    IN new_status VARCHAR(50)
)
BEGIN
    DECLARE v INT;
    DECLARE uid INT;

    -- Get version and user
    SELECT version, user_id INTO v, uid 
    FROM documents WHERE document_id = doc_id;

    -- Insert new version of the doc
    INSERT INTO documents (user_id, document_name, document_type, year, status, version)
    SELECT user_id, new_name, document_type, year, new_status, v+1
    FROM documents WHERE document_id = doc_id;

    -- Log the version update
    INSERT INTO audit_logs (user_id, action, document_id)
    VALUES (uid, CONCAT('Added version for doc ID ', doc_id), LAST_INSERT_ID());
END$$

DELIMITER ;

-- -----------------------------------------------------
-- VIEW FOR DOCUMENT FILING REPORT
-- Shows counts of docs by their status
-- -----------------------------------------------------
CREATE OR REPLACE VIEW filing_summary AS
SELECT
    user_id,
    year AS filing_year,
    COUNT(*) AS total_documents,
    SUM(CASE WHEN status = 'uploaded' THEN 1 ELSE 0 END) AS pending_review,
    SUM(CASE WHEN status = 'reviewed' THEN 1 ELSE 0 END) AS reviewed_docs,
    SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved_docs
FROM documents
WHERE is_deleted = FALSE
GROUP BY user_id, year;

-- -----------------------------------------------------
-- SAMPLE DATA TO TEST THINGS
-- -----------------------------------------------------
INSERT INTO users (username, email, password_hash) VALUES
('john_doe', 'john@example.com', 'hashedpass123'),
('jane_smith', 'jane@example.com', 'hashedpass456');

INSERT INTO document_tags (tag_name) VALUES ('Income'), ('Investment'), ('Medical');

INSERT INTO tax_filings (user_id, filing_year) VALUES (1, 2023), (2, 2024);

INSERT INTO documents (user_id, document_name, document_type, year) VALUES
(1, 'Form16_2023.pdf', 'Income', 2023),
(1, 'LIC_Receipt.pdf', 'Investment', 2023);

INSERT INTO document_tag_map (document_id, tag_id) VALUES (1, 1), (2, 2);

INSERT INTO reminders (user_id, message, remind_date) VALUES
(1, 'File tax return for 2023', '2025-07-31'),
(2, 'Upload investment proofs', '2025-08-15');

-- -----------------------------------------------------
-- TEST QUERIES TO REPRESENT DATA
-- These help to see if everything's working right
-- -----------------------------------------------------

-- 1. View all documents of a user (excluding soft-deleted ones)
SELECT * FROM documents WHERE user_id = 1 AND is_deleted = FALSE;

-- 2. View tags assigned to a document
SELECT t.tag_name
FROM document_tags t
JOIN document_tag_map dtm ON t.tag_id = dtm.tag_id
WHERE dtm.document_id = 1;

-- 3. Check what actions a user has done
SELECT * FROM audit_logs WHERE user_id = 1;

-- 4. Check which docs are shared and with whom
SELECT d.document_name, sd.shared_with_user, sd.permission
FROM shared_documents sd
JOIN documents d ON sd.document_id = d.document_id;

-- 5. See summary report for documents per year
SELECT * FROM filing_summary;

-- 6. Add a new version of a document (simulating an update)
CALL add_document_version(1, 'Form16_2023_v2.pdf', 'reviewed');

-- 7. Check if new version got inserted
SELECT * FROM documents WHERE document_name = 'Form16_2023_v2.pdf';
