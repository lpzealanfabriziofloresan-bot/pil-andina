from db import get_db


def registrar_auditoria(id_usuario, accion, tabla, id_registro=None, detalle=None):
    db = get_db()
    cur = db.cursor()
    cur.execute(
        "INSERT INTO auditoria (id_usuario, accion, tabla_afectada, id_registro, detalle) VALUES (%s,%s,%s,%s,%s)",
        (id_usuario, accion, tabla, id_registro, detalle),
    )
    db.commit()
    db.close()
