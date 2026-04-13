# Officer Equipment Checkout Web App

This is a web-based app for managing officer equipment checkout/check-in by badge and QR scans.

## Features implemented

- **Badge scan/start shift**: officer enters/scans badge ID at start of shift.
- **Officer profile view after scan**: shows picture, full name, NUID, badge, shift start time, and shift ID.
- **No-equipment option**: single button to log officer as not checking out equipment.
- **QR equipment scanning**: checkout/checkin actions with timestamped entries.
- **End-of-shift scan flow**: end shift action stores shift end timestamp.
- **Audit reporting**: query logs by shift ID, day (`YYYY-MM-DD`), or month (`YYYY-MM`).
- **Officer registration**: register badge/NUID/name/photo when badge is unknown.
- **Equipment registration**: add QR-coded equipment inventory.

## Tech stack

- Python 3
- Flask
- SQLite (local file `app.db`)

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install flask
python app.py
```

Open: `http://localhost:5000`

## First-time setup

- App auto-initializes DB (`app.db`) if missing.
- You can also force re-initialize by visiting `/init-db`.

## Main routes

- `/` → badge scan (start shift)
- `/register` → register officer
- `/shift/<shift_id>` → active officer shift actions
- `/equipment` → register/list equipment
- `/audit` → audit search view

## Files

- `app.py` - Flask routes and business logic
- `schema.sql` - SQLite schema + seed data
- `templates/` - Jinja templates for UI pages
- `static/style.css` - basic styling
