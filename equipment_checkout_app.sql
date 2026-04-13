-- Equipment Checkout App database
-- MySQL 8+

DROP SCHEMA IF EXISTS equipment_checkout_app;
CREATE SCHEMA equipment_checkout_app;
USE equipment_checkout_app;

CREATE TABLE officers (
    officer_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    badge_id VARCHAR(64) NOT NULL UNIQUE,
    nuid VARCHAR(32) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    photo_url VARCHAR(500),
    active_flag TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE equipment (
    equipment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    qr_code VARCHAR(128) NOT NULL UNIQUE,
    equipment_type ENUM('radio', 'phone', 'key', 'bodycam', 'other') NOT NULL,
    label VARCHAR(120) NOT NULL,
    serial_number VARCHAR(120),
    active_flag TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE shifts (
    shift_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    officer_id BIGINT NOT NULL,
    shift_date DATE NOT NULL,
    shift_start DATETIME NOT NULL,
    shift_end DATETIME NULL,
    no_equipment_flag TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_shifts_officer FOREIGN KEY (officer_id) REFERENCES officers(officer_id),
    INDEX idx_shifts_officer_start (officer_id, shift_start),
    INDEX idx_shifts_date (shift_date)
);

CREATE TABLE equipment_transactions (
    txn_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    shift_id BIGINT NOT NULL,
    officer_id BIGINT NOT NULL,
    equipment_id BIGINT NOT NULL,
    action ENUM('checkout', 'checkin') NOT NULL,
    action_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes VARCHAR(255),
    CONSTRAINT fk_txn_shift FOREIGN KEY (shift_id) REFERENCES shifts(shift_id),
    CONSTRAINT fk_txn_officer FOREIGN KEY (officer_id) REFERENCES officers(officer_id),
    CONSTRAINT fk_txn_equipment FOREIGN KEY (equipment_id) REFERENCES equipment(equipment_id),
    INDEX idx_txn_time (action_time),
    INDEX idx_txn_shift (shift_id),
    INDEX idx_txn_equipment (equipment_id)
);

-- Optional: one scan event table to maintain complete audit of badge scans
CREATE TABLE badge_scan_events (
    scan_event_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    officer_id BIGINT NOT NULL,
    scan_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    scan_type ENUM('shift_start', 'shift_end', 'view_only') NOT NULL,
    shift_id BIGINT,
    CONSTRAINT fk_scan_officer FOREIGN KEY (officer_id) REFERENCES officers(officer_id),
    CONSTRAINT fk_scan_shift FOREIGN KEY (shift_id) REFERENCES shifts(shift_id),
    INDEX idx_scan_time (scan_time)
);

DELIMITER $$

CREATE PROCEDURE start_shift_by_badge(IN p_badge_id VARCHAR(64))
BEGIN
    DECLARE v_officer_id BIGINT;

    SELECT officer_id INTO v_officer_id
    FROM officers
    WHERE badge_id = p_badge_id
      AND active_flag = 1;

    IF v_officer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Officer not found for this badge scan';
    END IF;

    INSERT INTO shifts (officer_id, shift_date, shift_start)
    VALUES (v_officer_id, CURRENT_DATE(), NOW());

    INSERT INTO badge_scan_events (officer_id, scan_type, shift_id)
    VALUES (v_officer_id, 'shift_start', LAST_INSERT_ID());

    SELECT o.officer_id,
           o.badge_id,
           o.nuid,
           CONCAT(o.first_name, ' ', o.last_name) AS full_name,
           o.photo_url,
           s.shift_id,
           s.shift_start
    FROM officers o
    JOIN shifts s ON s.officer_id = o.officer_id
    WHERE s.shift_id = LAST_INSERT_ID();
END $$

CREATE PROCEDURE mark_no_equipment(IN p_shift_id BIGINT)
BEGIN
    UPDATE shifts
    SET no_equipment_flag = 1
    WHERE shift_id = p_shift_id;
END $$

CREATE PROCEDURE scan_equipment(
    IN p_shift_id BIGINT,
    IN p_qr_code VARCHAR(128),
    IN p_action ENUM('checkout', 'checkin'),
    IN p_notes VARCHAR(255)
)
BEGIN
    DECLARE v_officer_id BIGINT;
    DECLARE v_equipment_id BIGINT;

    SELECT officer_id INTO v_officer_id
    FROM shifts
    WHERE shift_id = p_shift_id;

    IF v_officer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid shift id';
    END IF;

    SELECT equipment_id INTO v_equipment_id
    FROM equipment
    WHERE qr_code = p_qr_code
      AND active_flag = 1;

    IF v_equipment_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipment not found for this QR scan';
    END IF;

    INSERT INTO equipment_transactions (
        shift_id,
        officer_id,
        equipment_id,
        action,
        action_time,
        notes
    ) VALUES (
        p_shift_id,
        v_officer_id,
        v_equipment_id,
        p_action,
        NOW(),
        p_notes
    );
END $$

CREATE PROCEDURE end_shift(IN p_shift_id BIGINT)
BEGIN
    DECLARE v_officer_id BIGINT;

    SELECT officer_id INTO v_officer_id
    FROM shifts
    WHERE shift_id = p_shift_id;

    IF v_officer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid shift id';
    END IF;

    UPDATE shifts
    SET shift_end = NOW()
    WHERE shift_id = p_shift_id;

    INSERT INTO badge_scan_events (officer_id, scan_type, shift_id)
    VALUES (v_officer_id, 'shift_end', p_shift_id);
END $$

DELIMITER ;

-- Reporting views for audits (per shift, day, month)
CREATE VIEW v_shift_audit AS
SELECT s.shift_id,
       s.shift_date,
       s.shift_start,
       s.shift_end,
       s.no_equipment_flag,
       o.badge_id,
       o.nuid,
       CONCAT(o.first_name, ' ', o.last_name) AS officer_name,
       e.qr_code,
       e.label AS equipment_label,
       e.equipment_type,
       t.action,
       t.action_time,
       t.notes
FROM shifts s
JOIN officers o ON o.officer_id = s.officer_id
LEFT JOIN equipment_transactions t ON t.shift_id = s.shift_id
LEFT JOIN equipment e ON e.equipment_id = t.equipment_id;

CREATE VIEW v_daily_audit AS
SELECT DATE(t.action_time) AS audit_day,
       o.badge_id,
       o.nuid,
       CONCAT(o.first_name, ' ', o.last_name) AS officer_name,
       e.qr_code,
       e.label AS equipment_label,
       e.equipment_type,
       t.action,
       t.action_time
FROM equipment_transactions t
JOIN officers o ON o.officer_id = t.officer_id
JOIN equipment e ON e.equipment_id = t.equipment_id;

CREATE VIEW v_monthly_summary AS
SELECT DATE_FORMAT(t.action_time, '%Y-%m') AS audit_month,
       t.action,
       COUNT(*) AS total_actions,
       COUNT(DISTINCT t.officer_id) AS officers_involved,
       COUNT(DISTINCT t.equipment_id) AS equipment_involved
FROM equipment_transactions t
GROUP BY DATE_FORMAT(t.action_time, '%Y-%m'), t.action;

-- Seed data for quick local testing
INSERT INTO officers (badge_id, nuid, first_name, last_name, photo_url)
VALUES
    ('BADGE-1001', 'N00123456', 'Alicia', 'Santos', 'https://example.local/photos/alicia_santos.jpg'),
    ('BADGE-1002', 'N00123457', 'Marcus', 'Lee', 'https://example.local/photos/marcus_lee.jpg');

INSERT INTO equipment (qr_code, equipment_type, label, serial_number)
VALUES
    ('QR-RADIO-001', 'radio', 'Patrol Radio 1', 'RAD-001'),
    ('QR-PHONE-007', 'phone', 'Shift Phone 7', 'PHN-007'),
    ('QR-KEY-012', 'key', 'Key Ring 12', 'KEY-012');

-- Example flow:
-- CALL start_shift_by_badge('BADGE-1001');
-- CALL mark_no_equipment(1);
-- CALL scan_equipment(1, 'QR-RADIO-001', 'checkout', 'Start of shift checkout');
-- CALL scan_equipment(1, 'QR-RADIO-001', 'checkin', 'End of shift checkin');
-- CALL end_shift(1);
