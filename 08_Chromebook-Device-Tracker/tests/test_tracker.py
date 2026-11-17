"""Tests for the business rules in tracker.py. Run: python -m unittest discover tests"""

import sqlite3
import sys
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import tracker  # noqa: E402

TODAY = date(2026, 11, 17)
SAMPLE = Path(__file__).resolve().parent.parent / "sample_data"


class TrackerTestCase(unittest.TestCase):
    def setUp(self):
        self.conn = tracker.connect(":memory:")
        tracker.init_db(self.conn)
        tracker.add_device(self.conn, "cb-1001", "SER1001", "Lenovo 100e", "Harbor Middle")
        tracker.add_device(self.conn, "CB-1002", "SER1002", "Lenovo 100e", "Harbor Middle")
        tracker.add_student(self.conn, "2033290", "Isabella", "Garcia", 6, "Harbor Middle")
        tracker.add_student(self.conn, "2031063", "Liam", "O'Brien", 8, "Harbor Middle")

    def tearDown(self):
        self.conn.close()

    def status(self, tag):
        return tracker.get_device(self.conn, tag)["status"]


class AddTests(TrackerTestCase):
    def test_asset_tags_are_stored_in_uppercase(self):
        self.assertEqual(tracker.get_device(self.conn, "CB-1001")["asset_tag"], "CB-1001")

    def test_duplicate_device_is_rejected(self):
        with self.assertRaises(tracker.TrackerError):
            tracker.add_device(self.conn, "CB-1001", "OTHER", "Acer", "Harbor Middle")

    def test_kindergarten_is_grade_zero(self):
        tracker.add_student(self.conn, "2037003", "Fatima", "Ali", "K", "Crestview Elementary")
        self.assertEqual(tracker.get_student(self.conn, "2037003")["grade"], 0)

    def test_bad_grade_and_id_are_rejected(self):
        with self.assertRaises(tracker.TrackerError):
            tracker.add_student(self.conn, "2037004", "Ben", "Turner", 14, "Pacific Crest High")
        with self.assertRaises(tracker.TrackerError):
            tracker.add_student(self.conn, "S-1", "Rosa", "Diaz", 9, "Pacific Crest High")


class CheckoutTests(TrackerTestCase):
    def test_check_out_marks_device_checked_out(self):
        tracker.check_out(self.conn, "CB-1001", "2033290", "2027-06-11", today=TODAY)
        self.assertEqual(self.status("CB-1001"), "Checked out")

    def test_device_cannot_go_to_two_students(self):
        tracker.check_out(self.conn, "CB-1001", "2033290", "2027-06-11", today=TODAY)
        with self.assertRaisesRegex(tracker.TrackerError, "not available"):
            tracker.check_out(self.conn, "CB-1001", "2031063", "2027-06-11", today=TODAY)

    def test_student_cannot_have_two_devices(self):
        tracker.check_out(self.conn, "CB-1001", "2033290", "2027-06-11", today=TODAY)
        with self.assertRaisesRegex(tracker.TrackerError, "already has CB-1001"):
            tracker.check_out(self.conn, "CB-1002", "2033290", "2027-06-11", today=TODAY)

    def test_due_date_cannot_be_in_the_past(self):
        with self.assertRaisesRegex(tracker.TrackerError, "past"):
            tracker.check_out(self.conn, "CB-1001", "2033290", "2026-11-01", today=TODAY)

    def test_inactive_student_cannot_check_out(self):
        self.conn.execute("UPDATE students SET active = 0 WHERE student_id = '2031063'")
        with self.assertRaisesRegex(tracker.TrackerError, "not active"):
            tracker.check_out(self.conn, "CB-1001", "2031063", "2027-06-11", today=TODAY)

    def test_database_also_blocks_double_checkout(self):
        # Even if code skipped the checks, the unique index stops a second open checkout
        tracker.check_out(self.conn, "CB-1001", "2033290", "2027-06-11", today=TODAY)
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("INSERT INTO checkouts (device_id, student_id, checked_out, due) "
                              "VALUES (1, 2, '2026-11-17', '2027-06-11')")


class CheckInAndRepairTests(TrackerTestCase):
    def setUp(self):
        super().setUp()
        tracker.check_out(self.conn, "CB-1001", "2033290", "2027-06-11", today=TODAY)

    def test_check_in_without_damage_makes_device_available(self):
        self.assertIsNone(tracker.check_in(self.conn, "CB-1001", today=TODAY))
        self.assertEqual(self.status("CB-1001"), "Available")

    def test_check_in_with_damage_opens_a_repair(self):
        repair_id = tracker.check_in(self.conn, "CB-1001", "Damaged", "Won't power on", "HD-1006", today=TODAY)
        self.assertIsNotNone(repair_id)
        self.assertEqual(self.status("CB-1001"), "In repair")
        repair = tracker.list_repairs(self.conn, "Open")[0]
        self.assertEqual((repair["asset_tag"], repair["ticket"]), ("CB-1001", "HD-1006"))

    def test_cannot_check_in_a_device_that_is_not_out(self):
        with self.assertRaises(tracker.TrackerError):
            tracker.check_in(self.conn, "CB-1002", today=TODAY)

    def test_fixed_repair_returns_device_to_service(self):
        repair_id = tracker.check_in(self.conn, "CB-1001", damage="Cracked screen", today=TODAY)
        tracker.close_repair(self.conn, repair_id, fixed=True, cost="89.00", today=TODAY)
        self.assertEqual(self.status("CB-1001"), "Available")
        self.assertEqual(tracker.dashboard(self.conn, TODAY)["repair_cost_this_year"], 89.0)

    def test_unrepairable_device_is_retired(self):
        repair_id = tracker.check_in(self.conn, "CB-1001", damage="Liquid damage", today=TODAY)
        tracker.close_repair(self.conn, repair_id, fixed=False, today=TODAY)
        self.assertEqual(self.status("CB-1001"), "Retired")

    def test_repair_cannot_be_closed_twice_or_with_negative_cost(self):
        repair_id = tracker.check_in(self.conn, "CB-1001", damage="Keyboard", today=TODAY)
        with self.assertRaises(tracker.TrackerError):
            tracker.close_repair(self.conn, repair_id, cost=-5, today=TODAY)
        tracker.close_repair(self.conn, repair_id, cost=10, today=TODAY)
        with self.assertRaises(tracker.TrackerError):
            tracker.close_repair(self.conn, repair_id, today=TODAY)

    def test_checked_out_device_must_be_checked_in_before_repair(self):
        with self.assertRaisesRegex(tracker.TrackerError, "checked out"):
            tracker.open_repair(self.conn, "CB-1001", "Trackpad", today=TODAY)


class ReportTests(TrackerTestCase):
    def test_overdue_lists_only_unreturned_past_due(self):
        tracker.check_out(self.conn, "CB-1001", "2033290", "2026-11-20", today=date(2026, 11, 10))
        tracker.check_out(self.conn, "CB-1002", "2031063", "2026-11-12", today=date(2026, 11, 10))
        overdue = tracker.overdue_checkouts(self.conn, TODAY)
        self.assertEqual([r["asset_tag"] for r in overdue], ["CB-1002"])
        self.assertEqual(overdue[0]["days_overdue"], 5)
        self.assertIn("CB-1002", tracker.overdue_csv(self.conn, TODAY))

    def test_dashboard_counts(self):
        tracker.check_out(self.conn, "CB-1001", "2033290", "2027-06-11", today=TODAY)
        d = tracker.dashboard(self.conn, TODAY)
        self.assertEqual(d["counts"]["Checked out"], 1)
        self.assertEqual(d["counts"]["Available"], 1)
        self.assertEqual(d["total"], 2)
        self.assertEqual(d["school_year_start"], date(2026, 7, 1))

    def test_default_due_date_is_second_friday_of_june(self):
        self.assertEqual(tracker.default_due_date(TODAY), date(2027, 6, 11))
        self.assertEqual(tracker.default_due_date(date(2027, 3, 1)), date(2027, 6, 11))


class ImportTests(TrackerTestCase):
    def test_device_import_adds_good_rows_and_explains_bad_ones(self):
        result = tracker.import_csv(self.conn, (SAMPLE / "devices.csv").read_text(encoding="utf-8"), "devices")
        self.assertEqual(result["added"], 3)
        self.assertEqual([line for line, _ in result["skipped"]], [5, 6, 7])

    def test_student_import_adds_good_rows_and_explains_bad_ones(self):
        result = tracker.import_csv(self.conn, (SAMPLE / "students.csv").read_text(encoding="utf-8"), "students")
        self.assertEqual(result["added"], 3)
        self.assertEqual(len(result["skipped"]), 3)

    def test_missing_columns_are_reported(self):
        with self.assertRaisesRegex(tracker.TrackerError, "missing these columns: serial"):
            tracker.import_csv(self.conn, "asset_tag,model,school\nCB-9,Acer,Harbor Middle\n", "devices")

    def test_excel_byte_order_mark_is_ignored(self):
        text = "﻿asset_tag,serial,model,school\nCB-9,S9,Acer,Harbor Middle\n"
        self.assertEqual(tracker.import_csv(self.conn, text, "devices")["added"], 1)


if __name__ == "__main__":
    unittest.main()
