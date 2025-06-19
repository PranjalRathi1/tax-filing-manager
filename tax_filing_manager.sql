-- -----------------------------------------------------
-- DATABASE SCHEMA: Tax Filing & Document Manager
-- -----------------------------------------------------
-- Create and use the project database
DROP DATABASE IF EXISTS tax_filing_manager;
CREATE DATABASE tax_filing_manager;
USE tax_filing_manager;

-- Drop existing tables if any (for clean re-run)
DROP TABLE IF EXISTS shared_documents, reminders, audit_logs, document_tag_map, document_tags,
    documents, tax_filings, users;

-- -----------------------------------------------------
-- USERS TABLE
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
-- -----------------------------------------------------

CREATE TABLE documents (
    document_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    document_name VARCHAR(100),
    document_type VARCHAR(50),
    year INT,
    status ENUM('uploaded', 'reviewed', 'approved') DEFAULT 'uploaded',
    version INT DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- -----------------------------------------------------
-- DOCUMENT TAGGING TABLES
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
-- TRIGGERS
-- -----------------------------------------------------
DELIMITER $$

-- Update filing status automatically on document insert
CREATE TRIGGER trg_update_filing_status
AFTER INSERT ON documents
FOR EACH ROW
BEGIN
    UPDATE tax_filings
    SET status = 'in_progress'
    WHERE user_id = NEW.user_id AND filing_year = NEW.year;
END$$

-- Log audit on document upload
CREATE TRIGGER trg_log_document_upload
AFTER INSERT ON documents
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, document_id)
    VALUES (NEW.user_id, 'Uploaded document', NEW.document_id);
END$$

DELIMITER ;

-- -----------------------------------------------------
-- STORED PROCEDURES
-- -----------------------------------------------------
DELIMITER $$

CREATE PROCEDURE add_document_version(
    IN doc_id INT, IN new_name VARCHAR(100), IN new_status VARCHAR(50)
)
BEGIN
    DECLARE v INT;
    SELECT version INTO v FROM documents WHERE document_id = doc_id;

    INSERT INTO documents (user_id, document_name, document_type, year, status, version)
    SELECT user_id, new_name, document_type, year, new_status, v+1
    FROM documents
    WHERE document_id = doc_id;
END$$

DELIMITER ;

-- -----------------------------------------------------
-- VIEWS
-- -----------------------------------------------------
CREATE VIEW filing_summary AS
SELECT
    user_id,
    year AS filing_year,
    COUNT(*) AS total_documents,
    SUM(CASE WHEN status = 'uploaded' THEN 1 ELSE 0 END) AS pending_review
FROM documents
GROUP BY user_id, year;

-- -----------------------------------------------------
-- SAMPLE DATA
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
-- -----------------------------------------------------

-- 1. View all documents of a user (excluding soft-deleted)
SELECT * FROM documents WHERE user_id = 1 AND is_deleted = FALSE;

-- 2. View document tags for a document
SELECT t.tag_name
FROM document_tags t
JOIN document_tag_map dtm ON t.tag_id = dtm.tag_id
WHERE dtm.document_id = 1;

-- 3. View audit logs for a user
SELECT * FROM audit_logs WHERE user_id = 1;

-- 4. View shared documents and their permissions
SELECT d.document_name, sd.shared_with_user, sd.permission
FROM shared_documents sd
JOIN documents d ON sd.document_id = d.document_id;

-- 5. View filing summary report (from view)
SELECT * FROM filing_summary;

-- 6. Call procedure to add a new version of a document
CALL add_document_version(1, 'Form16_2023_v2.pdf', 'reviewed');

-- 7. Check for newly inserted document version
SELECT * FROM documents WHERE document_name = 'Form16_2023_v2.pdf';

