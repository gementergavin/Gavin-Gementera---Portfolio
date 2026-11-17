#!/usr/bin/env python3
"""
Inventory Management System - command-line app

Tracks stock for training and event supplies across four locations.
Records receipts, fulfillments and adjustments, blocks bad input,
flags items below their reorder level, and writes every stock change
to an audit log.

Run:
    python inventory_app.py

If inventory_management.db is missing, the app builds it with sample
data (see create_database.py).
"""

import sqlite3
import sys
from datetime import datetime
from pathlib import Path

from create_database import DEFAULT_DB_PATH, build_database

TRANSACTION_TYPES = {"1": "RECEIPT", "2": "FULFILLMENT", "3": "ADJUSTMENT"}


class InventoryError(Exception):
    """A transaction that breaks a business rule (bad SKU, not enough stock, ...)."""


# ---------------------------------------------------------------------------
# Database access and business rules (no input/print here, so they can be tested)
# ---------------------------------------------------------------------------

def get_connection(db_path=DEFAULT_DB_PATH):
    db_path = Path(db_path)
    if not db_path.exists():
        print(f"No database found at {db_path.name}; creating one with sample data...")
        build_database(db_path)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def list_locations(conn):
    return conn.execute(
        "SELECT location_id, location_name FROM locations ORDER BY location_id"
    ).fetchall()


def find_item(conn, sku):
    row = conn.execute(
        "SELECT item_id, item_name FROM items WHERE sku = ?", (sku.strip().upper(),)
    ).fetchone()
    if row is None:
        raise InventoryError(f"SKU '{sku}' not found.")
    return row


def get_quantity(conn, item_id, location_id):
    row = conn.execute(
        "SELECT quantity_on_hand FROM inventory WHERE item_id = ? AND location_id = ?",
        (item_id, location_id),
    ).fetchone()
    if row is None:
        raise InventoryError("That item is not stocked at that location.")
    return row[0]


def record_transaction(conn, t_type, sku, quantity, location_id,
                       performed_by="Unknown User", notes=""):
    """
    Apply one stock movement and log it. Returns the new quantity on hand.

    RECEIPT      adds stock (quantity must be positive)
    FULFILLMENT  removes stock (quantity must be positive and available)
    ADJUSTMENT   corrects a count (quantity may be + or -, but not 0,
                 and stock can't go below zero)
    """
    if t_type not in TRANSACTION_TYPES.values():
        raise InventoryError(f"Unknown transaction type '{t_type}'.")
    if not isinstance(quantity, int) or isinstance(quantity, bool):
        raise InventoryError("Quantity must be a whole number.")
    if t_type in ("RECEIPT", "FULFILLMENT") and quantity <= 0:
        raise InventoryError(f"{t_type.title()} quantity must be greater than zero.")
    if t_type == "ADJUSTMENT" and quantity == 0:
        raise InventoryError("Adjustment quantity can't be zero.")

    item_id, _ = find_item(conn, sku)
    current = get_quantity(conn, item_id, location_id)
    change = -quantity if t_type == "FULFILLMENT" else quantity
    new_qty = current + change
    if new_qty < 0:
        raise InventoryError(
            f"Not enough stock: {current} on hand, this would leave {new_qty}."
        )

    performed_by = performed_by.strip() or "Unknown User"
    now = datetime.now().isoformat(timespec="seconds")
    with conn:  # one database transaction: all three writes happen, or none do
        conn.execute(
            """UPDATE inventory SET quantity_on_hand = ?, last_counted = ?
               WHERE item_id = ? AND location_id = ?""",
            (new_qty, now, item_id, location_id),
        )
        from_loc = location_id if change < 0 else None
        to_loc = location_id if change > 0 else None
        cur = conn.execute(
            """INSERT INTO transactions (transaction_type, item_id, from_location_id,
                                         to_location_id, quantity, notes, performed_by)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (t_type, item_id, from_loc, to_loc, quantity, notes, performed_by),
        )
        conn.execute(
            """INSERT INTO audit_log (table_name, record_id, action, old_value,
                                      new_value, performed_by)
               VALUES ('inventory', ?, ?, ?, ?, ?)""",
            (cur.lastrowid, t_type, str(current), str(new_qty), performed_by),
        )
    return new_qty


def low_stock_items(conn):
    return conn.execute("""
        SELECT i.sku, i.item_name, l.location_name, inv.quantity_on_hand,
               i.reorder_level, i.reorder_level - inv.quantity_on_hand AS shortage
        FROM inventory inv
        JOIN items i     ON inv.item_id = i.item_id
        JOIN locations l ON inv.location_id = l.location_id
        WHERE inv.quantity_on_hand < i.reorder_level
        ORDER BY shortage DESC, l.location_name
    """).fetchall()


def dashboard_numbers(conn):
    total_skus = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
    total_units = conn.execute("SELECT COALESCE(SUM(quantity_on_hand), 0) FROM inventory").fetchone()[0]
    stock_value = conn.execute("""
        SELECT COALESCE(SUM(inv.quantity_on_hand * i.unit_cost), 0)
        FROM inventory inv JOIN items i ON inv.item_id = i.item_id
    """).fetchone()[0]
    recent = conn.execute("""
        SELECT t.transaction_date, t.transaction_type, i.sku, t.quantity, t.performed_by
        FROM transactions t JOIN items i ON t.item_id = i.item_id
        ORDER BY t.transaction_id DESC
        LIMIT 5
    """).fetchall()
    return {
        "total_skus": total_skus,
        "total_units": total_units,
        "stock_value": stock_value,
        "low_stock": len(low_stock_items(conn)),
        "recent": recent,
    }


# ---------------------------------------------------------------------------
# Command-line screens
# ---------------------------------------------------------------------------

def ask_int(prompt, allow_negative=False):
    """Keep asking until the user types a whole number that isn't zero
    (and isn't negative, unless allow_negative is True)."""
    while True:
        text = input(prompt).strip()
        try:
            value = int(text)
        except ValueError:
            print("  Please enter a whole number (for example 12).")
            continue
        if value == 0 or (value < 0 and not allow_negative):
            hint = "a number other than zero" if allow_negative else "a number greater than zero"
            print(f"  Please enter {hint}.")
            continue
        return value


def ask_location(conn):
    locations = list_locations(conn)
    for loc_id, name in locations:
        print(f"  {loc_id}. {name}")
    valid = {loc_id for loc_id, _ in locations}
    while True:
        choice = ask_int("Select location: ")
        if choice in valid:
            return choice
        print("  Please pick one of the numbers listed.")


def show_low_stock_report(conn):
    print("\n" + "=" * 80)
    print("LOW STOCK / REORDER REPORT")
    print("=" * 80)
    rows = low_stock_items(conn)
    if not rows:
        print("No items are below their reorder level.")
        return
    print(f"{'SKU':<14}{'Item':<38}{'Location':<26}{'On hand':>8}{'Reorder at':>11}{'Short':>7}")
    print("-" * 104)
    for sku, name, location, on_hand, reorder, short in rows:
        print(f"{sku:<14}{name[:36]:<38}{location[:24]:<26}{on_hand:>8}{reorder:>11}{short:>7}")
    print(f"\nItems needing attention: {len(rows)}")


def record_transaction_screen(conn):
    print("\n--- Record a transaction ---")
    print("1. Receipt (add stock)")
    print("2. Fulfillment (remove stock for a training or event)")
    print("3. Adjustment (correct a count; use a negative number to reduce)")
    choice = input("Select type (1-3): ").strip()
    t_type = TRANSACTION_TYPES.get(choice)
    if t_type is None:
        print("Invalid choice.")
        return

    sku = input("SKU (e.g. AV-MIC-007): ").strip().upper()
    try:
        _, item_name = find_item(conn, sku)
    except InventoryError as err:
        print(err)
        return
    print(f"  Item: {item_name}")

    location_id = ask_location(conn)
    quantity = ask_int("Quantity: ", allow_negative=(t_type == "ADJUSTMENT"))
    performed_by = input("Your name: ")
    notes = input("Notes / reference (optional): ").strip()

    try:
        new_qty = record_transaction(conn, t_type, sku, quantity, location_id, performed_by, notes)
    except InventoryError as err:
        print(f"Not recorded: {err}")
        return
    print(f"Recorded {t_type.lower()} of {quantity} for {sku}. New quantity on hand: {new_qty}.")


def show_dashboard(conn):
    numbers = dashboard_numbers(conn)
    print("\n" + "=" * 80)
    print("INVENTORY DASHBOARD")
    print("=" * 80)
    print(f"Active SKUs:               {numbers['total_skus']}")
    print(f"Units in stock:            {numbers['total_units']:,}")
    print(f"Stock value:               ${numbers['stock_value']:,.2f}")
    flag = "ACTION NEEDED" if numbers["low_stock"] else "OK"
    print(f"Below reorder level:       {numbers['low_stock']}  ({flag})")
    print("\nLast 5 transactions:")
    for date, t_type, sku, qty, who in numbers["recent"]:
        print(f"  {str(date)[:16]} | {t_type:<11} | {sku:<14} | qty {qty:>4} | {who}")


def main_menu(conn):
    actions = {
        "1": show_low_stock_report,
        "2": record_transaction_screen,
        "3": show_dashboard,
    }
    while True:
        print("\n" + "=" * 80)
        print("INVENTORY MANAGEMENT SYSTEM")
        print("=" * 80)
        print("1. Low stock / reorder report")
        print("2. Record a transaction (receipt, fulfillment, adjustment)")
        print("3. Dashboard")
        print("4. Exit")
        choice = input("\nSelect option (1-4): ").strip()
        if choice == "4":
            print("Goodbye.")
            return
        action = actions.get(choice)
        if action:
            action(conn)
        else:
            print("Invalid option. Please try again.")


def main():
    conn = get_connection()
    try:
        main_menu(conn)
    except (KeyboardInterrupt, EOFError):
        print("\nGoodbye.")
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
