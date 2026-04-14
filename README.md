# Officer Equipment Checkout Web App

This is a **web-based app** for managing officer equipment checkout/check-in by badge and QR scans, and it includes deployment support for **Vercel**.

## Features implemented

- **Badge scan/start shift**: officer enters/scans badge ID at start of shift.
- **Officer profile view after scan**: shows picture, full name, NUID, badge, shift start time, and shift ID.
- **No-equipment option**: single button to log officer as not checking out equipment.
- **QR equipment scanning**: checkout/checkin actions with timestamped entries.
- **End-of-shift flow**: end shift action stores shift end timestamp.
- **Audit reporting UI**: query logs by shift ID, day (`YYYY-MM-DD`), or month (`YYYY-MM`).
- **Officer registration UI**: register badge/NUID/name/photo when badge is unknown.
- **Equipment registration UI**: add QR-coded equipment inventory.

## Tech stack

- Python 3
- Flask
- SQLite (`app.db` locally, `/tmp/officer_checkout.db` on Vercel runtime)

## Local run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Open: `http://localhost:5000`

## Vercel deployment

This repository includes:

- `api/index.py` (Vercel serverless Python entrypoint)
- `vercel.json` (routes all paths to Flask app)

### Deploy steps

1. Push repository to GitHub.
2. In Vercel, import the GitHub repository.
3. Framework preset: **Other**.
4. Build/Output commands: leave default for Python serverless.
5. Deploy.

### Important persistence note

Vercel serverless file storage is ephemeral. This app stores the SQLite DB in `/tmp` when running on Vercel, which is good for demo/testing but not durable for production. For production persistence, point the app to a managed database.

## First-time setup

- App auto-initializes DB if missing.
- You can force re-initialize with `/init-db`.

## Main routes

- `/` → badge scan (start shift)
- `/register` → register officer
- `/shift/<shift_id>` → active officer shift actions
- `/equipment` → register/list equipment
- `/audit` → audit search view

## Files

- `app.py` - Flask routes and business logic
- `schema.sql` - SQLite schema + seed data
- `api/index.py` - Vercel Python entrypoint
- `vercel.json` - Vercel routing/build config
- `templates/` - Jinja templates for UI pages
- `static/style.css` - styling
