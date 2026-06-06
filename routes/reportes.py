from flask import Blueprint, render_template, make_response
from flask_login import login_required, current_user
from db import get_db
import pandas as pd, io

reportes_bp = Blueprint("reportes", __name__, url_prefix="/reportes")

@reportes_bp.route("/")
@login_required
def index():
    if current_user.rol == "Distribuidor":
        return render_template("reportes/distribuidor.html")

    db = get_db()
    cur = db.cursor(dictionary=True)

    cur.execute("SELECT * FROM v_stock_por_planta ORDER BY planta, stock_total DESC")
    stock_planta = cur.fetchall()

    cur.execute("SELECT * FROM v_proximos_a_vencer ORDER BY dias_restantes ASC")
    proximos = cur.fetchall()

    cur.execute("SELECT * FROM v_rotacion_inventario ORDER BY pct_rotacion DESC")
    rotacion = cur.fetchall()

    cur.execute("""
        SELECT pl.nombre AS planta, SUM(l.cantidad_disponible) AS stock_total,
               COUNT(DISTINCT l.id_producto) AS productos_distintos
        FROM lotes l JOIN plantas pl ON l.id_planta = pl.id_planta
        WHERE l.estado = 'Aprobado' AND l.cantidad_disponible > 0
        GROUP BY pl.id_planta, pl.nombre ORDER BY stock_total DESC
    """)
    resumen_plantas = cur.fetchall()

    db.close()
    return render_template("reportes/index.html",
        stock_planta=stock_planta,
        proximos=proximos,
        rotacion=rotacion,
        resumen_plantas=resumen_plantas,
    )

@reportes_bp.route("/exportar/<tipo>")
@login_required
def exportar(tipo):
    if current_user.rol == "Distribuidor":
        return render_template("reportes/distribuidor.html")

    vistas = {
        "stock":    "SELECT * FROM v_stock_por_planta",
        "vencer":   "SELECT * FROM v_proximos_a_vencer",
        "rotacion": "SELECT * FROM v_rotacion_inventario",
    }
    if tipo not in vistas:
        return "Reporte no encontrado", 404

    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute(vistas[tipo])
    rows = cur.fetchall()
    db.close()

    df = pd.DataFrame(rows)
    output = io.BytesIO()
    df.to_excel(output, index=False)
    output.seek(0)
    resp = make_response(output.read())
    resp.headers["Content-Disposition"] = f"attachment; filename=reporte_{tipo}.xlsx"
    resp.headers["Content-Type"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    return resp
