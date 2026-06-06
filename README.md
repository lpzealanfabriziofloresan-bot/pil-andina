# Proyecto Final — Pil Andina Cervecería

**Grupo:** Code Monkeys

**Integrantes:**
- Alan Fabrizio Flores Anavi
- Arturo Wilder Figueredo Sanjines
- Alvaro Ociel Sanchez Magne

**Repositorio:** https://github.com/lpzealanfabriziofloresan-bot/pil-andina

---

## Descripción del proyecto

Proyecto final completo de la materia Base de Datos 2, desarrollado según los requerimientos explicados por el docente.

Sistema web para la gestión de inventario, producción y distribución de Pil Andina S.A. La cervecería opera en tres plantas (La Paz, Cochabamba y Santa Cruz) y el sistema incluye:

- Base de datos MySQL en XAMPP con tablas, relaciones, vistas y procedimientos almacenados
- Login con tres roles: Administrador, Gerente y Distribuidor (cada uno ve pantallas distintas)
- CRUD de productos, lotes, pedidos, distribuidores y usuarios
- Reportes de stock por planta, productos próximos a vencer y rotación de inventario
- Panel de backups y monitoreo (procesos, logs y conexiones MySQL)

Desarrollado con Python/Flask, conectado a la base `pil_andina` en XAMPP.

---

## Instrucciones de instalación

**Requisitos:** Python 3.8+, XAMPP con MySQL encendido.

**1. Clonar el repo**

```bash
git clone https://github.com/lpzealanfabriziofloresan-bot/pil-andina.git
cd pil-andina
```

**2. Base de datos**

- Abrir XAMPP y darle Start a MySQL.
- En phpMyAdmin (`http://localhost/phpmyadmin`) debe existir la base `pil_andina` con sus tablas, vistas y datos. La base se configura en XAMPP, no viene en este repo.

**3. Archivo .env**

```bash
copy .env.example .env
```

Los valores por defecto son:

```
DB_HOST=localhost
DB_USER=pil_admin
DB_PASSWORD=Admin@Pil2026!
DB_NAME=pil_andina
SECRET_KEY=pil-andina-secret-2026
FLASK_DEBUG=true
PORT=5000
```

**4. Instalar dependencias**

Windows:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Linux/macOS:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**5. Correr la app**

```bash
python app.py
```

Entrar en el navegador a: http://127.0.0.1:5000

La primera vez que arranca, la app hashea las contraseñas de usuarios que tengan `CHANGEME` en la base de datos.

---

## Credenciales de acceso

**Aplicación web**

| Rol | Email | Contraseña |
|-----|-------|------------|
| Administrador | admin@pilandina.bo | Admin123! |
| Gerente | gerente@pilandina.bo | Gerente123! |
| Gerente | rtorrez@pilandina.bo | Gerente123! |
| Distribuidor | andina@dist.bo | Dist123! |
| Distribuidor | buen@dist.bo | Dist123! |
| Distribuidor | valle@dist.bo | Dist123! |

**Base de datos MySQL**

| Usuario | Contraseña |
|---------|------------|
| pil_admin | Admin@Pil2026! |
| pil_gerente | Gerente@Pil2026! |
| pil_distribuidor | Dist@Pil2026! |

La app usa `pil_admin` (configurado en el `.env`).

