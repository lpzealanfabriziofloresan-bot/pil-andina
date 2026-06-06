from flask import Blueprint, render_template, request, redirect, url_for, flash, current_app, send_from_directory
from flask_login import login_required, current_user
from db import get_db
from utils import registrar_auditoria
import os, datetime, subprocess

admin_bp = Blueprint("admin", __name__, url_prefix="/admin")

def solo_admin(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_user.is_admin():
            flash("Solo administradores", "danger")
            return redirect(url_for("main.dashboard"))
        return f(*args, **kwargs)
    return decorated

@admin_bp.route("/usuarios")
@login_required
@solo_admin
def usuarios():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT u.*,d.razon_social FROM usuarios u LEFT JOIN distribuidores d ON u.id_distribuidor=d.id_distribuidor")
    usuarios = cur.fetchall()
    cur.execute("SELECT id_distribuidor, razon_social FROM distribuidores WHERE activo=1")
    distribuidores = cur.fetchall()
    db.close()
    return render_template("admin/usuarios.html", usuarios=usuarios, distribuidores=distribuidores)

@admin_bp.route("/usuarios/nuevo", methods=["GET", "POST"])
@login_required
@solo_admin
def usuario_nuevo():
    db = get_db()
    cur = db.cursor(dictionary=True)
    if request.method == "POST":
        f = request.form
        id_dist = f.get("id_distribuidor") or None
        if id_dist:
            id_dist = int(id_dist)
        cur2 = db.cursor()
        cur2.execute("""INSERT INTO usuarios (nombre, apellido, email, rol, id_distribuidor, password_hash)
            VALUES (%s,%s,%s,%s,%s,'CHANGEME')""",
            (f["nombre"], f["apellido"], f["email"], f["rol"], id_dist))
        id_nuevo = cur2.lastrowid
        db.commit()
        db.close()
        registrar_auditoria(current_user.id, "INSERT", "usuarios", id_nuevo, f["email"])
        flash("Usuario creado. Contraseña por defecto: Dist123!", "success")
        return redirect(url_for("admin.usuarios"))
    cur.execute("SELECT id_distribuidor, razon_social FROM distribuidores WHERE activo=1")
    distribuidores = cur.fetchall()
    db.close()
    return render_template("admin/usuario_form.html", usuario=None, distribuidores=distribuidores)

@admin_bp.route("/usuarios/editar/<int:id>", methods=["GET", "POST"])
@login_required
@solo_admin
def usuario_editar(id):
    db = get_db()
    cur = db.cursor(dictionary=True)
    if request.method == "POST":
        f = request.form
        id_dist = f.get("id_distribuidor") or None
        if id_dist:
            id_dist = int(id_dist)
        cur.execute("""UPDATE usuarios SET nombre=%s, apellido=%s, email=%s, rol=%s,
            id_distribuidor=%s, activo=%s WHERE id_usuario=%s""",
            (f["nombre"], f["apellido"], f["email"], f["rol"], id_dist,
             1 if f.get("activo") else 0, id))
        db.commit()
        db.close()
        registrar_auditoria(current_user.id, "UPDATE", "usuarios", id, f["email"])
        flash("Usuario actualizado", "success")
        return redirect(url_for("admin.usuarios"))
    cur.execute("SELECT * FROM usuarios WHERE id_usuario=%s", (id,))
    usuario = cur.fetchone()
    cur.execute("SELECT id_distribuidor, razon_social FROM distribuidores WHERE activo=1")
    distribuidores = cur.fetchall()
    db.close()
    return render_template("admin/usuario_form.html", usuario=usuario, distribuidores=distribuidores)

@admin_bp.route("/monitoreo")
@login_required
@solo_admin
def monitoreo():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SHOW FULL PROCESSLIST")
    procesos = cur.fetchall()
    cur.execute("SELECT * FROM auditoria ORDER BY fecha DESC LIMIT 50")
    logs = cur.fetchall()
    cur.execute("SHOW STATUS LIKE 'Threads_connected'")
    conexiones = cur.fetchone()
    db.close()
    return render_template("admin/monitoreo.html", procesos=procesos, logs=logs, conexiones=conexiones)

@admin_bp.route("/backup", methods=["GET", "POST"])
@login_required
@solo_admin
def backup():
    if request.method == "POST":
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        os.makedirs("backups", exist_ok=True)
        path = os.path.join("backups", f"pil_andina_{ts}.sql")
        with open(path, "w", encoding="utf-8") as out:
            subprocess.run(
                ["mysqldump", "-u", current_app.config["DB_USER"],
                 f"-p{current_app.config['DB_PASSWORD']}", current_app.config["DB_NAME"]],
                stdout=out, check=False,
            )
        registrar_auditoria(current_user.id, "BACKUP", "pil_andina", None, f"Backup: {path}")
        flash(f"Backup generado: {path}", "success")
    backups = sorted(os.listdir("backups"), reverse=True) if os.path.exists("backups") else []
    return render_template("admin/backup.html", backups=backups)

@admin_bp.route("/backup/descargar/<filename>")
@login_required
@solo_admin
def backup_descargar(filename):
    if ".." in filename or "/" in filename or "\\" in filename:
        flash("Archivo no válido", "danger")
        return redirect(url_for("admin.backup"))
    return send_from_directory("backups", filename, as_attachment=True)
