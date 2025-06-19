# Tax Filing & Document Manager

## Project Overview
This project is a MySQL-only backend solution designed to manage tax-related documents, user data, tax filings, reminders, and related metadata. It uses MySQL features like DDL, DML, triggers, procedures, views, and constraints without involving any frontend/backend code.

## Objective
To design a normalized and efficient relational database schema for a Tax Filing and Document Manager that includes complete support for document storage, versioning, user access control, audit logging, reminders, and optional collaboration features.

---

## Database Schema Design

### 1. `users`
- Stores basic user profile and login information.
- Includes: `user_id`, `username`, `email`, `password_hash`, `created_at`

### 2. `documents`
- Stores metadata about tax documents uploaded by users.
- Tracks document name, type, year, version, status (`uploaded`, `reviewed`, `approved`), and `is_deleted` for soft deletion.
- Includes a foreign key to `users`.

### 3. `document_tags` & `document_tag_map`
- Tagging system for better document classification.
- `document_tags`: stores tag names.
- `document_tag_map`: many-to-many relationship between `documents` and `tags`.

### 4. `tax_filings`
- Tracks the tax filing activity per user and year.
- Stores the filing status (`not_started`, `in_progress`, `filed`), along with timestamps.
- Includes soft delete field `is_deleted`.

### 5. `audit_logs`
- Logs all critical user actions such as uploads, edits, or deletions.
- Tracks `user_id`, `document_id`, `action`, and `timestamp`.

### 6. `reminders`
- Stores user-defined reminders for tax deadlines.
- Includes message, due date (`remind_date`), and status (`is_done`).

### 7. `shared_documents` (Bonus)
- Enables users to share documents with others.
- Supports permissions (`view` or `edit`) for collaborative workflows.

---

## Triggers Implemented

- `trg_update_filing_status`: Automatically updates the user's `tax_filings` status to `in_progress` when a document is uploaded for that year.
- `trg_log_document_upload`: Logs each upload action to the `audit_logs` table.

---

## Stored Procedure

- `add_document_version`: Implements document versioning by duplicating an existing document record with an incremented version number, a new name, and an updated status.

---

## View

- `filing_summary`: Provides a report per user and per year, showing the number of documents uploaded and how many are still pending review.

---

## Testing 

 Ensure you're connected to a MySQL client (e.g., Workbench, CLI, phpMyAdmin) and execute the provided SQL script.

### Steps:

1. **Run the full SQL script (`tax_filing_manager.sql`)**:
   - This will create the database, tables, triggers, procedures, view, and populate sample data.

2. **Run the following queries to test core features**:

   - View documents for a user:
     ```sql
     SELECT * FROM documents WHERE user_id = 1 AND is_deleted = FALSE;
     ```

   - View tags associated with a document:
     ```sql
     SELECT t.tag_name
     FROM document_tags t
     JOIN document_tag_map dtm ON t.tag_id = dtm.tag_id
     WHERE dtm.document_id = 1;
     ```

   - View audit logs:
     ```sql
     SELECT * FROM audit_logs WHERE user_id = 1;
     ```

   - View shared documents:
     ```sql
     SELECT d.document_name, sd.shared_with_user, sd.permission
     FROM shared_documents sd
     JOIN documents d ON sd.document_id = d.document_id;
     ```

   - View filing summary:
     ```sql
     SELECT * FROM filing_summary;
     ```

   - Test versioning procedure:
     ```sql
     CALL add_document_version(1, 'Form16_2023_v2.pdf', 'reviewed');
     ```
   - Check if the new versioned document was added:
     ```sql
     SELECT * FROM documents WHERE document_name = 'Form16_2023_v2.pdf';
     ```

---

## Additional Features Summary

- **Soft Deletes**: `is_deleted` flag used in both `documents` and `tax_filings` instead of hard deletes.
- **Multi-user Collaboration**: Implemented using `shared_documents` with permission levels.
- **Automated Status Updates**: Trigger ensures filing status is automatically updated when a document is uploaded.
- **Reporting**: View `filing_summary` summarizes document status per user/year.

---
