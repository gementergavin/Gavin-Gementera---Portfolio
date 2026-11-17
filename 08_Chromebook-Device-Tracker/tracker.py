"""
Business rules and database access for the Chromebook Device Tracker.

Everything here works on a plain sqlite3 connection, so it can be tested
without the web app. The Flask app in app.py calls these functions.

Device life cycle:
    Available   --check_out-->                    Checked out
    Checked out --check_in-->                     Available
    Checked out --check_in (damage noted)-->      In repair
    Available   --open_repair-->                  In repair
    In repair   --close_repair (fixed)-->         Available
    In repair   --close_repair (not repairable)--> Retired
"""

import csv
import io
import sqlite3
from datetime import date, timedelta
from pathlib import Path

SCHEMA_PATH = Path(__file__).with_name("schema.sql")
DEVICE_STATUSES = ("Available", "Checked out", "In repair", "Retired")


class TrackerError(Exception):
    """A request that breaks a business rule. The message is safe to show users."""


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

def connect(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(conn):
    conn.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
    conn.commit()


def _today(today):
    return today or date.today()


def _parse_date(value, field):
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value).strip())
    except ValueError:
        raise TrackerError(f"{field} must be a date like 2027-06-11.") from None


# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------

def get_device(conn, asset_tag):
    row = conn.execute("SELECT * FROM devices WHERE asset_tag = ?",
                       (asset_tag.strip().upper(),)).fetchone()
    if row is None:
        raise TrackerError(f"No device with asset tag {asset_tag}.")
    return row


def get_student(conn, student_id):
    row = conn.execute("SELECT * FROM students WHERE student_id = ?",
                       (str(student_id).strip(),)).fetchone()
    if row is None:
        raise TrackerError(f"No student with ID {student_id}.")
    return row


def open_checkout_for_device(conn, device_id):
    return conn.execute(
        """SELECT c.*, s.student_id AS student_number, s.first_name, s.last_name
           FROM checkouts c JOIN students s ON s.id = c.student_id
           WHERE c.device_id = ? AND c.returned IS NULL""",
        (device_id,)).fetchone()


def list_devices(conn, status=None, school=None, search=None):
    sql = "SELECT * FROM devices WHERE 1 = 1"
    params = []
    if status:
        sql += " AND status = ?"
        params.append(status)
    if school:
        sql += " AND school = ?"
        params.append(school)
    if search:
        sql += " AND (asset_tag LIKE ? OR serial LIKE ? OR model LIKE ?)"
        like = f"%{search.strip()}%"
        params += [like, like, like]
    return conn.execute(sql + " ORDER BY asset_tag", params).fetchall()


def list_students(conn, search=None):
    sql = """SELECT s.*, d.asset_tag AS device_tag, c.due AS due
             FROM students s
             LEFT JOIN checkouts c ON c.student_id = s.id AND c.returned IS NULL
             LEFT JOIN devices d ON d.id = c.device_id
             WHERE 1 = 1"""
    params = []
    if search:
        sql += " AND (s.student_id LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ?)"
        like = f"%{search.strip()}%"
        params += [like, like, like]
    return conn.execute(sql + " ORDER BY s.last_name, s.first_name", params).fetchall()


def list_schools(conn):
    return [r[0] for r in conn.execute("SELECT DISTINCT school FROM devices ORDER BY school")]


def device_history(conn, device_id):
    checkouts = conn.execute(
        """SELECT c.*, s.student_id AS student_number, s.first_name, s.last_name
           FROM checkouts c JOIN students s ON s.id = c.student_id
           WHERE c.device_id = ? ORDER BY c.checked_out DESC, c.id DESC""",
        (device_id,)).fetchall()
    repairs = conn.execute(
        "SELECT * FROM repairs WHERE device_id = ? ORDER BY opened DESC, id DESC",
        (device_id,)).fetchall()
    return checkouts, repairs


def list_repairs(conn, status=None):
    sql = """SELECT r.*, d.asset_tag, d.model, d.school
             FROM repairs r JOIN devices d ON d.id = r.device_id"""
    params = []
    if status:
        sql += " WHERE r.status = ?"
        params.append(status)
    return conn.execute(sql + " ORDER BY r.status = 'Open' DESC, r.opened DESC", params).fetchall()


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

def add_device(conn, asset_tag, serial, model, school, purchased=None, notes=None):
    asset_tag = (asset_tag or "").strip().upper()
    serial = (serial or "").strip().upper()
    model = (model or "").strip()
    school = (school or "").strip()
    if not all([asset_tag, serial, model, school]):
        raise TrackerError("Asset tag, serial, model and school are required.")
    if purchased:
        purchased = _parse_date(purchased, "Purchase date").isoformat()
    try:
        cur = conn.execute(
            "INSERT INTO devices (asset_tag, serial, model, school, purchased, notes) VALUES (?, ?, ?, ?, ?, ?)",
            (asset_tag, serial, model, school, purchased, notes))
    except sqlite3.IntegrityError:
        raise TrackerError(f"A device with asset tag {asset_tag} or serial {serial} already exists.") from None
    conn.commit()
    return cur.lastrowid


def add_student(conn, student_id, first_name, last_name, grade, school):
    student_id = str(student_id or "").strip()
    first_name = (first_name or "").strip()
    last_name = (last_name or "").strip()
    school = (school or "").strip()
    if not all([student_id, first_name, last_name, school]):
        raise TrackerError("Student ID, first name, last name and school are required.")
    if not student_id.isdigit():
        raise TrackerError(f"Student ID {student_id} must be digits only.")
    try:
        grade = int(str(grade).strip().upper().replace("K", "0"))
    except ValueError:
        raise TrackerError(f"Grade {grade} must be K or 1-12.") from None
    if not 0 <= grade <= 12:
        raise TrackerError(f"Grade {grade} must be K or 1-12.")
    try:
        cur = conn.execute(
            "INSERT INTO students (student_id, first_name, last_name, grade, school) VALUES (?, ?, ?, ?, ?)",
            (student_id, first_name, last_name, grade, school))
    except sqlite3.IntegrityError:
        raise TrackerError(f"Student ID {student_id} already exists.") from None
    conn.commit()
    return cur.lastrowid


def check_out(conn, asset_tag, student_id, due, notes=None, today=None):
    """Lend a device to a student. Returns the new checkout id."""
    today = _today(today)
    device = get_device(conn, asset_tag)
    student = get_student(conn, student_id)
    due = _parse_date(due, "Due date")

    if device["status"] != "Available":
        raise TrackerError(f"{device['asset_tag']} is {device['status'].lower()}, not available.")
    if not student["active"]:
        raise TrackerError(f"Student {student['student_id']} is not active.")
    has_device = conn.execute(
        "SELECT d.asset_tag FROM checkouts c JOIN devices d ON d.id = c.device_id "
        "WHERE c.student_id = ? AND c.returned IS NULL", (student["id"],)).fetchone()
    if has_device:
        raise TrackerError(f"{student['first_name']} {student['last_name']} already has "
                           f"{has_device['asset_tag']}. Check it in first.")
    if due < today:
        raise TrackerError("Due date can't be in the past.")

    with conn:
        cur = conn.execute(
            "INSERT INTO checkouts (device_id, student_id, checked_out, due, notes) VALUES (?, ?, ?, ?, ?)",
            (device["id"], student["id"], today.isoformat(), due.isoformat(), notes))
        conn.execute("UPDATE devices SET status = 'Checked out' WHERE id = ?", (device["id"],))
    return cur.lastrowid


def check_in(conn, asset_tag, condition="Good", damage=None, ticket=None, today=None):
    """
    Return a device. If damage is described, a repair is opened and the
    device goes to In repair; otherwise it's Available again.
    Returns the repair id if one was opened, else None.
    """
    today = _today(today)
    device = get_device(conn, asset_tag)
    checkout = open_checkout_for_device(conn, device["id"])
    if checkout is None:
        raise TrackerError(f"{device['asset_tag']} isn't checked out.")

    damage = (damage or "").strip()
    repair_id = None
    with conn:
        conn.execute("UPDATE checkouts SET returned = ?, condition_in = ? WHERE id = ?",
                     (today.isoformat(), condition, checkout["id"]))
        if damage:
            cur = conn.execute(
                "INSERT INTO repairs (device_id, opened, issue, ticket) VALUES (?, ?, ?, ?)",
                (device["id"], today.isoformat(), damage, ticket))
            repair_id = cur.lastrowid
            conn.execute("UPDATE devices SET status = 'In repair' WHERE id = ?", (device["id"],))
        else:
            conn.execute("UPDATE devices SET status = 'Available' WHERE id = ?", (device["id"],))
    return repair_id


def open_repair(conn, asset_tag, issue, ticket=None, today=None):
    """Send an available device to repair. Returns the repair id."""
    today = _today(today)
    device = get_device(conn, asset_tag)
    issue = (issue or "").strip()
    if not issue:
        raise TrackerError("Describe the problem.")
    if device["status"] == "Checked out":
        raise TrackerError(f"{device['asset_tag']} is checked out. Check it in with the damage noted instead.")
    if device["status"] != "Available":
        raise TrackerError(f"{device['asset_tag']} is {device['status'].lower()}.")
    with conn:
        cur = conn.execute("INSERT INTO repairs (device_id, opened, issue, ticket) VALUES (?, ?, ?, ?)",
                           (device["id"], today.isoformat(), issue, ticket))
        conn.execute("UPDATE devices SET status = 'In repair' WHERE id = ?", (device["id"],))
    return cur.lastrowid


def close_repair(conn, repair_id, fixed=True, cost=0, today=None):
    """Close a repair. Fixed devices become Available; others are Retired."""
    today = _today(today)
    repair = conn.execute("SELECT * FROM repairs WHERE id = ?", (repair_id,)).fetchone()
    if repair is None:
        raise TrackerError(f"No repair #{repair_id}.")
    if repair["status"] != "Open":
        raise TrackerError(f"Repair #{repair_id} is already closed.")
    try:
        cost = round(float(cost or 0), 2)
    except ValueError:
        raise TrackerError("Cost must be a number.") from None
    if cost < 0:
        raise TrackerError("Cost can't be negative.")

    status, device_status = ("Fixed", "Available") if fixed else ("Not repairable", "Retired")
    with conn:
        conn.execute("UPDATE repairs SET status = ?, cost = ?, closed = ? WHERE id = ?",
                     (status, cost, today.isoformat(), repair_id))
        conn.execute("UPDATE devices SET status = ? WHERE id = ?", (device_status, repair["device_id"]))


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

def overdue_checkouts(conn, today=None):
    today = _today(today)
    rows = conn.execute(
        """SELECT c.id, c.checked_out, c.due, d.asset_tag, d.model, d.school,
                  s.student_id AS student_number, s.first_name, s.last_name, s.grade
           FROM checkouts c
           JOIN devices d ON d.id = c.device_id
           JOIN students s ON s.id = c.student_id
           WHERE c.returned IS NULL AND c.due < ?
           ORDER BY c.due, s.last_name""",
        (today.isoformat(),)).fetchall()
    return [dict(r, days_overdue=(today - date.fromisoformat(r["due"])).days) for r in rows]


def dashboard(conn, today=None):
    today = _today(today)
    counts = {status: 0 for status in DEVICE_STATUSES}
    for row in conn.execute("SELECT status, COUNT(*) AS n FROM devices GROUP BY status"):
        counts[row["status"]] = row["n"]

    by_school = conn.execute(
        """SELECT school,
                  COUNT(*) AS total,
                  SUM(status = 'Available')   AS available,
                  SUM(status = 'Checked out') AS checked_out,
                  SUM(status = 'In repair')   AS in_repair,
                  SUM(status = 'Retired')     AS retired
           FROM devices GROUP BY school ORDER BY school""").fetchall()

    year_start = date(today.year if today.month >= 7 else today.year - 1, 7, 1)  # school year starts July 1
    repair_cost = conn.execute(
        "SELECT COALESCE(SUM(cost), 0) FROM repairs WHERE closed >= ?",
        (year_start.isoformat(),)).fetchone()[0]
    open_repairs = conn.execute("SELECT COUNT(*) FROM repairs WHERE status = 'Open'").fetchone()[0]
    in_service = sum(counts[s] for s in ("Available", "Checked out", "In repair"))

    return {
        "counts": counts,
        "total": sum(counts.values()),
        "in_service": in_service,
        "by_school": by_school,
        "overdue": overdue_checkouts(conn, today),
        "open_repairs": open_repairs,
        "repair_cost_this_year": round(repair_cost, 2),
        "school_year_start": year_start,
    }


def overdue_csv(conn, today=None):
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["Asset tag", "Model", "School", "Student ID", "Student", "Grade",
                     "Checked out", "Due", "Days overdue"])
    for r in overdue_checkouts(conn, today):
        writer.writerow([r["asset_tag"], r["model"], r["school"], r["student_number"],
                         f"{r['first_name']} {r['last_name']}", r["grade"],
                         r["checked_out"], r["due"], r["days_overdue"]])
    return out.getvalue()


# ---------------------------------------------------------------------------
# CSV import
# ---------------------------------------------------------------------------

DEVICE_COLUMNS = ("asset_tag", "serial", "model", "school")
STUDENT_COLUMNS = ("student_id", "first_name", "last_name", "grade", "school")


def import_csv(conn, text, kind):
    """
    Import devices or students from CSV text. Good rows are added; bad rows
    and duplicates are skipped. Returns {"added": n, "skipped": [(line, reason), ...]}.
    """
    if kind not in ("devices", "students"):
        raise ValueError(kind)
    required = DEVICE_COLUMNS if kind == "devices" else STUDENT_COLUMNS
    reader = csv.DictReader(io.StringIO(text.lstrip("﻿")))
    headers = [h.strip().lower() for h in (reader.fieldnames or [])]
    missing = [c for c in required if c not in headers]
    if missing:
        raise TrackerError(f"The CSV is missing these columns: {', '.join(missing)}.")

    added, skipped = 0, []
    for line_number, raw in enumerate(reader, start=2):
        row = {(k or "").strip().lower(): (v or "").strip() for k, v in raw.items()}
        try:
            if kind == "devices":
                add_device(conn, row["asset_tag"], row["serial"], row["model"], row["school"],
                           row.get("purchased") or None, row.get("notes") or None)
            else:
                add_student(conn, row["student_id"], row["first_name"], row["last_name"],
                            row["grade"], row["school"])
            added += 1
        except TrackerError as err:
            skipped.append((line_number, str(err)))
    return {"added": added, "skipped": skipped}


def default_due_date(today=None):
    """Devices issued for the year are due back the second Friday of June."""
    today = _today(today)
    year = today.year + 1 if today.month >= 7 else today.year
    first = date(year, 6, 1)
    first_friday = first + timedelta(days=(4 - first.weekday()) % 7)
    return first_friday + timedelta(days=7)
