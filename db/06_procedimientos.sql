-- =====================================================================
-- SIMA  |  Procedimientos almacenados
--   Soporte transaccional de los flujos:
--     - Movimientos de inventario (entrada / salida / ajuste)
--     - Evaluacion de reposicion (ROP / RP)
--     - Registro de venta (descuenta stock + comprobante + comision)
--     - Bloqueo de cuenta por deuda (con notificacion)
--     - Cierre de reclamo con motivo
--     - Autenticacion y eliminacion de usuario
-- =====================================================================

USE sima;

-- ---------------------------------------------------------------------
-- 1. Registrar movimiento de inventario y actualizar el stock
--    ENTRADA: suma cantidad, recalcula costo promedio
--    SALIDA: descuenta cantidad, valida disponibilidad
--    AJUSTE: aplica diferencia con signo
--    NOTA: no controla la transaccion; debe invocarse dentro de una
--          transaccion (usar sp_movimiento_stock como punto de entrada).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_movimiento_inventario;

CREATE PROCEDURE sp_registrar_movimiento_inventario(
  IN  p_tipo                  VARCHAR(20),
  IN  p_id_productos          INT UNSIGNED,
  IN  p_id_lotes              INT UNSIGNED,
  IN  p_id_almacenes          SMALLINT UNSIGNED,
  IN  p_id_almacenes_destino  SMALLINT UNSIGNED,
  IN  p_cantidad              DECIMAL(15,3),
  IN  p_costo_unitario        DECIMAL(15,4),
  IN  p_id_usuarios           INT UNSIGNED,
  IN  p_documento_tipo        VARCHAR(40),
  IN  p_documento_id          INT UNSIGNED,
  IN  p_documento_numero      VARCHAR(40),
  IN  p_motivo                VARCHAR(255),
  OUT p_id_movimiento         BIGINT UNSIGNED
)
BEGIN
  DECLARE v_cantidad_actual DECIMAL(15,3) DEFAULT 0;
  DECLARE v_costo_actual   DECIMAL(15,4) DEFAULT 0;
  DECLARE v_costo_nuevo    DECIMAL(15,4) DEFAULT 0;
  DECLARE v_previa         DECIMAL(15,3) DEFAULT 0;
  DECLARE v_nueva          DECIMAL(15,3) DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    RESIGNAL;
  END;

  IF p_id_productos IS NULL OR p_id_almacenes IS NULL OR p_id_usuarios IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parametros obligatorios faltantes (producto, almacen, usuario)';
  END IF;

  IF p_tipo NOT IN ('ENTRADA','SALIDA','AJUSTE','TRANSFERENCIA','DEVOLUCION','MERMA') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de movimiento no valido';
  END IF;

  SELECT cantidad, costo_promedio
    INTO v_cantidad_actual, v_costo_actual
    FROM inventario_stock
   WHERE id_almacenes = p_id_almacenes
     AND id_productos = p_id_productos
     AND ((p_id_lotes IS NULL AND id_lotes IS NULL) OR id_lotes = p_id_lotes)
   LIMIT 1
   FOR UPDATE;

  SET v_previa = IFNULL(v_cantidad_actual, 0);
  SET v_costo_actual = IFNULL(v_costo_actual, 0);

  IF p_tipo = 'ENTRADA' THEN
    SET v_nueva = v_previa + p_cantidad;
    IF (v_previa + p_cantidad) > 0 THEN
      SET v_costo_nuevo = ROUND(((v_previa * v_costo_actual) + (p_cantidad * IFNULL(p_costo_unitario,0)))
                                 / (v_previa + p_cantidad), 4);
    ELSE
      SET v_costo_nuevo = IFNULL(p_costo_unitario, 0);
    END IF;
  ELSEIF p_tipo = 'SALIDA' THEN
    IF v_previa < p_cantidad THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para la salida solicitada';
    END IF;
    SET v_nueva = v_previa - p_cantidad;
    SET v_costo_nuevo = v_costo_actual;
  ELSEIF p_tipo = 'AJUSTE' THEN
    SET v_nueva = v_previa + p_cantidad;
    IF v_nueva < 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ajuste dejaria el stock en negativo';
    END IF;
    SET v_costo_nuevo = v_costo_actual;
  ELSE
    SET v_nueva = v_previa;
    SET v_costo_nuevo = v_costo_actual;
  END IF;

  INSERT INTO inventario_stock (
    id_almacenes, id_productos, id_lotes, cantidad, costo_promedio, valorizacion, ultimo_movimiento
  ) VALUES (
    p_id_almacenes, p_id_productos, p_id_lotes, v_nueva, v_costo_nuevo,
    ROUND(v_nueva * v_costo_nuevo, 2), NOW()
  )
  ON DUPLICATE KEY UPDATE
    cantidad          = v_nueva,
    costo_promedio    = v_costo_nuevo,
    valorizacion      = ROUND(v_nueva * v_costo_nuevo, 2),
    ultimo_movimiento = NOW();

  INSERT INTO inventario_movimientos (
    tipo_movimiento, id_productos, id_lotes, id_almacenes, id_almacenes_destino,
    cantidad, cantidad_previa, cantidad_posterior, costo_unitario, id_usuarios,
    documento_tipo, documento_id, documento_numero, motivo
  ) VALUES (
    p_tipo, p_id_productos, p_id_lotes, p_id_almacenes, p_id_almacenes_destino,
    p_cantidad, v_previa, v_nueva, p_costo_unitario, p_id_usuarios,
    p_documento_tipo, p_documento_id, p_documento_numero, p_motivo
  );

  SET p_id_movimiento = LAST_INSERT_ID();
END;

-- ---------------------------------------------------------------------
-- 1.b. Punto de entrada transaccional para movimientos de stock
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_movimiento_stock;

CREATE PROCEDURE sp_movimiento_stock(
  IN  p_tipo                  VARCHAR(20),
  IN  p_id_productos          INT UNSIGNED,
  IN  p_id_lotes              INT UNSIGNED,
  IN  p_id_almacenes          SMALLINT UNSIGNED,
  IN  p_id_almacenes_destino  SMALLINT UNSIGNED,
  IN  p_cantidad              DECIMAL(15,3),
  IN  p_costo_unitario        DECIMAL(15,4),
  IN  p_id_usuarios           INT UNSIGNED,
  IN  p_documento_tipo        VARCHAR(40),
  IN  p_documento_id          INT UNSIGNED,
  IN  p_documento_numero      VARCHAR(40),
  IN  p_motivo                VARCHAR(255),
  OUT p_id_movimiento         BIGINT UNSIGNED
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  CALL sp_registrar_movimiento_inventario(
    p_tipo, p_id_productos, p_id_lotes, p_id_almacenes, p_id_almacenes_destino,
    p_cantidad, p_costo_unitario, p_id_usuarios, p_documento_tipo, p_documento_id,
    p_documento_numero, p_motivo, p_id_movimiento
  );

  COMMIT;
END;

-- ---------------------------------------------------------------------
-- 2. Evaluar politica de reposicion y generar reposiciones
--    Compara el stock con el ROP y propone la cantidad RP
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_evaluar_reposiciones;

CREATE PROCEDURE sp_evaluar_reposiciones(
  IN  p_id_almacenes      SMALLINT UNSIGNED,
  IN  p_id_usuarios       INT UNSIGNED,
  IN  p_id_proveedores    INT UNSIGNED,
  OUT p_reposiciones_creadas INT UNSIGNED
)
BEGIN
  DECLARE v_codigo      VARCHAR(30);
  DECLARE v_id_reposicion INT UNSIGNED;
  DECLARE v_total        INT UNSIGNED DEFAULT 0;
  DECLARE v_fin          INT DEFAULT 0;
  DECLARE v_id_productos INT UNSIGNED;
  DECLARE v_id_almacenes SMALLINT UNSIGNED;
  DECLARE v_stock_actual DECIMAL(15,3);
  DECLARE v_rop          DECIMAL(15,3);
  DECLARE v_rp           DECIMAL(15,3);
  DECLARE v_cantidad_sugerida DECIMAL(15,3);
  DECLARE v_proveedor    INT UNSIGNED;

  DECLARE cur CURSOR FOR
    SELECT id_productos, id_almacenes, stock_actual, rop, rp, cantidad_sugerida, id_proveedores
      FROM vw_productos_bajo_minimo
     WHERE (p_id_almacenes IS NULL OR id_almacenes = p_id_almacenes)
     ORDER BY id_proveedores, id_productos;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;

  SET p_reposiciones_creadas = 0;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_id_productos, v_id_almacenes, v_stock_actual, v_rop, v_rp, v_cantidad_sugerida, v_proveedor;
    IF v_fin = 1 THEN
      LEAVE read_loop;
    END IF;

    SET v_codigo = CONCAT('REP-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', LPAD(v_total + 1, 4, '0'));

    INSERT INTO reposiciones (codigo, id_proveedores, id_usuarios, estado, fecha_generacion)
    VALUES (v_codigo, IFNULL(p_id_proveedores, v_proveedor), p_id_usuarios, 'GENERADA', NOW());

    SET v_id_reposicion = LAST_INSERT_ID();

    INSERT INTO reposiciones_detalle (
      id_reposiciones, id_productos, id_almacenes, stock_actual, rop, rp, cantidad_sugerida
    ) VALUES (
      v_id_reposicion, v_id_productos, v_id_almacenes, v_stock_actual, v_rop, v_rp, v_cantidad_sugerida
    );

    SET v_total = v_total + 1;
  END LOOP;
  CLOSE cur;

  SET p_reposiciones_creadas = v_total;
END;

-- ---------------------------------------------------------------------
-- 3. Registrar venta completa
--    Verifica stock -> descuenta stock -> genera comprobante -> calcula comision
--    p_items: JSON [{"id_productos":1,"cantidad":2,"precio_unitario":100,"descuento_pct":0,"id_lotes":null}]
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_venta;

CREATE PROCEDURE sp_registrar_venta(
  IN  p_clientes           INT UNSIGNED,
  IN  p_presupuestos       INT UNSIGNED,
  IN  p_usuarios           INT UNSIGNED,
  IN  p_vendedores         INT UNSIGNED,
  IN  p_almacenes          SMALLINT UNSIGNED,
  IN  p_estados_venta      SMALLINT UNSIGNED,
  IN  p_forma_pago         VARCHAR(20),
  IN  p_items              LONGTEXT COMMENT 'JSON: [{"id_productos":1,"cantidad":2,...}]',
  IN  p_observaciones      TEXT,
  OUT p_id_ventas          INT UNSIGNED,
  OUT p_numero             VARCHAR(30),
  OUT p_id_comprobante     INT UNSIGNED
)
BEGIN
  DECLARE v_numero      VARCHAR(30);
  DECLARE v_total       DECIMAL(15,2) DEFAULT 0;
  DECLARE v_subtotal    DECIMAL(15,2) DEFAULT 0;
  DECLARE v_descuento   DECIMAL(15,2) DEFAULT 0;
  DECLARE v_impuestos   DECIMAL(15,2) DEFAULT 0;
  DECLARE v_total_item  DECIMAL(15,2);
  DECLARE v_cantidad    DECIMAL(15,3);
  DECLARE v_precio      DECIMAL(15,4);
  DECLARE v_desc_pct    DECIMAL(5,2);
  DECLARE v_id_producto INT UNSIGNED;
  DECLARE v_id_lote     INT UNSIGNED;
  DECLARE v_costo       DECIMAL(15,4);
  DECLARE v_tasa_iva    DECIMAL(5,2);
  DECLARE v_json        TEXT;
  DECLARE v_i           INT DEFAULT 0;
  DECLARE v_cant        INT DEFAULT 0;
  DECLARE v_mov         BIGINT UNSIGNED;
  DECLARE v_bloqueado   TINYINT(1) DEFAULT 0;
  DECLARE v_existe      INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  -- El cliente no debe tener bloqueada la compra.
  SELECT bloqueado_compra INTO v_bloqueado FROM clientes WHERE id_clientes = p_clientes;
  IF v_bloqueado = 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente tiene la compra bloqueada por deuda';
  END IF;

  SET v_numero = CONCAT('V-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', LPAD(
      (SELECT COUNT(*) + 1 FROM ventas WHERE DATE(fecha_venta) = CURDATE()), 5, '0'));

  SET v_json = CAST(p_items AS CHAR);
  IF v_json IS NULL OR v_json = '' OR NOT JSON_VALID(v_json) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_items debe ser un JSON valido con los items de la venta';
  END IF;
  SET v_cant = JSON_LENGTH(v_json);

  INSERT INTO ventas (
    numero, id_clientes, id_presupuestos, id_usuarios, id_vendedores,
    id_almacenes_origen, id_estados_venta, fecha_venta, subtotal, descuento,
    recargo, impuestos, total, moneda, forma_pago, observaciones
  ) VALUES (
    v_numero, p_clientes, p_presupuestos, p_usuarios, p_vendedores,
    p_almacenes, p_estados_venta, CURDATE(), 0, 0, 0, 0, 0, 'ARS',
    IFNULL(p_forma_pago, 'CONTADO'), p_observaciones
  );

  SET p_id_ventas = LAST_INSERT_ID();

  WHILE v_i < v_cant DO
    SET v_id_producto = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].id_productos'))) AS UNSIGNED);
    SET v_cantidad   = CAST(IFNULL(JSON_UNQUOTE(JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].cantidad'))), 0) AS DECIMAL(15,3));
    SET v_precio     = CAST(IFNULL(JSON_UNQUOTE(JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].precio_unitario'))), 0) AS DECIMAL(15,4));
    SET v_desc_pct   = CAST(IFNULL(JSON_UNQUOTE(JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].descuento_pct'))), 0) AS DECIMAL(5,2));
    SET v_id_lote    = CASE
                         WHEN JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].id_lotes')) IS NULL THEN NULL
                         WHEN JSON_TYPE(JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].id_lotes'))) = 'NULL' THEN NULL
                         ELSE CAST(JSON_UNQUOTE(JSON_EXTRACT(v_json, CONCAT('$[', v_i, '].id_lotes'))) AS UNSIGNED)
                       END;

    SELECT COUNT(*) INTO v_existe FROM productos WHERE id_productos = v_id_producto;
    IF v_existe = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto indicado no existe';
    END IF;

    SELECT precio_costo, tasa_iva INTO v_costo, v_tasa_iva
      FROM productos WHERE id_productos = v_id_producto;

    SET v_total_item = ROUND(v_cantidad * v_precio * (1 - (v_desc_pct / 100)), 2);
    SET v_subtotal   = v_subtotal + ROUND(v_cantidad * v_precio, 2);
    SET v_descuento  = v_descuento + (ROUND(v_cantidad * v_precio, 2) - v_total_item);
    SET v_impuestos  = v_impuestos + ROUND(v_total_item * (v_tasa_iva / 100), 2);

    INSERT INTO ventas_items (
      id_ventas, id_productos, id_lotes, cantidad, precio_unitario,
      descuento_pct, subtotal, total
    ) VALUES (
      p_id_ventas, v_id_producto, v_id_lote, v_cantidad, v_precio,
      v_desc_pct, ROUND(v_cantidad * v_precio, 2), v_total_item
    );

    CALL sp_registrar_movimiento_inventario(
      'SALIDA', v_id_producto, v_id_lote, p_almacenes, NULL,
      v_cantidad, v_costo, p_usuarios, 'VENTA', p_id_ventas, v_numero,
      'Salida por venta', v_mov
    );

    SET v_i = v_i + 1;
  END WHILE;

  SET v_total = v_subtotal - v_descuento + v_impuestos;

  UPDATE ventas
     SET subtotal = v_subtotal, descuento = v_descuento, impuestos = v_impuestos, total = v_total
   WHERE id_ventas = p_id_ventas;

  -- Comprobante
  INSERT INTO comprobantes (
    tipo, numero, id_ventas, id_presupuestos, id_clientes, id_usuarios,
    fecha_emision, subtotal, impuestos, total, estado
  ) VALUES (
    'COMPROBANTE_VENTA', v_numero, p_id_ventas, p_presupuestos, p_clientes, p_usuarios,
    NOW(), v_subtotal, v_impuestos, v_total, 'GENERADO'
  );
  SET p_id_comprobante = LAST_INSERT_ID();

  -- Comision del vendedor segun la asignacion vigente del cliente
  IF p_vendedores IS NOT NULL THEN
    INSERT INTO comisiones (
      id_asignaciones_clientes, id_vendedores, id_clientes, id_ventas,
      tipo, base, porcentaje, monto, periodo, estado, id_usuarios_calculo
    )
    SELECT
      ac.id_asignaciones_clientes, p_vendedores, p_clientes, p_id_ventas,
      'VENTA', v_total, ac.comision_pct, ROUND(v_total * (ac.comision_pct / 100), 2),
      DATE_FORMAT(CURDATE(), '%Y-%m-01'), 'CALCULADA', p_usuarios
    FROM asignaciones_clientes ac
    WHERE ac.id_clientes = p_clientes
      AND ac.fecha_hasta IS NULL
      AND (ac.id_vendedores = p_vendedores OR ac.id_vendedores IS NULL)
    ORDER BY ac.tipo_asignacion DESC
    LIMIT 1;
  END IF;

  SET p_numero = v_numero;

  -- El presupuesto de origen queda convertido en venta.
  IF p_presupuestos IS NOT NULL THEN
    UPDATE presupuestos SET estado = 'CONVERTIDO_EN_VENTA', fecha_confirmacion = CURDATE()
     WHERE id_presupuestos = p_presupuestos;
  END IF;

  COMMIT;
END;

-- ---------------------------------------------------------------------
-- 4. Bloqueo de cuenta por deuda
--    Bloquea la compra, deja registro y genera la notificacion al cliente
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_bloquear_cliente;

CREATE PROCEDURE sp_bloquear_cliente(
  IN  p_clientes      INT UNSIGNED,
  IN  p_usuarios      INT UNSIGNED,
  IN  p_motivo        VARCHAR(255),
  IN  p_observacion   TEXT,
  IN  p_canal         VARCHAR(20),
  OUT p_id_bloqueo    BIGINT UNSIGNED,
  OUT p_id_notificacion BIGINT UNSIGNED
)
BEGIN
  DECLARE v_saldo   DECIMAL(15,2) DEFAULT 0;
  DECLARE v_dias    SMALLINT UNSIGNED DEFAULT 0;
  DECLARE v_email   VARCHAR(150);
  DECLARE v_nombre  VARCHAR(150);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT email, razon_social INTO v_email, v_nombre FROM clientes WHERE id_clientes = p_clientes;

  SELECT COALESCE(SUM(saldo), 0), COALESCE(MAX(dias_vencimiento), 0)
    INTO v_saldo, v_dias
    FROM clientes_deudas
   WHERE id_clientes = p_clientes AND estado = 'VENCIDO';

  INSERT INTO bloqueos_clientes (
    id_clientes, id_usuarios, monto_deuda, dias_vencimiento, motivo, observacion, estado
  ) VALUES (
    p_clientes, p_usuarios, v_saldo, v_dias, p_motivo, p_observacion, 'ACTIVO'
  );
  SET p_id_bloqueo = LAST_INSERT_ID();

  UPDATE clientes
     SET bloqueado_compra = 1,
         motivo_bloqueo   = p_motivo,
         bloqueado_por    = p_usuarios,
         bloqueado_en     = NOW(),
         saldo_deuda      = v_saldo
   WHERE id_clientes = p_clientes;

  INSERT INTO notificaciones (
    id_clientes, id_bloqueos_clientes, destinatario, canal, tipo, asunto, mensaje, estado
  ) VALUES (
    p_clientes, p_id_bloqueo, v_email, IFNULL(p_canal, 'EMAIL'), 'BLOQUEO_COMPRA',
    'Cuenta bloqueada por deuda',
    CONCAT('Estimado ', v_nombre, ': su cuenta fue bloqueada por una deuda de ', v_saldo, '. ', p_motivo),
    'PENDIENTE'
  );
  SET p_id_notificacion = LAST_INSERT_ID();

  UPDATE bloqueos_clientes SET id_notificaciones = p_id_notificacion WHERE id_bloqueos_clientes = p_id_bloqueo;

  COMMIT;
END;

-- ---------------------------------------------------------------------
-- 5. Cierre de reclamo con motivo (metrica de gestion)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cerrar_reclamo;

CREATE PROCEDURE sp_cerrar_reclamo(
  IN  p_reclamos        INT UNSIGNED,
  IN  p_usuarios       INT UNSIGNED,
  IN  p_estado_final   SMALLINT UNSIGNED,
  IN  p_motivo_cierre  SMALLINT UNSIGNED,
  IN  p_resolucion     TEXT,
  IN  p_comentario     VARCHAR(255)
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_motivo_cierre IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cierre de reclamo requiere un motivo';
  END IF;

  START TRANSACTION;

  UPDATE reclamos
     SET id_estados_reclamo   = p_estado_final,
         id_motivo_cierre     = p_motivo_cierre,
         fecha_cierre         = NOW(),
         id_usuarios_cierre   = p_usuarios,
         resolucion           = p_resolucion
   WHERE id_reclamos = p_reclamos;

  INSERT INTO reclamos_historial (id_reclamos, id_estados_reclamo, id_usuarios, comentario)
  VALUES (p_reclamos, p_estado_final, p_usuarios, p_comentario);

  COMMIT;
END;

-- ---------------------------------------------------------------------
-- 6. Autenticacion de usuario
--    Valida clave + rol -> concede o deniega el acceso a los modulos
--    p_password_hash: hash calculado por la aplicacion (mismo algoritmo del alta)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_autenticar_usuario;

CREATE PROCEDURE sp_autenticar_usuario(
  IN  p_usuario        VARCHAR(150),
  IN  p_password_hash  VARCHAR(255),
  IN  p_ip             VARCHAR(45),
  IN  p_user_agent     VARCHAR(255),
  OUT p_id_usuarios    INT UNSIGNED,
  OUT p_id_roles       INT UNSIGNED,
  OUT p_acceso         TINYINT(1),
  OUT p_motivo         VARCHAR(40)
)
BEGIN
  DECLARE v_password  VARCHAR(255);
  DECLARE v_activo    TINYINT(1) DEFAULT 0;
  DECLARE v_eliminado TINYINT(1) DEFAULT 0;
  DECLARE v_bloqueado TINYINT(1) DEFAULT 0;
  DECLARE v_bloqueo_hasta DATETIME;
  DECLARE v_rol       INT UNSIGNED DEFAULT NULL;

  SET p_id_usuarios = NULL;
  SET p_id_roles    = NULL;
  SET p_acceso      = 0;
  SET p_motivo      = 'CREDENCIALES_INVALIDAS';

  SELECT id_usuarios, password_hash, activo, eliminado, bloqueado_hasta
    INTO p_id_usuarios, v_password, v_activo, v_eliminado, v_bloqueo_hasta
    FROM usuarios
   WHERE usuario = p_usuario OR email = p_usuario
   LIMIT 1;

  IF p_id_usuarios IS NULL THEN
    INSERT INTO intentos_autenticacion (usuario_intento, exito, motivo, ip, user_agent)
    VALUES (p_usuario, 0, 'CREDENCIALES_INVALIDAS', p_ip, p_user_agent);
    SET p_motivo = 'CREDENCIALES_INVALIDAS';
    SET p_id_usuarios = NULL;
  ELSEIF v_eliminado = 1 THEN
    INSERT INTO intentos_autenticacion (id_usuarios, usuario_intento, exito, motivo, ip, user_agent)
    VALUES (p_id_usuarios, p_usuario, 0, 'CUENTA_ELIMINADA', p_ip, p_user_agent);
    SET p_motivo = 'CUENTA_ELIMINADA';
  ELSEIF v_activo = 0 THEN
    INSERT INTO intentos_autenticacion (id_usuarios, usuario_intento, exito, motivo, ip, user_agent)
    VALUES (p_id_usuarios, p_usuario, 0, 'USUARIO_INACTIVO', p_ip, p_user_agent);
    SET p_motivo = 'USUARIO_INACTIVO';
  ELSEIF v_bloqueo_hasta IS NOT NULL AND v_bloqueo_hasta > NOW() THEN
    INSERT INTO intentos_autenticacion (id_usuarios, usuario_intento, exito, motivo, ip, user_agent)
    VALUES (p_id_usuarios, p_usuario, 0, 'USUARIO_BLOQUEADO', p_ip, p_user_agent);
    SET p_motivo = 'USUARIO_BLOQUEADO';
  ELSEIF v_password <> p_password_hash THEN
    UPDATE usuarios SET intentos_fallidos = intentos_fallidos + 1 WHERE id_usuarios = p_id_usuarios;
    INSERT INTO intentos_autenticacion (id_usuarios, usuario_intento, exito, motivo, ip, user_agent)
    VALUES (p_id_usuarios, p_usuario, 0, 'CREDENCIALES_INVALIDAS', p_ip, p_user_agent);
    SET p_motivo = 'CREDENCIALES_INVALIDAS';
  ELSE
    -- Credenciales correctas: se busca un rol con permisos habilitados.
    SELECT ur.id_roles INTO v_rol
      FROM usuarios_roles ur
      INNER JOIN roles r ON r.id_roles = ur.id_roles AND r.activo = 1
     WHERE ur.id_usuarios = p_id_usuarios
     LIMIT 1;

    IF v_rol IS NULL THEN
      INSERT INTO intentos_autenticacion (id_usuarios, usuario_intento, exito, motivo, ip, user_agent)
      VALUES (p_id_usuarios, p_usuario, 0, 'ROL_SIN_ACCESO', p_ip, p_user_agent);
      SET p_motivo = 'ROL_SIN_ACCESO';
    ELSE
      SET p_id_roles = v_rol;
      SET p_acceso  = 1;
      SET p_motivo  = 'OK';

      UPDATE usuarios
         SET intentos_fallidos = 0, ultimo_acceso = NOW() WHERE id_usuarios = p_id_usuarios;

      INSERT INTO intentos_autenticacion (id_usuarios, usuario_intento, exito, motivo, id_roles_resuelto, ip, user_agent)
      VALUES (p_id_usuarios, p_usuario, 1, 'OK', v_rol, p_ip, p_user_agent);
    END IF;
  END IF;
END;

-- ---------------------------------------------------------------------
-- 7. Eliminacion de usuario (baja logica)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_eliminar_usuario;

CREATE PROCEDURE sp_eliminar_usuario(
  IN  p_usuarios    INT UNSIGNED,
  IN  p_usuario_actor INT UNSIGNED,
  IN  p_motivo      VARCHAR(255)
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  UPDATE usuarios
     SET eliminado      = 1,
         eliminado_en   = NOW(),
         eliminado_por  = p_usuario_actor,
         activo         = 0,
         bloqueado_hasta= NOW()
   WHERE id_usuarios = p_usuarios;

  UPDATE sesiones
     SET activo = 0, cierre_sesion = NOW(), motivo_cierre = 'ADMIN'
   WHERE id_usuarios = p_usuarios AND activo = 1;

  DELETE FROM tokens_recuperacion WHERE id_usuarios = p_usuarios AND usado = 0;

  INSERT INTO auditoria (id_usuarios, modulo, entidad, id_entidad, operacion, descripcion)
  VALUES (p_usuario_actor, 'USUARIOS', 'usuarios', p_usuarios, 'DELETE', IFNULL(p_motivo, 'Eliminacion de usuario'));

  COMMIT;
END;

-- ---------------------------------------------------------------------
-- 8. Alta de cliente desde prospecto (registro de cliente)
--    Reutiliza los datos del prospecto y deja la trazabilidad del origen
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_cliente;

CREATE PROCEDURE sp_registrar_cliente(
  IN  p_prospectos        INT UNSIGNED,
  IN  p_usuarios          INT UNSIGNED,
  IN  p_listas_precios    INT UNSIGNED,
  IN  p_condicion_comercial INT UNSIGNED,
  IN  p_zonas             SMALLINT UNSIGNED,
  IN  p_vendedores        INT UNSIGNED,
  IN  p_comision_pct      DECIMAL(5,2),
  OUT p_id_clientes       INT UNSIGNED
)
BEGIN
  DECLARE v_codigo VARCHAR(20);
  DECLARE v_existe INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT COUNT(*) INTO v_existe FROM prospectos WHERE id_prospectos = p_prospectos;
  IF v_existe = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El prospecto indicado no existe';
  END IF;

  -- Se valida si el cliente ya existe (validacion de duplicados por documento).
  SELECT COUNT(*) INTO v_existe
    FROM clientes
   WHERE tipo_documento = (SELECT tipo_documento FROM prospectos WHERE id_prospectos = p_prospectos)
     AND nro_documento  = (SELECT nro_documento  FROM prospectos WHERE id_prospectos = p_prospectos);
  IF v_existe > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente ya existe con el mismo documento';
  END IF;

  SELECT CONCAT('CLI-', DATE_FORMAT(NOW(), '%Y%m%d'), '-',
                LPAD((SELECT COUNT(*) + 1 FROM clientes), 5, '0'))
    INTO v_codigo;

  INSERT INTO clientes (
    codigo, tipo_cliente, razon_social, nombre_fantasia, tipo_documento, nro_documento,
    email, telefono, ciudad, provincia, origen, estado, fecha_alta, id_usuarios_alta,
    id_listas_precios, id_condicion_comercial
  )
  SELECT
    v_codigo, 'JURIDICA', pr.razon_social, pr.nombre_fantasia, pr.tipo_documento, pr.nro_documento,
    pr.email, pr.telefono, pr.ciudad, pr.provincia, 'PROSPECTO_COTIZACION', 'ACTIVO', NOW(), p_usuarios,
    p_listas_precios, p_condicion_comercial
  FROM prospectos pr
  WHERE pr.id_prospectos = p_prospectos;

  SET p_id_clientes = LAST_INSERT_ID();

  UPDATE prospectos
     SET estado = 'CONVERTIDO', id_clientes = p_id_clientes, fecha_conversion = NOW()
   WHERE id_prospectos = p_prospectos;

  IF p_listas_precios IS NOT NULL THEN
    INSERT INTO clientes_listas_precios (id_clientes, id_listas_precios, fecha_desde, es_principal)
    VALUES (p_id_clientes, p_listas_precios, CURDATE(), 1);
  END IF;

  IF p_condicion_comercial IS NOT NULL THEN
    INSERT INTO clientes_condiciones_comerciales (id_clientes, id_condicion_comercial, fecha_desde)
    VALUES (p_id_clientes, p_condicion_comercial, CURDATE());
  END IF;

  IF p_zonas IS NOT NULL OR p_vendedores IS NOT NULL THEN
    INSERT INTO asignaciones_clientes (
      id_clientes, id_zonas, id_vendedores, tipo_asignacion, fecha_desde,
      comision_pct, id_usuarios_asignacion
    ) VALUES (
      p_id_clientes, p_zonas, p_vendedores,
      IF(p_vendedores IS NULL, 'ZONA', 'VENDEDOR'), CURDATE(),
      IFNULL(p_comision_pct, 0), p_usuarios
    );
  END IF;

  COMMIT;
END;
