#!/usr/bin/env python3
"""
Builds (or rebuilds) the SQLite database used by inventory_app.py.

Creates the schema and loads sample data: 5 categories, 4 locations,
10 items, stock levels for every item at every location, and 35
historical transactions.

Usage:
    python create_database.py            # creates inventory_management.db
    python create_database.py --force    # deletes and rebuilds it
"""

import argparse
import sqlite3
from pathlib import Path

DEFAULT_DB_PATH = Path(__file__).parent / "inventory_management.db"

SCHEMA = """
CREATE TABLE categories (
    category_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    category_name TEXT NOT NULL UNIQUE,
    description   TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE locations (
    location_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    location_name  TEXT NOT NULL UNIQUE,
    address        TEXT,
    contact_person TEXT,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE items (
    item_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    sku              TEXT NOT NULL UNIQUE,
    item_name        TEXT NOT NULL,
    description      TEXT,
    category_id      INTEGER,
    unit_cost        REAL CHECK (unit_cost >= 0),
    reorder_level    INTEGER DEFAULT 10 CHECK (reorder_level >= 0),
    reorder_quantity INTEGER DEFAULT 50 CHECK (reorder_quantity >= 0),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE inventory (
    inventory_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id           INTEGER NOT NULL,
    location_id       INTEGER NOT NULL,
    quantity_on_hand  INTEGER DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INTEGER DEFAULT 0 CHECK (quantity_reserved >= 0),
    last_counted      TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items(item_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    UNIQUE (item_id, location_id)
);

CREATE TABLE transactions (
    transaction_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_type TEXT NOT NULL
        CHECK (transaction_type IN ('RECEIPT', 'FULFILLMENT', 'ADJUSTMENT', 'TRANSFER')),
    item_id          INTEGER NOT NULL,
    from_location_id INTEGER,
    to_location_id   INTEGER,
    quantity         INTEGER NOT NULL,
    unit_cost        REAL,
    reference_number TEXT,
    notes            TEXT,
    performed_by     TEXT,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items(item_id),
    FOREIGN KEY (from_location_id) REFERENCES locations(location_id),
    FOREIGN KEY (to_location_id) REFERENCES locations(location_id)
);

CREATE TABLE audit_log (
    log_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name   TEXT NOT NULL,
    record_id    INTEGER,
    action       TEXT NOT NULL,
    old_value    TEXT,
    new_value    TEXT,
    performed_by TEXT,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""

SEED_TIME = "2026-07-07 18:27:27"

CATEGORIES = [
    ("Training Materials", "Printed workbooks, participant guides, handouts"),
    ("Facilitator Resources", "Trainer manuals, slide decks, activity kits"),
    ("Event Supplies", "Name badges, signage, registration materials"),
    ("Technology & AV", "Laptops, projectors, microphones, cables"),
    ("Wellness & Promotional", "Branded items, water bottles, journals"),
]

LOCATIONS = [
    ("San Diego Main Warehouse", "1234 Mission Valley Rd, San Diego, CA 92108", "Maria Gonzalez"),
    ("Riverside Regional Hub", "5678 University Ave, Riverside, CA 92501", "James Chen"),
    ("Los Angeles Training Center", "9010 Wilshire Blvd, Los Angeles, CA 90036", "Aisha Patel"),
    ("Central Valley Storage", "1122 Fresno St, Fresno, CA 93721", "David Kim"),
]

# sku, name, description, category_id, unit_cost, reorder_level, reorder_quantity
ITEMS = [
    ("WB-CW-001", "Child Welfare Core Practice Workbook", "Full participant workbook for 5-day core training", 1, 12.50, 25, 100),
    ("FM-MI-002", "Motivational Interviewing Facilitator Manual", "Trainer guide with activities and scripts", 2, 28.00, 10, 30),
    ("EB-TIC-003", "Trauma-Informed Care Participant Guide", "Updated 2025 edition", 1, 9.75, 40, 150),
    ("AV-PROJ-004", "Portable Projector - Epson", "Standard AV kit for regional trainings", 4, 245.00, 3, 5),
    ("SUP-BADGE-005", "Name Badge Holder + Lanyard (Branded)", "Organization branded", 3, 2.85, 200, 500),
    ("WM-JRNL-006", "Recovery Journal - Participant", "For behavioral health programs", 5, 4.20, 50, 200),
    ("AV-MIC-007", "Wireless Microphone Kit", "For larger venues", 4, 89.00, 4, 8),
    ("FM-SUP-008", "Supervision Skills Participant Workbook", "Leadership development series", 1, 11.25, 20, 80),
    ("TECH-LAP-009", "Training Laptop - Dell Latitude", "Loaner laptops for facilitators", 4, 675.00, 2, 4),
    ("SUP-SIGN-010", "Retractable Banner - Organization Logo", "Event signage", 3, 65.00, 5, 12),
]

# Quantity on hand for each item (rows) at locations 1-4 (columns)
STOCK = [
    [119, 41, 99, 71],
    [81, 94, 16, 115],
    [106, 67, 55, 107],
    [49, 34, 103, 113],
    [81, 94, 94, 118],
    [95, 78, 31, 111],
    [94, 45, 25, 115],
    [50, 21, 74, 109],
    [101, 45, 74, 119],
    [24, 74, 91, 43],
]

# type, item_id, location_id, quantity
HISTORY = [
    ("ADJUSTMENT", 8, 3, 15), ("ADJUSTMENT", 10, 1, 7), ("ADJUSTMENT", 5, 4, 11),
    ("ADJUSTMENT", 7, 3, 40), ("FULFILLMENT", 4, 1, 11), ("FULFILLMENT", 8, 3, 39),
    ("RECEIPT", 10, 2, 37), ("RECEIPT", 10, 4, 40), ("RECEIPT", 2, 3, 5),
    ("RECEIPT", 7, 4, 8), ("ADJUSTMENT", 6, 3, 32), ("ADJUSTMENT", 3, 4, 9),
    ("FULFILLMENT", 4, 4, 39), ("RECEIPT", 4, 4, 13), ("FULFILLMENT", 4, 1, 19),
    ("FULFILLMENT", 5, 4, 9), ("RECEIPT", 2, 2, 12), ("FULFILLMENT", 6, 3, 23),
    ("ADJUSTMENT", 9, 3, 6), ("ADJUSTMENT", 4, 3, 23), ("ADJUSTMENT", 5, 1, 27),
    ("FULFILLMENT", 5, 3, 6), ("FULFILLMENT", 1, 3, 40), ("RECEIPT", 10, 1, 38),
    ("FULFILLMENT", 5, 1, 38), ("RECEIPT", 3, 1, 17), ("FULFILLMENT", 6, 1, 36),
    ("FULFILLMENT", 3, 3, 25), ("FULFILLMENT", 4, 2, 24), ("ADJUSTMENT", 1, 1, 27),
    ("RECEIPT", 8, 4, 35), ("RECEIPT", 6, 4, 40), ("RECEIPT", 3, 2, 25),
    ("FULFILLMENT", 2, 4, 25), ("FULFILLMENT", 7, 4, 32),
]


def build_database(db_path=DEFAULT_DB_PATH, force=False):
    """Create the database file with schema and sample data. Returns its path."""
    db_path = Path(db_path)
    if db_path.exists():
        if not force:
            raise FileExistsError(f"{db_path} already exists. Use --force to rebuild it.")
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    try:
        conn.executescript(SCHEMA)
        conn.executemany(
            "INSERT INTO categories (category_name, description, created_at) VALUES (?, ?, ?)",
            [(name, desc, SEED_TIME) for name, desc in CATEGORIES],
        )
        conn.executemany(
            "INSERT INTO locations (location_name, address, contact_person, created_at) VALUES (?, ?, ?, ?)",
            [(*loc, SEED_TIME) for loc in LOCATIONS],
        )
        conn.executemany(
            """INSERT INTO items (sku, item_name, description, category_id, unit_cost,
                                  reorder_level, reorder_quantity, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            [(*item, SEED_TIME) for item in ITEMS],
        )
        conn.executemany(
            """INSERT INTO inventory (item_id, location_id, quantity_on_hand, last_counted)
               VALUES (?, ?, ?, ?)""",
            [
                (item_id, location_id, qty, SEED_TIME)
                for item_id, row in enumerate(STOCK, start=1)
                for location_id, qty in enumerate(row, start=1)
            ],
        )
        for t_type, item_id, location_id, qty in HISTORY:
            from_loc = location_id if t_type == "FULFILLMENT" else None
            to_loc = None if t_type == "FULFILLMENT" else location_id
            conn.execute(
                """INSERT INTO transactions (transaction_type, item_id, from_location_id,
                                             to_location_id, quantity, notes, performed_by,
                                             transaction_date)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (t_type, item_id, from_loc, to_loc, qty,
                 "Sample historical transaction", "System Import", SEED_TIME),
            )
        conn.commit()
    finally:
        conn.close()
    return db_path


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", default=DEFAULT_DB_PATH, help="path of the database file")
    parser.add_argument("--force", action="store_true", help="delete and rebuild an existing database")
    args = parser.parse_args()
    try:
        path = build_database(args.db, force=args.force)
    except FileExistsError as err:
        print(err)
        raise SystemExit(1)
    print(f"Database created: {path}")


if __name__ == "__main__":
    main()
