from __future__ import annotations

import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional

from flask import Flask, flash, g, redirect, render_template, request, url_for

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "app.db"
SCHEMA_PATH = BASE_DIR / "schema.sql"

app = Flask(__name__)
app.secret_key = "dev-secret-change-me"


def get_db() -> sqlite3.Connection:
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_error: Optional[Exception]) -> None:
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db() -> None:
    db = sqlite3.connect(DB_PATH)
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        db.executescript(f.read())
    db.commit()
    db.close()


@app.route("/init-db")
def init_db_route():
    init_db()
    flash("Database initialized.", "success")
    return redirect(url_for("home"))


@app.route("/", methods=["GET", "POST"])
def home():
    if request.method == "POST":
        badge_id = request.form.get("badge_id", "").strip()
        if not badge_id:
            flash("Please scan or enter a badge ID.", "error")
            return redirect(url_for("home"))

        db = get_db()
        officer = db.execute(
            "SELECT * FROM officers WHERE badge_id = ?", (badge_id,)
        ).fetchone()

        if officer is None:
            flash("Badge not found. Please register officer.", "error")
            return redirect(url_for("register_officer", badge_id=badge_id))

        now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        db.execute(
            "INSERT INTO shifts (officer_id, shift_start) VALUES (?, ?)",
            (officer["id"], now),
        )
        shift_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
        db.commit()

        return redirect(url_for("shift_view", shift_id=shift_id))

    return render_template("index.html")


@app.route("/register", methods=["GET", "POST"])
def register_officer():
    preset_badge = request.args.get("badge_id", "")
    if request.method == "POST":
        badge_id = request.form.get("badge_id", "").strip()
        first_name = request.form.get("first_name", "").strip()
        last_name = request.form.get("last_name", "").strip()
        nuid = request.form.get("nuid", "").strip()
        photo_url = request.form.get("photo_url", "").strip()

        if not all([badge_id, first_name, last_name, nuid]):
            flash("Badge, first name, last name, and NUID are required.", "error")
            return redirect(url_for("register_officer", badge_id=badge_id))

        db = get_db()
        try:
            db.execute(
                """
                INSERT INTO officers (badge_id, first_name, last_name, nuid, photo_url)
                VALUES (?, ?, ?, ?, ?)
                """,
                (badge_id, first_name, last_name, nuid, photo_url or None),
            )
            db.commit()
        except sqlite3.IntegrityError:
            flash("Badge ID or NUID already exists.", "error")
            return redirect(url_for("register_officer", badge_id=badge_id))

        flash("Officer registered. Scan badge to start shift.", "success")
        return redirect(url_for("home"))

    return render_template("register.html", preset_badge=preset_badge)


@app.route("/shift/<int:shift_id>", methods=["GET", "POST"])
def shift_view(shift_id: int):
    db = get_db()

    if request.method == "POST":
        action = request.form.get("form_action")
        if action == "no_equipment":
            db.execute("UPDATE shifts SET no_equipment = 1 WHERE id = ?", (shift_id,))
            db.commit()
            flash("Marked as no equipment needed.", "success")

        elif action in {"checkout", "checkin"}:
            qr_code = request.form.get("qr_code", "").strip()
            if not qr_code:
                flash("Scan or enter equipment QR code.", "error")
                return redirect(url_for("shift_view", shift_id=shift_id))

            equip = db.execute(
                "SELECT * FROM equipment WHERE qr_code = ?", (qr_code,)
            ).fetchone()
            if equip is None:
                flash("Unknown equipment QR code.", "error")
                return redirect(url_for("shift_view", shift_id=shift_id))

            shift = db.execute("SELECT * FROM shifts WHERE id = ?", (shift_id,)).fetchone()
            now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            db.execute(
                """
                INSERT INTO transactions (shift_id, officer_id, equipment_id, action, action_time)
                VALUES (?, ?, ?, ?, ?)
                """,
                (shift_id, shift["officer_id"], equip["id"], action, now),
            )
            db.commit()
            flash(f"Equipment {action} logged.", "success")

        elif action == "end_shift":
            now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            db.execute("UPDATE shifts SET shift_end = ? WHERE id = ?", (now, shift_id))
            db.commit()
            flash("Shift ended.", "success")
            return redirect(url_for("home"))

    shift = db.execute(
        """
        SELECT s.*, o.badge_id, o.first_name, o.last_name, o.nuid, o.photo_url
        FROM shifts s
        JOIN officers o ON o.id = s.officer_id
        WHERE s.id = ?
        """,
        (shift_id,),
    ).fetchone()

    transactions = db.execute(
        """
        SELECT t.*, e.qr_code, e.label, e.equipment_type
        FROM transactions t
        JOIN equipment e ON e.id = t.equipment_id
        WHERE t.shift_id = ?
        ORDER BY t.action_time DESC
        """,
        (shift_id,),
    ).fetchall()

    return render_template("officer.html", shift=shift, transactions=transactions)


@app.route("/equipment", methods=["GET", "POST"])
def equipment_register():
    db = get_db()
    if request.method == "POST":
        qr_code = request.form.get("qr_code", "").strip()
        label = request.form.get("label", "").strip()
        equipment_type = request.form.get("equipment_type", "other").strip()

        if not qr_code or not label:
            flash("QR code and label are required.", "error")
            return redirect(url_for("equipment_register"))

        try:
            db.execute(
                "INSERT INTO equipment (qr_code, label, equipment_type) VALUES (?, ?, ?)",
                (qr_code, label, equipment_type),
            )
            db.commit()
            flash("Equipment added.", "success")
        except sqlite3.IntegrityError:
            flash("QR code already exists.", "error")

    equipment = db.execute("SELECT * FROM equipment ORDER BY id DESC").fetchall()
    return render_template("equipment.html", equipment=equipment)


@app.route("/audit")
def audit():
    period = request.args.get("period", "day")
    value = request.args.get("value", "")
    db = get_db()

    query = """
        SELECT t.action_time, t.action, o.badge_id,
               o.first_name || ' ' || o.last_name AS full_name,
               o.nuid, e.qr_code, e.label, e.equipment_type, t.shift_id
        FROM transactions t
        JOIN officers o ON o.id = t.officer_id
        JOIN equipment e ON e.id = t.equipment_id
    """
    params = []

    if period == "shift" and value:
        query += " WHERE t.shift_id = ?"
        params.append(value)
    elif period == "day" and value:
        query += " WHERE date(t.action_time) = ?"
        params.append(value)
    elif period == "month" and value:
        query += " WHERE strftime('%Y-%m', t.action_time) = ?"
        params.append(value)

    query += " ORDER BY t.action_time DESC"
    rows = db.execute(query, params).fetchall()

    return render_template("audit.html", rows=rows, period=period, value=value)


if __name__ == "__main__":
    if not DB_PATH.exists():
        init_db()
    app.run(debug=True, host="0.0.0.0", port=5000)
