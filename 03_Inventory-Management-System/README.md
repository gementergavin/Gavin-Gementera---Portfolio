# Inventory Management System (Python + SQLite)

A command-line app that tracks training and event supplies across four warehouse locations. It records stock coming in and going out, blocks bad entries, flags items that need reordering, and logs every change.

## Run it

Requires Python 3.9 or newer. No packages to install.

```bash
cd 03_Inventory-Management-System
python inventory_app.py
```

The repo includes `inventory_management.db` with sample data. To reset it to the original sample data:

```bash
python create_database.py --force
```

If the database file is missing, the app builds it automatically.

## What it does

| Menu option | What happens |
|---|---|
| 1. Low stock / reorder report | Lists every item and location where stock is below the reorder level, largest shortage first |
| 2. Record a transaction | **Receipt** adds stock, **Fulfillment** removes it, **Adjustment** corrects a count (+ or -) at the location you pick |
| 3. Dashboard | SKU count, units in stock, stock value, items below reorder level, last 5 transactions |

## Data checks

- Quantity must be a whole number; the app re-asks until it gets one.
- Receipts and fulfillments must be greater than zero.
- A fulfillment or adjustment can't take stock below zero.
- An unknown SKU is rejected before anything is saved.
- Each change updates stock, writes a transaction record, and writes an audit log entry (old and new quantity, who made it) in one database transaction, so a failure never leaves half a change saved.

## Database

Six tables: `categories`, `locations`, `items`, `inventory` (quantity per item per location), `transactions`, and `audit_log`. The schema and sample data are in `create_database.py`.

## Tests

```bash
cd 03_Inventory-Management-System
python -m unittest discover tests
```

11 tests cover receipts, fulfillments, adjustments, rejected input, the audit log, and the reports. Each test runs on a temporary copy of the database.

## Files

| File | Purpose |
|---|---|
| `inventory_app.py` | The app: business rules plus the menu screens |
| `create_database.py` | Builds the database schema and sample data |
| `inventory_management.db` | Sample database (SQLite) |
| `tests/test_inventory_app.py` | Unit tests |
