"""Tests for the web pages in app.py, using Flask's test client."""

import io
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import tracker  # noqa: E402
from app import create_app  # noqa: E402

TODAY = date(2026, 11, 17)


class AppTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        db_path = Path(self.tmp.name) / "test.db"
        conn = tracker.connect(db_path)
        tracker.init_db(conn)
        tracker.add_device(conn, "CB-1001", "SER1001", "Lenovo 100e", "Harbor Middle")
        tracker.add_device(conn, "CB-1002", "SER1002", "Acer Chromebook 511", "Harbor Middle")
        tracker.add_student(conn, "2033290", "Isabella", "Garcia", 6, "Harbor Middle")
        tracker.add_student(conn, "2031063", "Liam", "O'Brien", 8, "Harbor Middle")
        tracker.check_out(conn, "CB-1002", "2031063", "2026-11-14", today=date(2026, 11, 7))  # overdue
        conn.close()
        self.app = create_app(db_path, today=TODAY)
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()

    def tearDown(self):
        self.tmp.cleanup()

    def test_every_page_loads(self):
        for path in ["/", "/devices", "/devices/CB-1001", "/students", "/checkout", "/repairs", "/import",
                     "/devices?status=Available", "/devices?q=acer", "/students?q=garcia"]:
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)

    def test_dashboard_shows_overdue_device(self):
        page = self.client.get("/").get_data(as_text=True)
        self.assertIn("CB-1002", page)
        self.assertIn("O&#39;Brien", page)  # names are HTML-escaped

    def test_unknown_device_is_404(self):
        self.assertEqual(self.client.get("/devices/CB-9999").status_code, 404)

    def test_check_out_then_check_in_with_damage(self):
        r = self.client.post("/checkout", data={"asset_tag": "cb-1001", "student_id": "2033290",
                                                "due": "2027-06-11"}, follow_redirects=True)
        self.assertIn("Checked out CB-1001", r.get_data(as_text=True))

        r = self.client.post("/checkin/CB-1001", data={"condition": "Damaged", "damage": "Won't power on",
                                                       "ticket": "HD-1006"}, follow_redirects=True)
        page = r.get_data(as_text=True)
        self.assertIn("Repair #1 opened", page)
        self.assertIn("In repair", page)

    def test_rule_errors_are_shown_not_crashed(self):
        r = self.client.post("/checkout", data={"asset_tag": "CB-1002", "student_id": "2033290",
                                                "due": "2027-06-11"}, follow_redirects=True)
        self.assertEqual(r.status_code, 200)
        self.assertIn("not available", r.get_data(as_text=True))

    def test_close_repair(self):
        self.client.post("/repairs/new", data={"asset_tag": "CB-1001", "issue": "Trackpad"})
        r = self.client.post("/repairs/1/close", data={"outcome": "fixed", "cost": "40"}, follow_redirects=True)
        self.assertIn("Repair #1 closed", r.get_data(as_text=True))

    def test_overdue_csv_download(self):
        r = self.client.get("/reports/overdue.csv")
        self.assertEqual(r.mimetype, "text/csv")
        self.assertIn("CB-1002", r.get_data(as_text=True))
        self.assertIn("attachment", r.headers["Content-Disposition"])

    def test_csv_import_upload(self):
        csv_bytes = b"asset_tag,serial,model,school\nCB-3001,S3001,Acer,Harbor Middle\nCB-1001,DUP,Acer,Harbor Middle\n"
        r = self.client.post("/import", data={"kind": "devices", "file": (io.BytesIO(csv_bytes), "devices.csv")},
                             content_type="multipart/form-data")
        page = r.get_data(as_text=True)
        self.assertIn("Imported 1 devices", page)
        self.assertIn("already exists", page)


if __name__ == "__main__":
    unittest.main()
