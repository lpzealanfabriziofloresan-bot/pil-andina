from flask_login import UserMixin

class User(UserMixin):
    def __init__(self, data: dict):
        self.id             = data["id_usuario"]
        self.nombre         = data["nombre"]
        self.apellido       = data["apellido"]
        self.email          = data["email"]
        self.rol            = data["rol"]
        self.id_distribuidor= data.get("id_distribuidor")
        self.activo         = data["activo"]

    def get_id(self):
        return str(self.id)

    def is_admin(self):
        return self.rol == "Administrador"

    def is_gerente(self):
        return self.rol in ("Administrador", "Gerente")