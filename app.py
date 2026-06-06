# Pil Andina — Sistema de Gestión de Inventario y Distribución

> Proyecto académico | Base de Datos 2 — Hitos 4 
> Docente: Ing. Alvaro G. Coronel Centellas  
> Universidad: Unifranz  
> Empresa Pil Anadina de cervecería con gestión de inventario, lotes, distribuidores y pedidos.

## 📋 Tabla de contenidos

- [Descripción del proyecto](#descripción-del-proyecto)
- [Tecnologías utilizadas](#tecnologías-utilizadas)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Base de datos](#base-de-datos)
- [Instalación y configuración](#instalación-y-configuración)
- [Credenciales por defecto](#credenciales-por-defecto)
- [Funcionalidades por rol](#funcionalidades-por-rol)
- [Vistas, procedimientos y triggers](#vistas-procedimientos-y-triggers)

Pil Andina S.A. es una empresa de cervecería boliviana con 3 plantas de producción (La Paz, Cochabamba y Santa Cruz). Este sistema web permite gestionar:

- Registro y control de lotes de producción con fechas de vencimiento
- Inventario de productos en bodegas por planta
- Pedidos de distribuidores con despacho y seguimiento
- Alertas automáticas de productos próximos a vencer
- Panel de auditoría y monitoreo de la base de datos
- Backups de la base de datos desde la interfaz

## 🛠 Tecnologías utilizadas

| Capa | Tecnología |
|------|-----------|
| Backend | Python 3.x + Flask |
| Base de datos | MySQL / MariaDB (XAMPP) |
| ORM / Conexión | mysql-connector-python |
| Autenticación | Flask-Login + bcrypt |
| Frontend | HTML5 + CSS3 + JavaScript (vanilla) |
| Exportación | pandas + openpyxl |
| Variables de entorno | python-dotenv |

### Tablas (9 tablas)

| # | Tabla | Descripción |
|---|-------|-------------|
| 1 | `plantas` | Las 3 plantas de producción |
| 2 | `productos` | Catálogo de cervezas (Paceña, Taquiña, Huari, etc.) |
| 3 | `bodegas` | Bodegas por planta (Producto Terminado, Insumos, Refrigerado) |
| 4 | `lotes` | Corridas de producción con stock y vencimiento |
| 5 | `distribuidores` | Empresas distribuidoras con NIT y zona |
| 6 | `pedidos` | Cabecera de pedidos |
| 7 | `detalle_pedidos` | Líneas de cada pedido |
| 8 | `usuarios` | Acceso al sistema con 3 roles |
| 9 | `auditoria` | Log automático de cambios (llenado por triggers) |

### Vistas (4 vistas)

| Vista | Descripción |
|-------|-------------|
| `v_stock_actual` | Stock disponible consolidado por producto, planta y bodega |
| `v_proximos_a_vencer` | Lotes con vencimiento en los próximos 30 días con nivel de alerta |
| `v_pedidos_pendientes` | Pedidos en estado Pendiente o Despachado con días restantes |
| `v_produccion_mensual` | Resumen de producción por planta, producto, año y mes |

### Procedimientos almacenados (3 SP)

| Procedimiento | Descripción |
|--------------|-------------|
| `sp_despachar_pedido` | Descuenta stock de lotes y cambia estado del pedido a Despachado |
| `sp_stock_producto` | Retorna el stock consolidado de un producto en todas las bodegas |
| `sp_crear_lote` | Registra un nuevo lote y deja auditoría automática |

### Triggers (3 triggers)

| Trigger | Evento | Descripción |
|---------|--------|-------------|
| `trg_lote_agotado` | AFTER UPDATE en lotes | Marca el lote como Agotado cuando el stock llega a 0 |
| `trg_auditoria_pedido` | AFTER UPDATE en pedidos | Registra cambios de estado en la tabla auditoria |
| `trg_monto_pedido` | AFTER INSERT en detalle_pedidos | Recalcula el monto_total del pedido automáticamente |

### Usuarios MySQL (3 roles de base de datos)

| Usuario MySQL | Contraseña | Permisos |
|--------------|-----------|---------|
| `pil_admin` | `Admin@Pil2026!` | FULL ACCESS — todos los privilegios |
| `pil_gerente` | `Gerente@Pil2026!` | SELECT, INSERT, UPDATE (sin DROP/CREATE) |
| `pil_distribuidor` | `Dist@Pil2026!` | SELECT solo en productos, pedidos y vistas |

## ⚙️ Instalación y configuración

### Requisitos previos

- Python 3.8 o superior
- XAMPP con MySQL/MariaDB corriendo
- Git

### Paso 1 — Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/pil_andina.git
cd pil_andina
```

### Paso 2 — Importar la base de datos en XAMPP

1. Abre XAMPP y arranca **Apache** y **MySQL**
2. Ve a `http://localhost/phpmyadmin`
3. Clic en **Importar** → selecciona `pil_andina.sql` → **Continuar**

### Paso 3 — Crear el archivo `.env`

Crea un archivo `.env` en la raíz del proyecto con este contenido:

DB_HOST=localhost
DB_USER=pil_admin
DB_PASSWORD=Admin@Pil2026!
DB_NAME=pil_andina
SECRET_KEY=pil-andina-secret-2026

### Paso 4 — Instalar dependencias Python

pip install -r requirements.txt

### Paso 5 — Correr el proyecto

python app.py

Abre tu navegador en: http://127.0.0.1:5000


## 🔐 Credenciales por defecto

> Las contraseñas se hashean con bcrypt automáticamente al primer arranque de la app.

### Usuarios de la aplicación web

| Rol | Email | Contraseña |
|-----|-------|-----------|
| Administrador | `admin@pilandina.bo` | `Admin123!` |
| Gerente | `gerente@pilandina.bo` | `Gerente123!` |
| Gerente | `rtorrez@pilandina.bo` | `Gerente123!` |
| Distribuidor | `andina@dist.bo` | `Dist123!` |
| Distribuidor | `buen@dist.bo` | `Dist123!` |
| Distribuidor | `valle@dist.bo` | `Dist123!` |

## 👤 Funcionalidades por rol

### Administrador
- Todo lo del Gerente
- Desactivar productos
- Ver y gestionar usuarios del sistema
- Generar backups de la base de datos
- Ver el monitor de procesos MySQL
- Ver el log completo de auditoría

### Gerente
- Ver dashboard con KPIs y alertas
- Crear, editar y ver productos
- Registrar nuevos lotes de producción
- Crear pedidos y despacharlos
- Exportar productos y pedidos a Excel

### Distribuidor
- Ver solo sus propios pedidos
- Ver catálogo de productos disponibles
- Ver stock actual (vista v_stock_actual)

## 📊 Índices de la base de datos (5 índices)

| Índice | Tabla | Columnas | Justificación |
|--------|-------|---------|--------------|
| `idx_lotes_vencimiento` | lotes | fecha_vencimiento | Consultas de alertas de vencimiento |
| `idx_lotes_bodega_estado` | lotes | id_bodega, estado | Stock en tiempo real por bodega |
| `idx_pedidos_dist_estado` | pedidos | id_distribuidor, estado | Reportes gerenciales por distribuidor |
| `idx_productos_marca` | productos | marca | Búsqueda y filtrado por marca |
| `idx_auditoria_tabla_fecha` | auditoria | tabla_afectada, fecha | Consultas de auditoría por tabla y fecha |

## 👥 Integrantes del grupo

| Nombre | Rol en el proyecto |
|--------|-------------------|
| Alan Fabrizio Flores Anavi | Base de datos |
| Arturo Wilder Figueredo Sanjines | Frontend |
| Alvaro Ociel Sanchez Magne | Backend |
