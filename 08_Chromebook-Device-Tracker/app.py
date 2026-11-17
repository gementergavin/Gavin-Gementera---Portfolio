"""
Chromebook Device Tracker - Flask web app.

Run:
    pip install -r requirements.txt
    python seed.py        # optional: sample data
    python app.py         # then open http://127.0.0.1:5000
"""

import os
from datetime import date
from pathlib import Path

from flask import (Flask, Response, abort, flash, g, redirect, render_template,
                   request, url_for)

import tracker

DEFAULT_DB = Path(__file__).with_name("devices.db")


def create_app(db_path=None, today=None):
    """
    App factory. db_path and today can be set for tests; today=None means
    the real date.
    """
    app = Flask(__name__)
    app.config["SECRET_KEY"] = os.environ.get("TRACKER_SECRET_KEY") or os.urandom(24)
    app.config["DB_PATH"] = str(db_path or DEFAULT_DB)
    app.config["TODAY"] = today

    def get_db():
        if "db" not in g:
            g.db = tracker.connect(app.config["DB_PATH"])
            tracker.init_db(g.db)
        return g.db

    def today_():
        return app.config["TODAY"] or date.today()

    @app.teardown_appcontext
    def close_db(_exc):
        db = g.pop("db", None)
        if db is not None:
            db.close()

    @app.context_processor
    def inject_globals():
        return {"today": today_(), "statuses": tracker.DEVICE_STATUSES}

    # ------------------------------------------------------------- dashboard
    @app.route("/")
    def index():
        return render_template("dashboard.html", d=tracker.dashboard(get_db(), today_()))

    # --------------------------------------------------------------- devices
    @app.route("/devices")
    def devices():
        db = get_db()
        status = request.args.get("status") or None
        school = request.args.get("school") or None
        search = request.args.get("q") or None
        if status and status not in tracker.DEVICE_STATUSES:
            status = None
        return render_template("devices.html",
                               devices=tracker.list_devices(db, status, school, search),
                               schools=tracker.list_schools(db),
                               status=status, school=school, q=search or "")

    @app.route("/devices/new", methods=["POST"])
    def device_new():
        f = request.form
        try:
            tracker.add_device(get_db(), f.get("asset_tag"), f.get("serial"), f.get("model"),
                               f.get("school"), f.get("purchased") or None)
            flash(f"Added {f.get('asset_tag', '').strip().upper()}.", "ok")
        except tracker.TrackerError as err:
            flash(str(err), "error")
        return redirect(url_for("devices"))

    @app.route("/devices/<asset_tag>")
    def device_detail(asset_tag):
        db = get_db()
        try:
            device = tracker.get_device(db, asset_tag)
        except tracker.TrackerError:
            abort(404)
        checkouts, repairs = tracker.device_history(db, device["id"])
        return render_template("device_detail.html", device=device,
                               current=tracker.open_checkout_for_device(db, device["id"]),
                               checkouts=checkouts, repairs=repairs)

    # -------------------------------------------------------------- students
    @app.route("/students")
    def students():
        q = request.args.get("q") or ""
        return render_template("students.html", students=tracker.list_students(get_db(), q or None), q=q)

    @app.route("/students/new", methods=["POST"])
    def student_new():
        f = request.form
        try:
            tracker.add_student(get_db(), f.get("student_id"), f.get("first_name"),
                                f.get("last_name"), f.get("grade"), f.get("school"))
            flash(f"Added {f.get('first_name', '').strip()} {f.get('last_name', '').strip()}.", "ok")
        except tracker.TrackerError as err:
            flash(str(err), "error")
        return redirect(url_for("students"))

    # --------------------------------------------------- check out / check in
    @app.route("/checkout", methods=["GET", "POST"])
    def checkout():
        db = get_db()
        if request.method == "POST":
            f = request.form
            try:
                tracker.check_out(db, f.get("asset_tag", ""), f.get("student_id", ""),
                                  f.get("due", ""), f.get("notes") or None, today_())
                flash(f"Checked out {f['asset_tag'].strip().upper()} to student {f['student_id'].strip()}.", "ok")
                return redirect(url_for("device_detail", asset_tag=f["asset_tag"].strip().upper()))
            except tracker.TrackerError as err:
                flash(str(err), "error")
        return render_template("checkout.html",
                               available=tracker.list_devices(db, status="Available"),
                               default_due=tracker.default_due_date(today_()),
                               asset_tag=request.values.get("asset_tag", ""),
                               student_id=request.values.get("student_id", ""))

    @app.route("/checkin/<asset_tag>", methods=["POST"])
    def checkin(asset_tag):
        f = request.form
        try:
            repair_id = tracker.check_in(get_db(), asset_tag, f.get("condition") or "Good",
                                         f.get("damage") or None, f.get("ticket") or None, today_())
            if repair_id:
                flash(f"Checked in {asset_tag}. Repair #{repair_id} opened.", "ok")
            else:
                flash(f"Checked in {asset_tag}. It's available again.", "ok")
        except tracker.TrackerError as err:
            flash(str(err), "error")
        return redirect(url_for("device_detail", asset_tag=asset_tag))

    # --------------------------------------------------------------- repairs
    @app.route("/repairs")
    def repairs():
        status = request.args.get("status") or None
        return render_template("repairs.html", repairs=tracker.list_repairs(get_db(), status), status=status)

    @app.route("/repairs/new", methods=["POST"])
    def repair_new():
        f = request.form
        asset_tag = f.get("asset_tag", "").strip().upper()
        try:
            repair_id = tracker.open_repair(get_db(), asset_tag, f.get("issue"), f.get("ticket") or None, today_())
            flash(f"Repair #{repair_id} opened for {asset_tag}.", "ok")
            return redirect(url_for("device_detail", asset_tag=asset_tag))
        except tracker.TrackerError as err:
            flash(str(err), "error")
        return redirect(url_for("repairs"))

    @app.route("/repairs/<int:repair_id>/close", methods=["POST"])
    def repair_close(repair_id):
        f = request.form
        try:
            tracker.close_repair(get_db(), repair_id, fixed=(f.get("outcome") != "retire"),
                                 cost=f.get("cost") or 0, today=today_())
            flash(f"Repair #{repair_id} closed.", "ok")
        except tracker.TrackerError as err:
            flash(str(err), "error")
        return redirect(url_for("repairs"))

    # ---------------------------------------------------------------- import
    @app.route("/import", methods=["GET", "POST"])
    def import_page():
        result = None
        if request.method == "POST":
            kind = request.form.get("kind")
            upload = request.files.get("file")
            if kind not in ("devices", "students") or upload is None or upload.filename == "":
                flash("Choose what you're importing and a CSV file.", "error")
            else:
                try:
                    text = upload.read().decode("utf-8-sig")
                    result = tracker.import_csv(get_db(), text, kind)
                    result["kind"] = kind
                except UnicodeDecodeError:
                    flash("Save the file as CSV UTF-8 and try again.", "error")
                except tracker.TrackerError as err:
                    flash(str(err), "error")
        return render_template("import.html", result=result)

    # --------------------------------------------------------------- reports
    @app.route("/reports/overdue.csv")
    def overdue_report():
        csv_text = tracker.overdue_csv(get_db(), today_())
        filename = f"overdue-devices-{today_().isoformat()}.csv"
        return Response(csv_text, mimetype="text/csv",
                        headers={"Content-Disposition": f"attachment; filename={filename}"})

    @app.errorhandler(404)
    def not_found(_err):
        return render_template("404.html"), 404

    return app


if __name__ == "__main__":
    # Local use only. debug=False so error pages never show code to users.
    create_app().run(host="127.0.0.1", port=5000, debug=False)
