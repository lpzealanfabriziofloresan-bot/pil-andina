from flask import Blueprint, render_template, request, redirect, url_for, flash
from flask_login import login_required, current_user
from db import get_db
from utils import registrar_auditoria

distribuidores_bp = Blueprint("distribuidores", __name__, url_prefix="/distribuidores")

@distribuidores_bp.route("/")
@login_required
def lista():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM distribuidores ORDER BY razon_social")
    distribuidores = cur.fetchall()
    db.close()
    return render_template("distribuidores/lista.html", distribuidores=distribuidores)

@distribuidores_bp.route("/nuevo", methods=["GET", "POST"])
@login_required
def nuevo():
    if not current_user.is_gerente():
        flash("Sin permisos", "danger")
        return redirect(url_for("distribuidores.lista"))
    if request.method == "POST":
        f = request.form
        db = get_db()
        cur = db.cursor()
        cur.execute(
            "INSERT INTO distribuidores (razon_social, ciudad, nit, telefono) VALUES (%s,%s,%s,%s)",
            (f["razon_social"], f["ciudad"], f.get("nit", ""), f.get("telefono", "")),
        )
        id_nuevo = cur.lastrowid
        db.commit()
        db.close()
        registrar_auditoria(current_user.id, "INSERT", "distribuidores", id_nuevo, f["razon_social"])
        flash("Distribuidor creado", "success")
        return redirect(url_for("distribuidores.lista"))
    return render_template("distribuidores/form.html", distribuidor=None)

@distribuidores_bp.route("/editar/<int:id>", methods=["GET", "POST"])
@login_required
def editar(id):
    if not current_user.is_gerente():
        flash("Sin permisos", "danger")
        return redirect(url_for("distribuidores.lista"))
    db = get_db()
    cur = db.cursor(dictionary=True)
    if request.method == "POST":
        f = request.form
        cur.execute(
            "UPDATE distribuidores SET razon_social=%s, ciudad=%s, nit=%s, telefono=%s WHERE id_distribuidor=%s",
            (f["razon_social"], f["ciudad"], f.get("nit", ""), f.get("telefono", ""), id),
        )
        db.commit()
        db.close()
        registrar_auditoria(current_user.id, "UPDATE", "distribuidores", id, f["razon_social"])
        flash("Distribuidor actualizado", "success")
        return redirect(url_for("distribuidores.lista"))
    cur.execute("SELECT * FROM distribuidores WHERE id_distribuidor=%s", (id,))
    distribuidor = cur.fetchone()
    db.close()
    return render_template("distribuidores/form.html", distribuidor=distribuidor)

@distribuidores_bp.route("/eliminar/<int:id>")
@login_required
def eliminar(id):
    if not current_user.is_admin():
        flash("Sin permisos", "danger")
        return redirect(url_for("distribuidores.lista"))
    db = get_db()
    cur = db.cursor()
    cur.execute("UPDATE distribuidores SET activo=0 WHERE id_distribuidor=%s", (id,))
    db.commit()
    db.close()
    registrar_auditoria(current_user.id, "DELETE", "distribuidores", id, "Distribuidor desactivado")
    flash("Distribuidor desactivado", "warning")
    return redirect(url_for("distribuidores.lista"))
