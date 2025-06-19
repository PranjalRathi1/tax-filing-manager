# Tax Filing & Document Manager

## Project Overview
This is a MySQL-only project designed to help users manage their tax documents, filings, reminders, and collaboration with others. The system uses SQL features like triggers, views, procedures, soft deletes, indexing, and more. It doesn't include any frontend or backend code.

## Objective
Build a normalized and efficient database for managing tax-related documents. The system should support document versioning, tagging, audit logs, user reminders, and allow optional sharing with permissions.

---

## Database Schema Design

### 1. `users`
- Stores user login details.
- Fields: `user_id`, `username`, `email`, `password_hash`, `created_at`

### 2. `documents`
- Stores metadata of each uploaded document.
- Tracks: name, type, year, version, status, deletion flag.
- Linked to `users` via `user_id`.

### 3. `document_tags` & `document_tag_map`
- Allows tagging documents for better search.
- Many-to-many relation between documents and tags.

### 4. `tax_filings`
- Tracks tax filings per user and year.
- Tracks status and soft delete status.

### 5. `audit_logs`
- Records important user actions (upload/versioning).

### 6. `reminders`
- Stores reminders set by users.
- Fields include message, due date, and done status.

### 7. `shared_documents`
- Enables document sharing with others.
- Permissions supported: `view`, `edit`.

---

## Indexes Added
To make queries and joins faster:
- `documents`: indexed on `user_id`, `year`, `status`
- `tax_filings`: indexed on `user_id`, `filing_year`
- `document_tag_map`: indexed on `document_id`, `tag_id`
- `audit_logs`: indexed on `user_id`

---

## Triggers

### `trg_documents_insert`
- After a document is uploaded:
  - Updates the tax filing status to `in_progress`.
  - Logs the upload in `audit_logs`.

---

## Stored Procedure

### `add_document_version`
- Creates a new version of an existing document.
- Increments version number.
- Logs the version update in `audit_logs`.

---

## View

### `filing_summary`
- Shows document counts by status per user per year:
  - Total, pending, reviewed, approved.

---

## Sample Data
Inserted for:
- Users
- Tags
- Tax filings
- Documents
- Tag map
- Reminders

---

## Testing Guide
Make sure to run the full SQL script, then use these queries:

### 1. View documents (excluding soft-deleted):
```sql
SELECT * FROM documents WHERE user_id = 1 AND is_deleted = FALSE;
```

### 2. View document tags:
```sql
SELECT t.tag_name
FROM document_tags t
JOIN document_tag_map dtm ON t.tag_id = dtm.tag_id
WHERE dtm.document_id = 1;
```

### 3. View audit logs:
```sql
SELECT * FROM audit_logs WHERE user_id = 1;
```

### 4. View shared documents:
```sql
SELECT d.document_name, sd.shared_with_user, sd.permission
FROM shared_documents sd
JOIN documents d ON sd.document_id = d.document_id;
```

### 5. Filing summary report:
```sql
SELECT * FROM filing_summary;
```

### 6. Add a document version:
```sql
CALL add_document_version(1, 'Form16_2023_v2.pdf', 'reviewed');
```

### 7. Check new version:
```sql
SELECT * FROM documents WHERE document_name = 'Form16_2023_v2.pdf';
```

---

## Additional Features Summary

- **Soft Deletes**: Supported using `is_deleted` flag in relevant tables.
- **Multi-user Collaboration**: Sharing with view/edit access.
- **Auto Status Updates**: Trigger updates filing status.
- **Reporting**: View `filing_summary` gives yearly breakdown.
