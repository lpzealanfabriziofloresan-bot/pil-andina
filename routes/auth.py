from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_user, logout_user, login_required
from db import get_db
from models import User
import bcrypt

auth_bp = Blueprint("auth", __name__)

@auth_bp.route("/", methods=["GET","POST"])
@auth_bp.route("/login", methods=["GET","POST"])
def login():
    if request.method == "POST":
        email = request.form["email"]
        pwd   = request.form["password"].encode()
        db    = get_db()
        cur   = db.cursor(dictionary=True)
        cur.execute("SELECT * FROM usuarios WHERE email=%s AND activo=1", (email,))
        row   = cur.fetchone()
        db.close()
        if row and bcrypt.checkpw(pwd, row["password_hash"].encode()):
            login_user(User(row))
            return redirect(url_for("main.dashboard"))
        flash("Credenciales incorrectas", "danger")
    return render_template("login.html")

@auth_bp.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("auth.login"))