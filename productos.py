from flask import Blueprint, render_template
from flask_login import login_required, current_user
from app import get_db

main_bp = Blueprint("main", __name__)

@main_bp.route("/dashboard")
@login_required
def dashboard():
    db  = get_db()
    cur = db.cursor(dictionary=True)

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
    )