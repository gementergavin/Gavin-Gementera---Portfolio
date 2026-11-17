"""
Tests for inventory_app.py. Each test runs on a fresh copy of the sample
database in a temporary folder, so the real database is never touched.

Run from the 03_Inventory-Management-System folder:
    python -m unittest discover tests
"""

import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from create_database import build_database  # noqa: E402
from inventory_app import (  # noqa: E402
    InventoryError,
    dashboard_numbers,
    get_quantity,
    low_stock_items,
    record_transaction,
)

MIC = "AV-MIC-007"   # item 7: 94 on hand at location 1 in the sample data
SAN_DIEGO = 1


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        db_path = build_database(Path(self.tmp.name) / "test.db")
        self.conn = sqlite3.connect(db_path)

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def qty(self, item_id=7, location_id=SAN_DIEGO):
        return get_quantity(self.conn, item_id, location_id)

    def test_receipt_adds_stock(self):
        self.assertEqual(record_transaction(self.conn, "RECEIPT", MIC, 6, SAN_DIEGO, "Test"), 100)
        self.assertEqual(self.qty(), 100)

    def test_fulfillment_removes_stock(self):
        record_transaction(self.conn, "FULFILLMENT", MIC, 4, SAN_DIEGO, "Test")
        self.assertEqual(self.qty(), 90)

    def test_fulfillment_cannot_exceed_stock(self):
        with self.assertRaises(InventoryError):
            record_transaction(self.conn, "FULFILLMENT", MIC, 500, SAN_DIEGO, "Test")
        self.assertEqual(self.qty(), 94)

    def test_adjustment_changes_stock_both_ways(self):
        record_transaction(self.conn, "ADJUSTMENT", MIC, 5, SAN_DIEGO, "Test")
        self.assertEqual(self.qty(), 99)
        record_transaction(self.conn, "ADJUSTMENT", MIC, -9, SAN_DIEGO, "Test")
        self.assertEqual(self.qty(), 90)

    def test_adjustment_cannot_go_below_zero(self):
        with self.assertRaises(InventoryError):
            record_transaction(self.conn, "ADJUSTMENT", MIC, -95, SAN_DIEGO, "Test")
        self.assertEqual(self.qty(), 94)

    def test_negative_or_zero_receipt_rejected(self):
        for bad in (-500, 0):
            with self.assertRaises(InventoryError):
                record_transaction(self.conn, "RECEIPT", MIC, bad, SAN_DIEGO, "Test")
        self.assertEqual(self.qty(), 94)

    def test_non_number_quantity_rejected(self):
        with self.assertRaises(InventoryError):
            record_transaction(self.conn, "RECEIPT", MIC, "ten", SAN_DIEGO, "Test")

    def test_unknown_sku_rejected(self):
        with self.assertRaises(InventoryError):
            record_transaction(self.conn, "RECEIPT", "NOPE-000", 1, SAN_DIEGO, "Test")

    def test_every_change_is_logged(self):
        record_transaction(self.conn, "FULFILLMENT", MIC, 4, SAN_DIEGO, "Gavin", "Event kit")
        t_type, qty, who = self.conn.execute(
            "SELECT transaction_type, quantity, performed_by FROM transactions "
            "ORDER BY transaction_id DESC LIMIT 1").fetchone()
        self.assertEqual((t_type, qty, who), ("FULFILLMENT", 4, "Gavin"))
        old, new = self.conn.execute(
            "SELECT old_value, new_value FROM audit_log ORDER BY log_id DESC LIMIT 1").fetchone()
        self.assertEqual((old, new), ("94", "90"))

    def test_low_stock_report_finds_items_below_reorder_level(self):
        skus = {row[0] for row in low_stock_items(self.conn)}
        self.assertIn("SUP-BADGE-005", skus)   # 81-118 on hand, reorder level 200
        self.assertNotIn(MIC, skus)

    def test_dashboard_counts(self):
        numbers = dashboard_numbers(self.conn)
        self.assertEqual(numbers["total_skus"], 10)
        self.assertEqual(numbers["low_stock"], len(low_stock_items(self.conn)))


if __name__ == "__main__":
    unittest.main()
