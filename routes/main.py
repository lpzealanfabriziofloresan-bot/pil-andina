from flask import Blueprint, render_template
from flask_login import login_required, current_user
from db import get_db

main_bp = Blueprint("main", __name__)

@main_bp.route("/dashboard")
@login_required
def dashboard():
    db = get_db()
    cur = db.cursor(dictionary=True)

    if current_user.rol == "Distribuidor":
        cur.execute("""SELECT COUNT(*) AS total FROM pedidos
            WHERE id_distribuidor=%s AND estado='Pendiente'""",
            (current_user.id_distribuidor,))
        mis_pendientes = cur.fetchone()["total"]

        cur.execute("""SELECT COUNT(*) AS total FROM pedidos
            WHERE id_distribuidor=%s""", (current_user.id_distribuidor,))
        mis_pedidos = cur.fetchone()["total"]

        cur.execute("""SELECT p.*, d.razon_social FROM pedidos p
            JOIN distribuidores d ON p.id_distribuidor=d.id_distribuidor
            WHERE p.id_distribuidor=%s ORDER BY p.fecha_pedido DESC LIMIT 8""",
            (current_user.id_distribuidor,))
        pedidos = cur.fetchall()

        cur.execute("SELECT COUNT(*) AS total FROM productos WHERE activo=1")
        total_productos = cur.fetchone()["total"]

        db.close()
        return render_template("dashboard_distribuidor.html",
            mis_pendientes=mis_pendientes,
            mis_pedidos=mis_pedidos,
            pedidos=pedidos,
            total_productos=total_productos,
        )

    cur.execute("SELECT COUNT(*) AS total FROM lotes WHERE estado='Aprobado'")
    total_lotes = cur.fetchone()["total"]

    cur.execute("SELECT COUNT(*) AS total FROM pedidos WHERE estado='Pendiente'")
    pedidos_pendientes = cur.fetchone()["total"]

    cur.execute("SELECT COUNT(*) AS total FROM v_proximos_a_vencer")
    proximos_vencer = cur.fetchone()["total"]

    cur.execute("SELECT COUNT(*) AS total FROM distribuidores WHERE activo=1")
    total_dist = cur.fetchone()["total"]

    cur.execute("SELECT * FROM v_proximos_a_vencer LIMIT 5")
    alertas = cur.fetchall()

    cur.execute("SELECT * FROM v_pedidos_pendientes LIMIT 5")
    pedidos = cur.fetchall()

    db.close()
    return render_template("dashboard.html",
        total_lotes=total_lotes,
        pedidos_pendientes=pedidos_pendientes,
        proximos_vencer=proximos_vencer,
        total_dist=total_dist,
        alertas=alertas,
        pedidos=pedidos,
        es_admin=current_user.is_admin(),
        es_gerente=current_user.is_gerente(),
    )
