-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 05-06-2026 a las 19:20:27
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `pil_andina`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_crear_lote` (IN `p_numero_lote` VARCHAR(50), IN `p_id_producto` INT, IN `p_id_bodega` INT, IN `p_id_planta` INT, IN `p_fecha_produccion` DATE, IN `p_fecha_vencimiento` DATE, IN `p_cantidad` INT, IN `p_id_usuario` INT)   BEGIN
    DECLARE v_id INT;
    INSERT INTO lotes(numero_lote, id_producto, id_bodega, id_planta,
                      fecha_produccion, fecha_vencimiento,
                      cantidad_producida, cantidad_disponible, estado)
    VALUES(p_numero_lote, p_id_producto, p_id_bodega, p_id_planta,
           p_fecha_produccion, p_fecha_vencimiento,
           p_cantidad, p_cantidad, 'Aprobado');
 
    SET v_id = LAST_INSERT_ID();
 
    INSERT INTO auditoria(id_usuario, accion, tabla_afectada, id_registro, detalle)
    VALUES(p_id_usuario, 'CREAR_LOTE', 'lotes', v_id,
           CONCAT('Lote ', p_numero_lote, ' creado con ', p_cantidad, ' unidades'));
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_despachar_pedido` (IN `p_id_pedido` INT, IN `p_id_usuario` INT, OUT `p_mensaje` VARCHAR(200))   BEGIN
    DECLARE v_estado     VARCHAR(30);
    DECLARE v_id_lote    INT;
    DECLARE v_cantidad   INT;
    DECLARE v_disponible INT;
    DECLARE done         INT DEFAULT 0;
 
    DECLARE cur CURSOR FOR
        SELECT id_lote, cantidad FROM detalle_pedidos WHERE id_pedido = p_id_pedido;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_mensaje = 'Error interno al despachar el pedido.';
    END;
 
    START TRANSACTION;
 
    SELECT estado INTO v_estado
    FROM pedidos WHERE id_pedido = p_id_pedido FOR UPDATE;
 
    IF v_estado != 'Pendiente' THEN
        ROLLBACK;
        SET p_mensaje = 'Solo se pueden despachar pedidos en estado Pendiente.';
    ELSE
        OPEN cur;
        loop_lotes: LOOP
            FETCH cur INTO v_id_lote, v_cantidad;
            IF done THEN LEAVE loop_lotes; END IF;
 
            SELECT cantidad_disponible INTO v_disponible
            FROM lotes WHERE id_lote = v_id_lote FOR UPDATE;
 
            IF v_disponible < v_cantidad THEN
                ROLLBACK;
                SET p_mensaje = CONCAT('Stock insuficiente en lote ', v_id_lote);
                LEAVE loop_lotes;
            END IF;
 
            UPDATE lotes
            SET cantidad_disponible = cantidad_disponible - v_cantidad
            WHERE id_lote = v_id_lote;
        END LOOP;
        CLOSE cur;
 
        UPDATE pedidos
        SET estado = 'Despachado', fecha_entrega_real = CURDATE()
        WHERE id_pedido = p_id_pedido;
 
        INSERT INTO auditoria(id_usuario, accion, tabla_afectada, id_registro, detalle)
        VALUES(p_id_usuario, 'DESPACHAR', 'pedidos', p_id_pedido,
               CONCAT('Pedido #', p_id_pedido, ' despachado'));
 
        COMMIT;
        SET p_mensaje = 'Pedido despachado correctamente.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_stock_producto` (IN `p_id_producto` INT)   BEGIN
    SELECT
        pl.nombre            AS planta,
        b.nombre             AS bodega,
        l.numero_lote,
        l.fecha_vencimiento,
        l.cantidad_disponible AS stock,
        DATEDIFF(l.fecha_vencimiento, CURDATE()) AS dias_para_vencer
    FROM lotes     l
    JOIN bodegas   b  ON l.id_bodega   = b.id_bodega
    JOIN plantas   pl ON l.id_planta   = pl.id_planta
    WHERE l.id_producto = p_id_producto
      AND l.estado = 'Aprobado'
      AND l.cantidad_disponible > 0
    ORDER BY l.fecha_vencimiento ASC;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `auditoria`
--

CREATE TABLE `auditoria` (
  `id_auditoria` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `accion` varchar(100) NOT NULL,
  `tabla_afectada` varchar(100) NOT NULL,
  `id_registro` int(11) DEFAULT NULL,
  `detalle` text DEFAULT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bodegas`
--

CREATE TABLE `bodegas` (
  `id_bodega` int(11) NOT NULL,
  `id_planta` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `tipo` enum('Producto Terminado','Insumos','Refrigerado') NOT NULL,
  `capacidad_max` int(11) NOT NULL COMMENT 'Capacidad en unidades',
  `temp_min` decimal(5,2) DEFAULT NULL COMMENT 'Temperatura mínima °C',
  `temp_max` decimal(5,2) DEFAULT NULL COMMENT 'Temperatura máxima °C',
  `activa` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `bodegas`
--

INSERT INTO `bodegas` (`id_bodega`, `id_planta`, `nombre`, `tipo`, `capacidad_max`, `temp_min`, `temp_max`, `activa`) VALUES
(1, 1, 'BD-LP-PT', 'Producto Terminado', 50000, 4.00, 12.00, 1),
(2, 1, 'BD-LP-IN', 'Insumos', 20000, 15.00, 25.00, 1),
(3, 1, 'BD-LP-RF', 'Refrigerado', 8000, 1.00, 4.00, 1),
(4, 2, 'BD-CB-PT', 'Producto Terminado', 45000, 4.00, 12.00, 1),
(5, 2, 'BD-CB-IN', 'Insumos', 18000, 15.00, 25.00, 1),
(6, 2, 'BD-CB-RF', 'Refrigerado', 7000, 1.00, 4.00, 1),
(7, 3, 'BD-SC-PT', 'Producto Terminado', 60000, 4.00, 12.00, 1),
(8, 3, 'BD-SC-IN', 'Insumos', 22000, 15.00, 25.00, 1),
(9, 3, 'BD-SC-RF', 'Refrigerado', 9000, 1.00, 4.00, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedidos`
--

CREATE TABLE `detalle_pedidos` (
  `id_detalle` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_lote` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` decimal(10,2) NOT NULL,
  `subtotal` decimal(12,2) GENERATED ALWAYS AS (`cantidad` * `precio_unitario`) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `detalle_pedidos`
--

INSERT INTO `detalle_pedidos` (`id_detalle`, `id_pedido`, `id_lote`, `cantidad`, `precio_unitario`) VALUES
(1, 1, 1, 200, 8.50),
(2, 1, 2, 100, 13.00),
(3, 2, 3, 150, 8.50),
(4, 2, 5, 200, 8.00),
(5, 3, 4, 100, 13.00),
(6, 3, 6, 150, 12.50),
(7, 4, 1, 300, 8.50),
(8, 4, 7, 100, 14.00),
(9, 5, 8, 200, 7.50),
(10, 5, 9, 100, 9.00),
(11, 6, 2, 200, 13.00),
(12, 6, 10, 100, 11.00),
(13, 7, 1, 500, 8.50),
(14, 7, 3, 300, 8.50),
(15, 8, 5, 400, 8.00),
(16, 8, 11, 200, 7.50),
(17, 9, 6, 100, 12.50),
(18, 10, 12, 100, 18.00),
(19, 10, 7, 150, 14.00),
(20, 11, 1, 250, 8.50),
(21, 11, 4, 250, 13.00),
(22, 12, 9, 300, 9.00),
(23, 12, 10, 200, 11.00);

--
-- Disparadores `detalle_pedidos`
--
DELIMITER $$
CREATE TRIGGER `trg_monto_pedido` AFTER INSERT ON `detalle_pedidos` FOR EACH ROW BEGIN
    UPDATE pedidos
    SET monto_total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM detalle_pedidos
        WHERE id_pedido = NEW.id_pedido
    )
    WHERE id_pedido = NEW.id_pedido;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `distribuidores`
--

CREATE TABLE `distribuidores` (
  `id_distribuidor` int(11) NOT NULL,
  `nit` varchar(20) NOT NULL,
  `razon_social` varchar(200) NOT NULL,
  `ciudad` varchar(100) NOT NULL,
  `zona` varchar(100) DEFAULT NULL,
  `direccion` varchar(300) NOT NULL,
  `contacto` varchar(150) NOT NULL,
  `telefono` varchar(20) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `distribuidores`
--

INSERT INTO `distribuidores` (`id_distribuidor`, `nit`, `razon_social`, `ciudad`, `zona`, `direccion`, `contacto`, `telefono`, `email`, `activo`, `creado_en`) VALUES
(1, '1001001001', 'Distribuidora Andina SRL', 'La Paz', 'Zona Sur', 'Av. Illimani 234', 'Mario Condori', '72234567', 'andina@dist.bo', 1, '2026-06-04 20:19:15'),
(2, '1002002002', 'Comercial El Buen Gusto', 'La Paz', 'Centro', 'Calle Murillo 123', 'Ana Flores', '71123456', 'buen@dist.bo', 1, '2026-06-04 20:19:15'),
(3, '1003003003', 'Distribuidora Valle Verde', 'Cochabamba', 'Norte', 'Av. Heroínas 456', 'Luis Medina', '77345678', 'valle@dist.bo', 1, '2026-06-04 20:19:15'),
(4, '1004004004', 'Bebidas del Oriente SRL', 'Santa Cruz', 'Plan 3000', 'Calle Warnes 789', 'Paola Ribera', '78456789', 'oriente@dist.bo', 1, '2026-06-04 20:19:15'),
(5, '1005005005', 'Distribuciones Norteña', 'La Paz', 'El Alto', 'Av. Montes 567', 'Pedro Quispe', '79567890', 'nortena@dist.bo', 1, '2026-06-04 20:19:15'),
(6, '1006006006', 'Gran Distribuidora Central', 'Cochabamba', 'Sacaba', 'Av. Blanco Galindo 234', 'Sandra Lima', '70678901', 'central@dist.bo', 1, '2026-06-04 20:19:15'),
(7, '1007007007', 'Comercial Los Andes', 'Santa Cruz', 'Equipetrol', 'Av. Cristo Redentor 12', 'Roberto Vaca', '67789012', 'andes@dist.bo', 1, '2026-06-04 20:19:15'),
(8, '1008008008', 'Distribuidora Sur Boliviana', 'Oruro', 'Centro', 'Calle Potosí 890', 'Carmen Chávez', '68890123', 'sur@dist.bo', 1, '2026-06-04 20:19:15'),
(9, '1009009009', 'Bebidas Tropicales SCZ', 'Santa Cruz', 'Centro', 'Av. Cañoto 345', 'Jorge Suárez', '60901234', 'tropical@dist.bo', 1, '2026-06-04 20:19:15'),
(10, '1010010010', 'Paceña Express', 'La Paz', 'Garita de Lima', 'Garita de Lima 67', 'Silvia Ramos', '71012345', 'express@dist.bo', 1, '2026-06-04 20:19:15'),
(11, '1011011011', 'Comercial Chapare', 'Cochabamba', 'Chapare', 'Av. Principal 111', 'Hugo Villarroel', '77112233', 'chapare@dist.bo', 1, '2026-06-04 20:19:15'),
(12, '1012012012', 'Distribuciones Cruceñas', 'Santa Cruz', 'Beni', 'Av. Beni 222', 'Natalia Guzmán', '78223344', 'crucena@dist.bo', 1, '2026-06-04 20:19:15');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `lotes`
--

CREATE TABLE `lotes` (
  `id_lote` int(11) NOT NULL,
  `numero_lote` varchar(50) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `id_bodega` int(11) NOT NULL COMMENT 'Bodega donde está almacenado',
  `id_planta` int(11) NOT NULL COMMENT 'Planta que lo produjo',
  `fecha_produccion` date NOT NULL,
  `fecha_vencimiento` date NOT NULL,
  `cantidad_producida` int(11) NOT NULL,
  `cantidad_disponible` int(11) NOT NULL,
  `estado` enum('En Producción','Aprobado','Rechazado','Agotado') NOT NULL DEFAULT 'En Producción',
  `creado_en` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `lotes`
--

INSERT INTO `lotes` (`id_lote`, `numero_lote`, `id_producto`, `id_bodega`, `id_planta`, `fecha_produccion`, `fecha_vencimiento`, `cantidad_producida`, `cantidad_disponible`, `estado`, `creado_en`) VALUES
(1, 'LP-2026-001', 1, 1, 1, '2026-01-15', '2026-07-15', 10000, 5000, 'Aprobado', '2026-06-04 20:19:15'),
(2, 'LP-2026-002', 2, 1, 1, '2026-01-20', '2026-07-20', 8000, 4000, 'Aprobado', '2026-06-04 20:19:15'),
(3, 'LP-2026-003', 3, 4, 2, '2026-02-01', '2026-08-01', 7000, 3500, 'Aprobado', '2026-06-04 20:19:15'),
(4, 'LP-2026-004', 4, 4, 2, '2026-02-10', '2026-08-10', 6000, 3000, 'Aprobado', '2026-06-04 20:19:15'),
(5, 'LP-2026-005', 5, 7, 3, '2026-02-15', '2026-08-15', 9000, 4500, 'Aprobado', '2026-06-04 20:19:15'),
(6, 'LP-2026-006', 6, 7, 3, '2026-02-20', '2026-08-20', 5000, 2500, 'Aprobado', '2026-06-04 20:19:15'),
(7, 'LP-2026-007', 7, 1, 1, '2026-03-01', '2026-09-01', 4000, 4000, 'Aprobado', '2026-06-04 20:19:15'),
(8, 'LP-2026-008', 8, 4, 2, '2026-03-05', '2026-06-10', 3000, 1500, 'Aprobado', '2026-06-04 20:19:15'),
(9, 'LP-2026-009', 9, 7, 3, '2026-03-10', '2026-09-10', 6000, 6000, 'Aprobado', '2026-06-04 20:19:15'),
(10, 'LP-2026-010', 10, 1, 1, '2026-03-15', '2026-06-12', 5000, 2000, 'Aprobado', '2026-06-04 20:19:15'),
(11, 'LP-2026-011', 11, 4, 2, '2026-03-20', '2026-06-08', 4000, 1800, 'Aprobado', '2026-06-04 20:19:15'),
(12, 'LP-2026-012', 12, 7, 3, '2026-04-01', '2026-10-01', 2000, 2000, 'Aprobado', '2026-06-04 20:19:15');

--
-- Disparadores `lotes`
--
DELIMITER $$
CREATE TRIGGER `trg_lote_agotado` AFTER UPDATE ON `lotes` FOR EACH ROW BEGIN
    IF NEW.cantidad_disponible = 0 AND OLD.cantidad_disponible > 0 THEN
        UPDATE lotes SET estado = 'Agotado' WHERE id_lote = NEW.id_lote;
        INSERT INTO auditoria(accion, tabla_afectada, id_registro, detalle)
        VALUES('STOCK_AGOTADO', 'lotes', NEW.id_lote,
               CONCAT('Lote ', NEW.numero_lote, ' marcado como Agotado'));
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `id_pedido` int(11) NOT NULL,
  `id_distribuidor` int(11) NOT NULL,
  `fecha_pedido` datetime NOT NULL DEFAULT current_timestamp(),
  `fecha_entrega_req` date NOT NULL,
  `fecha_entrega_real` date DEFAULT NULL,
  `estado` enum('Pendiente','Despachado','Entregado','Cancelado') NOT NULL DEFAULT 'Pendiente',
  `monto_total` decimal(12,2) NOT NULL DEFAULT 0.00,
  `notas` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `pedidos`
--

INSERT INTO `pedidos` (`id_pedido`, `id_distribuidor`, `fecha_pedido`, `fecha_entrega_req`, `fecha_entrega_real`, `estado`, `monto_total`, `notas`) VALUES
(1, 1, '2026-05-28 09:00:00', '2026-06-05', NULL, 'Pendiente', 3000.00, NULL),
(2, 2, '2026-05-29 10:30:00', '2026-06-06', NULL, 'Pendiente', 2875.00, NULL),
(3, 3, '2026-05-30 08:00:00', '2026-06-07', NULL, 'Despachado', 3175.00, NULL),
(4, 4, '2026-05-25 11:00:00', '2026-06-01', NULL, 'Entregado', 3950.00, NULL),
(5, 5, '2026-05-26 14:00:00', '2026-06-02', NULL, 'Entregado', 2400.00, NULL),
(6, 6, '2026-05-31 09:30:00', '2026-06-08', NULL, 'Pendiente', 3700.00, NULL),
(7, 7, '2026-06-01 10:00:00', '2026-06-10', NULL, 'Pendiente', 6800.00, NULL),
(8, 8, '2026-06-01 11:30:00', '2026-06-11', NULL, 'Pendiente', 4700.00, NULL),
(9, 9, '2026-05-27 09:00:00', '2026-06-03', NULL, 'Cancelado', 1250.00, NULL),
(10, 10, '2026-06-02 08:00:00', '2026-06-12', NULL, 'Pendiente', 3900.00, NULL),
(11, 11, '2026-06-02 14:00:00', '2026-06-13', NULL, 'Pendiente', 5375.00, NULL),
(12, 12, '2026-06-03 10:00:00', '2026-06-14', NULL, 'Pendiente', 4900.00, NULL);

--
-- Disparadores `pedidos`
--
DELIMITER $$
CREATE TRIGGER `trg_auditoria_pedido` AFTER UPDATE ON `pedidos` FOR EACH ROW BEGIN
    IF OLD.estado != NEW.estado THEN
        INSERT INTO auditoria(accion, tabla_afectada, id_registro, detalle)
        VALUES('CAMBIO_ESTADO', 'pedidos', NEW.id_pedido,
               CONCAT('Estado: "', OLD.estado, '" → "', NEW.estado, '"'));
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `plantas`
--

CREATE TABLE `plantas` (
  `id_planta` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `ciudad` varchar(100) NOT NULL,
  `direccion` varchar(200) NOT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `activa` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `plantas`
--

INSERT INTO `plantas` (`id_planta`, `nombre`, `ciudad`, `direccion`, `telefono`, `email`, `activa`, `creado_en`) VALUES
(1, 'Planta La Paz', 'La Paz', 'Mecapaca, Carretera a Palca km 12', '2-2771000', 'lapaz@pilandina.bo', 1, '2026-06-04 20:19:15'),
(2, 'Planta Cochabamba', 'Cochabamba', 'Sacaba, Zona Industrial Av. Melchor', '4-4280100', 'cbba@pilandina.bo', 1, '2026-06-04 20:19:15'),
(3, 'Planta Santa Cruz', 'Santa Cruz', 'Palmasola, Carretera Norte km 8', '3-3462200', 'scz@pilandina.bo', 1, '2026-06-04 20:19:15');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` int(11) NOT NULL,
  `codigo` varchar(20) NOT NULL,
  `marca` varchar(100) NOT NULL COMMENT 'Paceña, Taquiña, Huari…',
  `tipo` enum('Lager','Pilsener','Malta','Negra','Stout','Ale') NOT NULL,
  `presentacion` enum('355ml','500ml','620ml','1L','2L') NOT NULL,
  `graduacion_alc` decimal(4,2) NOT NULL COMMENT '% alcohol',
  `precio_unitario` decimal(10,2) NOT NULL,
  `stock_minimo` int(11) NOT NULL DEFAULT 100,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `codigo`, `marca`, `tipo`, `presentacion`, `graduacion_alc`, `precio_unitario`, `stock_minimo`, `activo`, `creado_en`) VALUES
(1, 'PAC-355', 'Paceña', 'Lager', '355ml', 4.60, 8.50, 500, 1, '2026-06-04 20:19:15'),
(2, 'PAC-620', 'Paceña', 'Lager', '620ml', 4.60, 13.00, 500, 1, '2026-06-04 20:19:15'),
(3, 'TAQ-355', 'Taquiña', 'Pilsener', '355ml', 5.00, 8.50, 300, 1, '2026-06-04 20:19:15'),
(4, 'TAQ-620', 'Taquiña', 'Pilsener', '620ml', 5.00, 13.00, 300, 1, '2026-06-04 20:19:15'),
(5, 'HUA-355', 'Huari', 'Lager', '355ml', 4.80, 8.00, 300, 1, '2026-06-04 20:19:15'),
(6, 'HUA-620', 'Huari', 'Lager', '620ml', 4.80, 12.50, 300, 1, '2026-06-04 20:19:15'),
(7, 'BOC-620', 'Bock', 'Negra', '620ml', 5.50, 14.00, 200, 1, '2026-06-04 20:19:15'),
(8, 'REA-355', 'Real', 'Pilsener', '355ml', 4.70, 7.50, 200, 1, '2026-06-04 20:19:15'),
(9, 'IMP-620', 'Imperial', 'Malta', '620ml', 0.50, 9.00, 200, 1, '2026-06-04 20:19:15'),
(10, 'POT-620', 'Potosina', 'Lager', '620ml', 4.50, 11.00, 200, 1, '2026-06-04 20:19:15'),
(11, 'COP-355', 'Copacabana', 'Lager', '355ml', 4.40, 7.50, 150, 1, '2026-06-04 20:19:15'),
(12, 'PAC-1L', 'Paceña', 'Lager', '1L', 4.60, 18.00, 100, 1, '2026-06-04 20:19:15');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int(11) NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `apellido` varchar(150) NOT NULL,
  `email` varchar(150) NOT NULL,
  `password_hash` varchar(255) NOT NULL COMMENT 'bcrypt — nunca texto plano',
  `rol` enum('Administrador','Gerente','Distribuidor') NOT NULL DEFAULT 'Distribuidor',
  `id_distribuidor` int(11) DEFAULT NULL COMMENT 'Solo si rol = Distribuidor',
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `ultimo_login` datetime DEFAULT NULL,
  `creado_en` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `nombre`, `apellido`, `email`, `password_hash`, `rol`, `id_distribuidor`, `activo`, `ultimo_login`, `creado_en`) VALUES
(1, 'Administrador', 'Sistema', 'admin@pilandina.bo', 'CHANGEME', 'Administrador', NULL, 1, NULL, '2026-06-04 20:19:15'),
(2, 'Carlos', 'Mamani', 'gerente@pilandina.bo', 'CHANGEME', 'Gerente', NULL, 1, NULL, '2026-06-04 20:19:15'),
(3, 'Rosa', 'Torrez', 'rtorrez@pilandina.bo', 'CHANGEME', 'Gerente', NULL, 1, NULL, '2026-06-04 20:19:15'),
(4, 'Mario', 'Condori', 'andina@dist.bo', 'CHANGEME', 'Distribuidor', 1, 1, NULL, '2026-06-04 20:19:15'),
(5, 'Ana', 'Flores', 'buen@dist.bo', 'CHANGEME', 'Distribuidor', 2, 1, NULL, '2026-06-04 20:19:15'),
(6, 'Luis', 'Medina', 'valle@dist.bo', 'CHANGEME', 'Distribuidor', 3, 1, NULL, '2026-06-04 20:19:15'),
(7, 'Paola', 'Ribera', 'oriente@dist.bo', 'CHANGEME', 'Distribuidor', 4, 1, NULL, '2026-06-04 20:19:15'),
(8, 'Pedro', 'Quispe', 'nortena@dist.bo', 'CHANGEME', 'Distribuidor', 5, 1, NULL, '2026-06-04 20:19:15'),
(9, 'Sandra', 'Lima', 'central@dist.bo', 'CHANGEME', 'Distribuidor', 6, 1, NULL, '2026-06-04 20:19:15'),
(10, 'Roberto', 'Vaca', 'andes@dist.bo', 'CHANGEME', 'Distribuidor', 7, 1, NULL, '2026-06-04 20:19:15'),
(11, 'Carmen', 'Chávez', 'sur@dist.bo', 'CHANGEME', 'Distribuidor', 8, 1, NULL, '2026-06-04 20:19:15'),
(12, 'Jorge', 'Suárez', 'tropical@dist.bo', 'CHANGEME', 'Distribuidor', 9, 1, NULL, '2026-06-04 20:19:15'),
(13, 'Silvia', 'Ramos', 'express@dist.bo', 'CHANGEME', 'Distribuidor', 10, 1, NULL, '2026-06-04 20:19:15');

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_pedidos_pendientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_pedidos_pendientes` (
`razon_social` varchar(200)
,`ciudad` varchar(100)
,`contacto` varchar(150)
,`telefono` varchar(20)
,`id_pedido` int(11)
,`fecha_pedido` datetime
,`fecha_entrega_req` date
,`monto_total` decimal(12,2)
,`estado` enum('Pendiente','Despachado','Entregado','Cancelado')
,`dias_para_entrega` int(7)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_produccion_mensual`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_produccion_mensual` (
`planta` varchar(100)
,`marca` varchar(100)
,`presentacion` enum('355ml','500ml','620ml','1L','2L')
,`anio` int(4)
,`mes` int(2)
,`total_lotes` bigint(21)
,`total_unidades` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_proximos_a_vencer`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_proximos_a_vencer` (
`numero_lote` varchar(50)
,`marca` varchar(100)
,`presentacion` enum('355ml','500ml','620ml','1L','2L')
,`planta` varchar(100)
,`bodega` varchar(100)
,`cantidad_disponible` int(11)
,`fecha_vencimiento` date
,`dias_restantes` int(7)
,`nivel_alerta` varchar(11)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_stock_actual`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_stock_actual` (
`marca` varchar(100)
,`presentacion` enum('355ml','500ml','620ml','1L','2L')
,`planta` varchar(100)
,`bodega` varchar(100)
,`numero_lote` varchar(50)
,`fecha_vencimiento` date
,`stock` int(11)
,`dias_para_vencer` int(7)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `v_pedidos_pendientes`
--
DROP TABLE IF EXISTS `v_pedidos_pendientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_pedidos_pendientes`  AS SELECT `d`.`razon_social` AS `razon_social`, `d`.`ciudad` AS `ciudad`, `d`.`contacto` AS `contacto`, `d`.`telefono` AS `telefono`, `p`.`id_pedido` AS `id_pedido`, `p`.`fecha_pedido` AS `fecha_pedido`, `p`.`fecha_entrega_req` AS `fecha_entrega_req`, `p`.`monto_total` AS `monto_total`, `p`.`estado` AS `estado`, to_days(`p`.`fecha_entrega_req`) - to_days(curdate()) AS `dias_para_entrega` FROM (`pedidos` `p` join `distribuidores` `d` on(`p`.`id_distribuidor` = `d`.`id_distribuidor`)) WHERE `p`.`estado` in ('Pendiente','Despachado') ORDER BY `p`.`fecha_entrega_req` ASC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_produccion_mensual`
--
DROP TABLE IF EXISTS `v_produccion_mensual`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_produccion_mensual`  AS SELECT `pl`.`nombre` AS `planta`, `p`.`marca` AS `marca`, `p`.`presentacion` AS `presentacion`, year(`l`.`fecha_produccion`) AS `anio`, month(`l`.`fecha_produccion`) AS `mes`, count(`l`.`id_lote`) AS `total_lotes`, sum(`l`.`cantidad_producida`) AS `total_unidades` FROM ((`lotes` `l` join `productos` `p` on(`l`.`id_producto` = `p`.`id_producto`)) join `plantas` `pl` on(`l`.`id_planta` = `pl`.`id_planta`)) WHERE `l`.`estado` in ('Aprobado','Agotado') GROUP BY `pl`.`id_planta`, `p`.`id_producto`, year(`l`.`fecha_produccion`), month(`l`.`fecha_produccion`) ORDER BY year(`l`.`fecha_produccion`) DESC, month(`l`.`fecha_produccion`) DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_proximos_a_vencer`
--
DROP TABLE IF EXISTS `v_proximos_a_vencer`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_proximos_a_vencer`  AS SELECT `l`.`numero_lote` AS `numero_lote`, `p`.`marca` AS `marca`, `p`.`presentacion` AS `presentacion`, `pl`.`nombre` AS `planta`, `b`.`nombre` AS `bodega`, `l`.`cantidad_disponible` AS `cantidad_disponible`, `l`.`fecha_vencimiento` AS `fecha_vencimiento`, to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) AS `dias_restantes`, CASE WHEN to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) <= 7 THEN 'CRÍTICO' WHEN to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) <= 15 THEN 'URGENTE' ELSE 'ADVERTENCIA' END AS `nivel_alerta` FROM (((`lotes` `l` join `productos` `p` on(`l`.`id_producto` = `p`.`id_producto`)) join `bodegas` `b` on(`l`.`id_bodega` = `b`.`id_bodega`)) join `plantas` `pl` on(`l`.`id_planta` = `pl`.`id_planta`)) WHERE `l`.`estado` = 'Aprobado' AND `l`.`cantidad_disponible` > 0 AND to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) between 0 and 30 ORDER BY to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) ASC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_stock_actual`
--
DROP TABLE IF EXISTS `v_stock_actual`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_stock_actual`  AS SELECT `p`.`marca` AS `marca`, `p`.`presentacion` AS `presentacion`, `pl`.`nombre` AS `planta`, `b`.`nombre` AS `bodega`, `l`.`numero_lote` AS `numero_lote`, `l`.`fecha_vencimiento` AS `fecha_vencimiento`, `l`.`cantidad_disponible` AS `stock`, to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) AS `dias_para_vencer` FROM (((`lotes` `l` join `productos` `p` on(`l`.`id_producto` = `p`.`id_producto`)) join `bodegas` `b` on(`l`.`id_bodega` = `b`.`id_bodega`)) join `plantas` `pl` on(`l`.`id_planta` = `pl`.`id_planta`)) WHERE `l`.`estado` = 'Aprobado' AND `l`.`cantidad_disponible` > 0 ORDER BY to_days(`l`.`fecha_vencimiento`) - to_days(curdate()) ASC ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `auditoria`
--
ALTER TABLE `auditoria`
  ADD PRIMARY KEY (`id_auditoria`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `idx_auditoria_tabla_fecha` (`tabla_afectada`,`fecha`);

--
-- Indices de la tabla `bodegas`
--
ALTER TABLE `bodegas`
  ADD PRIMARY KEY (`id_bodega`),
  ADD KEY `id_planta` (`id_planta`);

--
-- Indices de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD PRIMARY KEY (`id_detalle`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_lote` (`id_lote`);

--
-- Indices de la tabla `distribuidores`
--
ALTER TABLE `distribuidores`
  ADD PRIMARY KEY (`id_distribuidor`),
  ADD UNIQUE KEY `nit` (`nit`);

--
-- Indices de la tabla `lotes`
--
ALTER TABLE `lotes`
  ADD PRIMARY KEY (`id_lote`),
  ADD UNIQUE KEY `numero_lote` (`numero_lote`),
  ADD KEY `id_producto` (`id_producto`),
  ADD KEY `id_planta` (`id_planta`),
  ADD KEY `idx_lotes_vencimiento` (`fecha_vencimiento`),
  ADD KEY `idx_lotes_bodega_estado` (`id_bodega`,`estado`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id_pedido`),
  ADD KEY `idx_pedidos_dist_estado` (`id_distribuidor`,`estado`);

--
-- Indices de la tabla `plantas`
--
ALTER TABLE `plantas`
  ADD PRIMARY KEY (`id_planta`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`),
  ADD UNIQUE KEY `codigo` (`codigo`),
  ADD KEY `idx_productos_marca` (`marca`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `id_distribuidor` (`id_distribuidor`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `auditoria`
--
ALTER TABLE `auditoria`
  MODIFY `id_auditoria` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `bodegas`
--
ALTER TABLE `bodegas`
  MODIFY `id_bodega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  MODIFY `id_detalle` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT de la tabla `distribuidores`
--
ALTER TABLE `distribuidores`
  MODIFY `id_distribuidor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `lotes`
--
ALTER TABLE `lotes`
  MODIFY `id_lote` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `plantas`
--
ALTER TABLE `plantas`
  MODIFY `id_planta` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `auditoria`
--
ALTER TABLE `auditoria`
  ADD CONSTRAINT `auditoria_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE SET NULL;

--
-- Filtros para la tabla `bodegas`
--
ALTER TABLE `bodegas`
  ADD CONSTRAINT `bodegas_ibfk_1` FOREIGN KEY (`id_planta`) REFERENCES `plantas` (`id_planta`);

--
-- Filtros para la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD CONSTRAINT `detalle_pedidos_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_pedidos_ibfk_2` FOREIGN KEY (`id_lote`) REFERENCES `lotes` (`id_lote`);

--
-- Filtros para la tabla `lotes`
--
ALTER TABLE `lotes`
  ADD CONSTRAINT `lotes_ibfk_1` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`),
  ADD CONSTRAINT `lotes_ibfk_2` FOREIGN KEY (`id_bodega`) REFERENCES `bodegas` (`id_bodega`),
  ADD CONSTRAINT `lotes_ibfk_3` FOREIGN KEY (`id_planta`) REFERENCES `plantas` (`id_planta`);

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`id_distribuidor`) REFERENCES `distribuidores` (`id_distribuidor`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`id_distribuidor`) REFERENCES `distribuidores` (`id_distribuidor`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
