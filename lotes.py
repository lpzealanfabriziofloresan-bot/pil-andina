from flask import Flask
from flask_login import LoginManager
from config import Config
from routes.auth      import auth_bp
from routes.main      import main_bp
from routes.productos import productos_bp
from routes.pedidos   import pedidos_bp
from routes.lotes     import lotes_bp
from routes.admin     import admin_bp
import mysql.connector, bcrypt

app = Flask(__name__)
app.config.from_object(Config)

login_manager = LoginManager(app)
login_manager.login_view = "auth.login"

app.register_blueprint(auth_bp)
app.register_blueprint(main_bp)
app.register_blueprint(productos_bp)
app.register_blueprint(pedidos_bp)
app.register_blueprint(lotes_bp)
app.register_blueprint(admin_bp)

def get_db():
    return mysql.connector.connect(
        host     = app.config["DB_HOST"],
        user     = app.config["DB_USER"],
        password = app.config["DB_PASSWORD"],
        database = app.config["DB_NAME"],
    )

from models import User
@login_manager.user_loader
def load_user(user_id):
    db  = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM usuarios WHERE id_usuario=%s", (user_id,))
    row = cur.fetchone()
    db.close()
    return User(row) if row else None

def init_passwords():
    db  = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT id_usuario, email FROM usuarios WHERE password_hash='CHANGEME'")
    rows = cur.fetchall()
    defaults = {
        "admin@pilandina.bo":   "Admin123!",
        "gerente@pilandina.bo": "Gerente123!",
        "rtorrez@pilandina.bo": "Gerente123!",
    }
    for row in rows:
        pwd  = defaults.get(row["email"], "Dist123!")
        hsh  = bcrypt.hashpw(pwd.encode(), bcrypt.gensalt()).decode()
        cur.execute("UPDATE usuarios SET password_hash=%s WHERE id_usuario=%s",
                    (hsh, row["id_usuario"]))
    db.commit()
    db.close()

with app.app_context():
    init_passwords()

if __name__ == "__main__":
    app.run(debug=True)