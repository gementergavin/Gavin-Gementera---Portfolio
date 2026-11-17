-- Chromebook Device Tracker schema (SQLite)

CREATE TABLE IF NOT EXISTS devices (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_tag  TEXT NOT NULL UNIQUE,
    serial     TEXT NOT NULL UNIQUE,
    model      TEXT NOT NULL,
    school     TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'Available'
               CHECK (status IN ('Available', 'Checked out', 'In repair', 'Retired')),
    purchased  TEXT,
    notes      TEXT
);

CREATE TABLE IF NOT EXISTS students (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name  TEXT NOT NULL,
    grade      INTEGER NOT NULL CHECK (grade BETWEEN 0 AND 12),
    school     TEXT NOT NULL,
    active     INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS checkouts (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id     INTEGER NOT NULL REFERENCES devices(id),
    student_id    INTEGER NOT NULL REFERENCES students(id),
    checked_out   TEXT NOT NULL,
    due           TEXT NOT NULL,
    returned      TEXT,
    condition_in  TEXT,
    notes         TEXT
);

CREATE TABLE IF NOT EXISTS repairs (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL REFERENCES devices(id),
    opened    TEXT NOT NULL,
    issue     TEXT NOT NULL,
    ticket    TEXT,
    status    TEXT NOT NULL DEFAULT 'Open'
              CHECK (status IN ('Open', 'Fixed', 'Not repairable')),
    cost      REAL NOT NULL DEFAULT 0 CHECK (cost >= 0),
    closed    TEXT
);

-- A device can only be out with one student at a time,
-- and a student can only have one device out at a time.
CREATE UNIQUE INDEX IF NOT EXISTS one_open_checkout_per_device
    ON checkouts(device_id) WHERE returned IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS one_open_checkout_per_student
    ON checkouts(student_id) WHERE returned IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS one_open_repair_per_device
    ON repairs(device_id) WHERE status = 'Open';
