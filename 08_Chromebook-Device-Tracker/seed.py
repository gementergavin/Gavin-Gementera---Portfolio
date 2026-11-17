"""
Fill devices.db with sample data: 3 schools, 60 Chromebooks, 45 students,
year-long checkouts, a few overdue short-term loaners, and some repairs.

Dates are based on today, so the dashboard always has something to show.

    python seed.py            # creates devices.db (refuses to overwrite)
    python seed.py --force    # deletes and rebuilds it
"""

import argparse
import random
from datetime import date, timedelta
from pathlib import Path

import tracker

DB_PATH = Path(__file__).with_name("devices.db")

SCHOOLS = {
    "Pacific Crest High": range(9, 13),
    "Harbor Middle": range(6, 9),
    "Crestview Elementary": range(0, 6),
}
MODELS = ["Lenovo 100e Chromebook Gen 4", "Acer Chromebook 511", "Dell Chromebook 3110"]

# The first nine match students in the AD lab's user CSV (project 05)
NAMED_STUDENTS = [
    ("2029118", "Jayden", "Nguyen", 10, "Pacific Crest High"),
    ("2028204", "Emma", "Johnson", 11, "Pacific Crest High"),
    ("2032157", "José", "Núñez", 7, "Harbor Middle"),
    ("2031063", "Liam", "O'Brien", 8, "Harbor Middle"),
    ("2034412", "Ava", "Patel", 5, "Crestview Elementary"),
    ("2030377", "Noah", "Williams", 9, "Pacific Crest High"),
    ("2033290", "Isabella", "Garcia", 6, "Harbor Middle"),
    ("2035118", "Ethan", "Smith-Jones", 4, "Crestview Elementary"),
    ("2027451", "Maria", "Lopez", 12, "Pacific Crest High"),
]
FIRST = ["Olivia", "Lucas", "Mia", "Elijah", "Sophia", "Mateo", "Amelia", "Daniel", "Harper", "Henry",
         "Camila", "Jack", "Luna", "Sebastian", "Chloe", "Aiden", "Zoe", "Leo", "Nora", "Gabriel",
         "Riley", "Julian", "Layla", "Isaac", "Aria", "Ezra", "Ella", "Kai", "Hazel", "Ryan",
         "Grace", "Adrian", "Lily", "Owen", "Stella", "Diego"]
LAST = ["Martinez", "Kim", "Hernandez", "Wilson", "Anderson", "Thomas", "Moore", "Jackson", "Lee", "Perez",
        "Thompson", "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
        "Allen", "King", "Wright", "Scott", "Torres", "Hill", "Flores", "Green", "Adams", "Nelson",
        "Baker", "Hall", "Rivera", "Campbell", "Mitchell", "Carter"]


def build(db_path, today=None):
    today = today or date.today()
    rng = random.Random(2026)
    conn = tracker.connect(db_path)
    tracker.init_db(conn)

    # School year started on the third Monday of August
    year = today.year if today.month >= 8 else today.year - 1
    aug1 = date(year, 8, 1)
    first_day = aug1 + timedelta(days=(0 - aug1.weekday()) % 7 + 14)
    if first_day > today:
        first_day = today - timedelta(days=30)

    # ---- Devices: 20 per school
    tags = []
    number = 1001
    for school in SCHOOLS:
        for _ in range(20):
            tag = f"CB-{number}"
            serial = "".join(rng.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(10))
            tracker.add_device(conn, tag, serial, rng.choice(MODELS), school,
                               purchased=date(year - rng.choice([0, 1, 2]), 7, 15).isoformat())
            tags.append((tag, school))
            number += 1

    # ---- Students: 9 named + 36 generated
    students = list(NAMED_STUDENTS)
    sid = 2036001
    for first, last in zip(FIRST, LAST):
        school = rng.choice(list(SCHOOLS))
        students.append((str(sid), first, last, rng.choice(list(SCHOOLS[school])), school))
        sid += 1
    for s in students:
        tracker.add_student(conn, *s)

    # ---- Year-long checkouts on the first day: about 2 of every 3 students
    due = tracker.default_due_date(first_day)
    free = {school: [t for t, s in tags if s == school] for school in SCHOOLS}
    named = {s[0] for s in NAMED_STUDENTS}
    for student_id, _first, _last, _grade, school in students:
        if (student_id in named or rng.random() < 0.6) and len(free[school]) > 6:
            tracker.check_out(conn, free[school].pop(0), student_id, due, today=first_day)

    # ---- Repairs closed earlier this year (device back in service or retired)
    history = [
        ("Cracked screen", 89.00, True),
        ("Keyboard missing keys", 45.50, True),
        ("Charging port loose", 62.00, True),
        ("Liquid damage; motherboard failed", 0, False),
    ]
    for issue, cost, fixed in history:
        school = rng.choice(list(SCHOOLS))
        tag = free[school].pop()
        opened = first_day + timedelta(days=rng.randint(5, 20))
        repair_id = tracker.open_repair(conn, tag, issue, today=opened)
        tracker.close_repair(conn, repair_id, fixed=fixed, cost=cost, today=opened + timedelta(days=9))
        if fixed:
            free[school].insert(0, tag)

    # ---- Isabella Garcia's Chromebook won't turn on (help desk ticket HD-1006)
    isabella_device = tracker.list_students(conn, "2033290")[0]["device_tag"]
    if isabella_device:
        tracker.check_in(conn, isabella_device, condition="Damaged",
                         damage="Won't power on; charger swapped, hard reset tried",
                         ticket="HD-1006", today=today - timedelta(days=3))

    # ---- Another open repair on a spare device
    spare = free["Pacific Crest High"].pop()
    tracker.open_repair(conn, spare, "Trackpad not responding", ticket="HD-1022",
                        today=today - timedelta(days=1))

    # ---- Short-term loaners for students without a device: some are overdue
    without = [s for s in tracker.list_students(conn) if not s["device_tag"]]
    for i, s in enumerate(without[:6]):
        pool = free[s["school"]]
        if not pool:
            continue
        loan_day = today - timedelta(days=12 - i)
        loan_due = loan_day + timedelta(days=7)  # first few are past due
        tracker.check_out(conn, pool.pop(0), s["student_id"], loan_due,
                          notes="Short-term loaner", today=loan_day)

    conn.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--force", action="store_true", help="delete and rebuild devices.db")
    args = parser.parse_args()
    if DB_PATH.exists():
        if not args.force:
            raise SystemExit(f"{DB_PATH.name} already exists. Use --force to rebuild it.")
        DB_PATH.unlink()
    build(DB_PATH)
    conn = tracker.connect(DB_PATH)
    d = tracker.dashboard(conn)
    conn.close()
    print(f"Created {DB_PATH.name}: {d['total']} devices {d['counts']}, "
          f"{len(d['overdue'])} overdue, {d['open_repairs']} open repairs.")


if __name__ == "__main__":
    main()
