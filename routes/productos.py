from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response
from flask_login import login_required, current_user
from db import get_db
from utils import registrar_auditoria
import pandas as pd, io

productos_bp = Blueprint("productos", __name__, url_prefix="/productos")

@productos_bp.route("/")
@login_required
def lista():
    db  = get_db()
    cur = db.cursor(dictionary=True)
    marca = request.args.get("marca","")
    tipo  = request.args.get("tipo","")
    sql   = "SELECT * FROM productos WHERE activo=1"
    params= []
    if marca: sql += " AND marca LIKE %s"; params.append(f"%{marca}%")
    if tipo:  sql += " AND tipo=%s";       params.append(tipo)
    cur.execute(sql, params)
    productos = cur.fetchall()
    db.close()
    return render_template("productos/lista.html", productos=productos, marca=marca, tipo=tipo)

@productos_bp.route("/nuevo", methods=["GET","POST"])
@login_required
def nuevo():
    if not current_user.is_gerente():
        flash("Sin permisos", "danger"); return redirect(url_for("productos.lista"))
    if request.method == "POST":
        f  = request.form
        db = get_db()
        cur= db.cursor()
        cur.execute("""INSERT INTO productos
            (codigo,marca,tipo,presentacion,graduacion_alc,precio_unitario,stock_minimo)
            VALUES (%s,%s,%s,%s,%s,%s,%s)""",
            (f["codigo"],f["marca"],f["tipo"],f["presentacion"],
             f["graduacion_alc"],f["precio_unitario"],f["stock_minimo"]))
        id_nuevo = cur.lastrowid
        db.commit(); db.close()
        registrar_auditoria(current_user.id, "INSERT", "productos", id_nuevo, f["codigo"])
        flash("Producto creado", "success")
        return redirect(url_for("productos.lista"))
    return render_template("productos/form.html", producto=None)

@productos_bp.route("/editar/<int:id>", methods=["GET","POST"])
@login_required
def editar(id):
    if not current_user.is_gerente():
        flash("Sin permisos","danger"); return redirect(url_for("productos.lista"))
    db  = get_db()
    cur = db.cursor(dictionary=True)
    if request.method == "POST":
        f = request.form
        cur.execute("""UPDATE productos SET marca=%s,tipo=%s,presentacion=%s,
            graduacion_alc=%s,precio_unitario=%s,stock_minimo=%s WHERE id_producto=%s""",
            (f["marca"],f["tipo"],f["presentacion"],
             f["graduacion_alc"],f["precio_unitario"],f["stock_minimo"],id))
        db.commit(); db.close()
        registrar_auditoria(current_user.id, "UPDATE", "productos", id, f["marca"])
        flash("Producto actualizado","success")
        return redirect(url_for("productos.lista"))
    cur.execute("SELECT * FROM productos WHERE id_producto=%s",(id,))
    producto = cur.fetchone(); db.close()
    return render_template("productos/form.html", producto=producto)

@productos_bp.route("/eliminar/<int:id>")
@login_required
def eliminar(id):
    if not current_user.is_admin():
        flash("Sin permisos","danger"); return redirect(url_for("productos.lista"))
    db=get_db(); cur=db.cursor()
    cur.execute("UPDATE productos SET activo=0 WHERE id_producto=%s",(id,))
    db.commit(); db.close()
    registrar_auditoria(current_user.id, "DELETE", "productos", id, "Producto desactivado")
    flash("Producto desactivado","warning")
    return redirect(url_for("productos.lista"))

@productos_bp.route("/exportar")
@login_required
def exportar():
    db=get_db(); cur=db.cursor(dictionary=True)
    cur.execute("SELECT * FROM productos WHERE activo=1")
    rows=cur.fetchall(); db.close()
    df=pd.DataFrame(rows)
    output=io.BytesIO()
    df.to_excel(output,index=False)
    output.seek(0)
    resp=make_response(output.read())
    resp.headers["Content-Disposition"]="attachment; filename=productos.xlsx"
    resp.headers["Content-Type"]="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    return resp