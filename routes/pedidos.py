from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response
from flask_login import login_required, current_user
from db import get_db
from utils import registrar_auditoria
import pandas as pd, io

pedidos_bp = Blueprint("pedidos", __name__, url_prefix="/pedidos")

@pedidos_bp.route("/")
@login_required
def lista():
    db = get_db()
    cur = db.cursor(dictionary=True)
    if current_user.rol == "Distribuidor":
        cur.execute("""SELECT p.*,d.razon_social FROM pedidos p
            JOIN distribuidores d ON p.id_distribuidor=d.id_distribuidor
            WHERE p.id_distribuidor=%s ORDER BY p.fecha_pedido DESC""",
            (current_user.id_distribuidor,))
    else:
        cur.execute("""SELECT p.*,d.razon_social FROM pedidos p
            JOIN distribuidores d ON p.id_distribuidor=d.id_distribuidor
            ORDER BY p.fecha_pedido DESC""")
    pedidos = cur.fetchall()
    db.close()
    return render_template("pedidos/lista.html", pedidos=pedidos)

@pedidos_bp.route("/nuevo", methods=["GET", "POST"])
@login_required
def nuevo():
    db = get_db()
    cur = db.cursor(dictionary=True)
    if request.method == "POST":
        f = request.form
        id_dist = current_user.id_distribuidor if current_user.rol == "Distribuidor" else f["id_distribuidor"]
        cur2 = db.cursor()
        cur2.execute("""INSERT INTO pedidos(id_distribuidor,fecha_entrega_req,notas)
            VALUES(%s,%s,%s)""", (id_dist, f["fecha_entrega_req"], f.get("notas", "")))
        id_pedido = cur2.lastrowid
        lotes = request.form.getlist("id_lote[]")
        cantidades = request.form.getlist("cantidad[]")
        precios = request.form.getlist("precio[]")
        monto = 0
        for l, c, p in zip(lotes, cantidades, precios):
            cur2.execute("""INSERT INTO detalle_pedidos(id_pedido,id_lote,cantidad,precio_unitario)
                VALUES(%s,%s,%s,%s)""", (id_pedido, l, c, p))
            monto += int(c) * float(p)
        cur2.execute("UPDATE pedidos SET monto_total=%s WHERE id_pedido=%s", (monto, id_pedido))
        db.commit()
        db.close()
        registrar_auditoria(current_user.id, "INSERT", "pedidos", id_pedido, f"Pedido #{id_pedido} creado")
        flash("Pedido creado", "success")
        return redirect(url_for("pedidos.lista"))
    cur.execute("SELECT * FROM distribuidores WHERE activo=1")
    distribuidores = cur.fetchall()
    cur.execute("""SELECT l.*,p.marca,p.presentacion FROM lotes l
        JOIN productos p ON l.id_producto=p.id_producto
        WHERE l.estado='Aprobado' AND l.cantidad_disponible>0""")
    lotes = cur.fetchall()
    db.close()
    return render_template("pedidos/form.html", distribuidores=distribuidores, lotes=lotes, pedido=None)

@pedidos_bp.route("/editar/<int:id>", methods=["GET", "POST"])
@login_required
def editar(id):
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM pedidos WHERE id_pedido=%s", (id,))
    pedido = cur.fetchone()
    if not pedido or pedido["estado"] != "Pendiente":
        flash("Solo se pueden editar pedidos pendientes", "danger")
        return redirect(url_for("pedidos.lista"))
    if current_user.rol == "Distribuidor" and pedido["id_distribuidor"] != current_user.id_distribuidor:
        flash("Sin permisos", "danger")
        return redirect(url_for("pedidos.lista"))
    if request.method == "POST":
        f = request.form
        cur2 = db.cursor()
        cur2.execute("UPDATE pedidos SET fecha_entrega_req=%s, notas=%s WHERE id_pedido=%s",
                     (f["fecha_entrega_req"], f.get("notas", ""), id))
        db.commit()
        db.close()
        registrar_auditoria(current_user.id, "UPDATE", "pedidos", id, "Pedido editado")
        flash("Pedido actualizado", "success")
        return redirect(url_for("pedidos.lista"))
    db.close()
    return render_template("pedidos/form_edit.html", pedido=pedido)

@pedidos_bp.route("/despachar/<int:id>")
@login_required
def despachar(id):
    if not current_user.is_gerente():
        flash("Sin permisos", "danger")
        return redirect(url_for("pedidos.lista"))
    db = get_db()
    cur = db.cursor()
    cur.callproc("sp_despachar_pedido", [id, current_user.id, ""])
    db.commit()
    db.close()
    flash("Pedido despachado", "success")
    return redirect(url_for("pedidos.lista"))

@pedidos_bp.route("/cancelar/<int:id>")
@login_required
def cancelar(id):
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM pedidos WHERE id_pedido=%s", (id,))
    pedido = cur.fetchone()
    if not pedido or pedido["estado"] != "Pendiente":
        flash("No se puede cancelar este pedido", "danger")
        return redirect(url_for("pedidos.lista"))
    if current_user.rol == "Distribuidor" and pedido["id_distribuidor"] != current_user.id_distribuidor:
        flash("Sin permisos", "danger")
        return redirect(url_for("pedidos.lista"))
    cur2 = db.cursor()
    cur2.execute("UPDATE pedidos SET estado='Cancelado' WHERE id_pedido=%s", (id,))
    db.commit()
    db.close()
    registrar_auditoria(current_user.id, "UPDATE", "pedidos", id, "Pedido cancelado")
    flash("Pedido cancelado", "warning")
    return redirect(url_for("pedidos.lista"))

@pedidos_bp.route("/exportar")
@login_required
def exportar():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("""SELECT p.id_pedido,d.razon_social,p.fecha_pedido,
        p.fecha_entrega_req,p.estado,p.monto_total
        FROM pedidos p JOIN distribuidores d ON p.id_distribuidor=d.id_distribuidor""")
    rows = cur.fetchall()
    db.close()
    df = pd.DataFrame(rows)
    out = io.BytesIO()
    df.to_excel(out, index=False)
    out.seek(0)
    resp = make_response(out.read())
    resp.headers["Content-Disposition"] = "attachment; filename=pedidos.xlsx"
    resp.headers["Content-Type"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    return resp
