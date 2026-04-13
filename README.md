# Officer Equipment Checkout App (Database Foundation)

This repository now includes a production-ready MySQL schema for an officer equipment checkout/check-in workflow.

## What this supports

- Badge scan to identify officer.
- Officer profile return after scan (picture URL, full name, NUID, scan/shift start time).
- Option to mark officer as **no equipment needed** and move to the next person.
- QR scan equipment checkout/check-in with exact timestamped transactions.
- Shift-level and audit-friendly reporting per shift/day/month.

## Main file

- `equipment_checkout_app.sql`

## Core data model

- `officers`: Officer identity and profile data.
- `equipment`: Trackable equipment inventory and QR IDs.
- `shifts`: One shift row per scan-in/start; supports no-equipment logging.
- `equipment_transactions`: Audit trail of checkout/check-in actions.
- `badge_scan_events`: Extra table for explicit badge scan event history.

## Stored procedures

- `start_shift_by_badge(badge_id)`: validates badge, starts shift, logs scan, returns officer + shift payload for UI.
- `mark_no_equipment(shift_id)`: logs a shift that requires no gear.
- `scan_equipment(shift_id, qr_code, action, notes)`: logs checkout/check-in from QR scans.
- `end_shift(shift_id)`: closes shift and logs ending badge scan.

## Audit views

- `v_shift_audit`: Full detail by shift (who, what, when).
- `v_daily_audit`: Day-level transactional trail.
- `v_monthly_summary`: Monthly action totals and unique officer/equipment counts.

## Quick start

```sql
SOURCE equipment_checkout_app.sql;

CALL start_shift_by_badge('BADGE-1001');
CALL scan_equipment(1, 'QR-RADIO-001', 'checkout', 'Start of shift checkout');
CALL scan_equipment(1, 'QR-RADIO-001', 'checkin', 'End of shift checkin');
CALL end_shift(1);

SELECT * FROM v_shift_audit WHERE shift_id = 1;
SELECT * FROM v_daily_audit WHERE audit_day = CURRENT_DATE();
SELECT * FROM v_monthly_summary;
```

## Suggested next step

Build a web/mobile UI against these procedures:

1. **Badge scan screen** → calls `start_shift_by_badge` and renders officer card.
2. **No Equipment button** → calls `mark_no_equipment`.
3. **QR scan page** with checkout/check-in toggle → calls `scan_equipment`.
4. **End shift** action → calls `end_shift`.
