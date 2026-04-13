DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS shifts;
DROP TABLE IF EXISTS equipment;
DROP TABLE IF EXISTS officers;

CREATE TABLE officers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    badge_id TEXT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    nuid TEXT UNIQUE NOT NULL,
    photo_url TEXT
);

CREATE TABLE equipment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    qr_code TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    equipment_type TEXT NOT NULL DEFAULT 'other'
);

CREATE TABLE shifts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    officer_id INTEGER NOT NULL,
    shift_start TEXT NOT NULL,
    shift_end TEXT,
    no_equipment INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (officer_id) REFERENCES officers(id)
);

CREATE TABLE transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shift_id INTEGER NOT NULL,
    officer_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('checkout', 'checkin')),
    action_time TEXT NOT NULL,
    FOREIGN KEY (shift_id) REFERENCES shifts(id),
    FOREIGN KEY (officer_id) REFERENCES officers(id),
    FOREIGN KEY (equipment_id) REFERENCES equipment(id)
);

INSERT INTO officers (badge_id, first_name, last_name, nuid, photo_url)
VALUES
    ('BADGE-1001', 'Alicia', 'Santos', 'N00123456', 'https://placehold.co/120x120?text=AS'),
    ('BADGE-1002', 'Marcus', 'Lee', 'N00123457', 'https://placehold.co/120x120?text=ML');

INSERT INTO equipment (qr_code, label, equipment_type)
VALUES
    ('QR-RADIO-001', 'Patrol Radio 1', 'radio'),
    ('QR-PHONE-007', 'Shift Phone 7', 'phone'),
    ('QR-KEY-012', 'Key Ring 12', 'key');
