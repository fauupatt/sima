-- =====================================================================
-- SIMA  |  Modulos Gestion de Inventario, Gestion de Compras y Gestion de Ventas
--   Inventario: control de stock (ROP/RP), movimientos, ingreso, salida, ajuste
--   Compras:    proveedor -> productos -> registrar compra -> actualizar stock
--   Ventas:     presupuesto -> confirmacion -> venta -> descontar stock -> comprobante
-- =====================================================================

USE sima;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- GESTION DE INVENTARIO - CONTROL DE STOCK
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS inventario_stock (
  id_inventario_stock   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_almacenes          SMALLINT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  id_lotes              INT UNSIGNED NULL,
  lote_key              INT UNSIGNED AS (IFNULL(id_lotes, 0)) STORED,
  cantidad              DECIMAL(15,3) NOT NULL DEFAULT 0,
  cantidad_reservada    DECIMAL(15,3) NOT NULL DEFAULT 0,
  costo_promedio        DECIMAL(15,4) NOT NULL DEFAULT 0,
  valorizacion          DECIMAL(15,2) NOT NULL DEFAULT 0,
  stock_minimo          DECIMAL(15,3) NOT NULL DEFAULT 0,
  rop                   DECIMAL(15,3) NULL COMMENT 'Punto de reposicion',
  rp                    DECIMAL(15,3) NULL COMMENT 'Cantidad a reponer',
  ultimo_movimiento     DATETIME NULL,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_stock (id_almacenes, id_productos, lote_key),
  KEY ix_stock_producto (id_productos),
  KEY ix_stock_almacen (id_almacenes),
  CONSTRAINT fk_stock_almacen FOREIGN KEY (id_almacenes)
    REFERENCES almacenes (id_almacenes),
  CONSTRAINT fk_stock_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_stock_lote FOREIGN KEY (id_lotes)
    REFERENCES lotes (id_lotes) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Movimientos de inventario: entradas / salidas / ajustes.
CREATE TABLE IF NOT EXISTS inventario_movimientos (
  id_inventario_movimientos BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tipo_movimiento         ENUM('ENTRADA','SALIDA','AJUSTE','TRANSFERENCIA','DEVOLUCION','MERMA')
                           NOT NULL,
  id_productos            INT UNSIGNED NOT NULL,
  id_lotes                INT UNSIGNED NULL,
  id_almacenes            SMALLINT UNSIGNED NOT NULL,
  id_almacenes_destino    SMALLINT UNSIGNED NULL,
  cantidad                DECIMAL(15,3) NOT NULL,
  cantidad_previa         DECIMAL(15,3) NULL,
  cantidad_posterior       DECIMAL(15,3) NULL,
  costo_unitario          DECIMAL(15,4) NULL,
  id_usuarios             INT UNSIGNED NOT NULL,
  -- Trazabilidad del documento origen
  documento_tipo          VARCHAR(40) NULL COMMENT 'COMPRA, VENTA, AJUSTE, DEVOLUCION, REPOSICION',
  documento_id            INT UNSIGNED NULL,
  documento_numero        VARCHAR(40) NULL,
  motivo                  VARCHAR(255) NULL COMMENT 'Motivo del ajuste',
  observacion             TEXT NULL,
  fecha_movimiento        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_movimientos_producto (id_productos, fecha_movimiento),
  KEY ix_movimientos_tipo (tipo_movimiento, fecha_movimiento),
  KEY ix_movimientos_documento (documento_tipo, documento_id),
  CONSTRAINT fk_movimientos_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_movimientos_lote FOREIGN KEY (id_lotes)
    REFERENCES lotes (id_lotes) ON DELETE SET NULL,
  CONSTRAINT fk_movimientos_almacen FOREIGN KEY (id_almacenes)
    REFERENCES almacenes (id_almacenes),
  CONSTRAINT fk_movimientos_almacen_destino FOREIGN KEY (id_almacenes_destino)
    REFERENCES almacenes (id_almacenes) ON DELETE SET NULL,
  CONSTRAINT fk_movimientos_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios)
) ENGINE=InnoDB;

-- Politica de reposicion por producto/almacen (stock minimo, ROP, RP).
CREATE TABLE IF NOT EXISTS inventario_politicas (
  id_inventario_politicas INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_productos          INT UNSIGNED NOT NULL,
  id_almacenes          SMALLINT UNSIGNED NOT NULL,
  id_proveedores        INT UNSIGNED NULL,
  stock_minimo          DECIMAL(15,3) NOT NULL DEFAULT 0,
  stock_maximo          DECIMAL(15,3) NULL,
  rop                   DECIMAL(15,3) NOT NULL DEFAULT 0,
  rp                    DECIMAL(15,3) NOT NULL DEFAULT 0,
  cantidad_pedido       DECIMAL(15,3) NULL COMMENT 'Cantidad fija sugerida; si es NULL se usa RP',
  periodo_revision_dias SMALLINT UNSIGNED NOT NULL DEFAULT 7,
  ultima_revision       DATE NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_politicas (id_productos, id_almacenes),
  CONSTRAINT fk_politicas_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos) ON DELETE CASCADE,
  CONSTRAINT fk_politicas_almacen FOREIGN KEY (id_almacenes)
    REFERENCES almacenes (id_almacenes),
  CONSTRAINT fk_politicas_proveedor FOREIGN KEY (id_proveedores)
    REFERENCES proveedores (id_proveedores) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Reposicion: stock <= ROP -> se genera reposicion por RP.
CREATE TABLE IF NOT EXISTS reposiciones (
  id_reposiciones       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(30) NOT NULL,
  id_proveedores        INT UNSIGNED NULL,
  id_usuarios           INT UNSIGNED NULL,
  estado                ENUM('GENERADA','APROBADA','ENVIADA','CONVERTIDA_EN_COMPRA','CANCELADA')
                          NOT NULL DEFAULT 'GENERADA',
  fecha_generacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_aprobacion      DATETIME NULL,
  id_usuarios_aprobacion INT UNSIGNED NULL,
  fecha_conversion      DATETIME NULL,
  id_compras            INT UNSIGNED NULL,
  observaciones         TEXT NULL,
  UNIQUE KEY uq_reposiciones_codigo (codigo),
  KEY ix_reposiciones_estado (estado, fecha_generacion),
  CONSTRAINT fk_reposiciones_proveedor FOREIGN KEY (id_proveedores)
    REFERENCES proveedores (id_proveedores) ON DELETE SET NULL,
  CONSTRAINT fk_reposiciones_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_reposiciones_aprobacion_por FOREIGN KEY (id_usuarios_aprobacion)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reposiciones_detalle (
  id_reposiciones_detalle INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reposiciones       INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  id_almacenes          SMALLINT UNSIGNED NOT NULL,
  stock_actual          DECIMAL(15,3) NOT NULL DEFAULT 0,
  rop                   DECIMAL(15,3) NOT NULL DEFAULT 0,
  rp                    DECIMAL(15,3) NOT NULL DEFAULT 0,
  cantidad_sugerida      DECIMAL(15,3) NOT NULL DEFAULT 0,
  costo_unitario        DECIMAL(15,4) NULL,
  PRIMARY KEY (id_reposiciones, id_productos, id_almacenes),
  CONSTRAINT fk_reposiciones_detalle_reposicion FOREIGN KEY (id_reposiciones)
    REFERENCES reposiciones (id_reposiciones) ON DELETE CASCADE,
  CONSTRAINT fk_reposiciones_detalle_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_reposiciones_detalle_almacen FOREIGN KEY (id_almacenes)
    REFERENCES almacenes (id_almacenes)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- GESTION DE COMPRAS
--   Seleccionar proveedor -> seleccionar productos -> registrar compra -> actualizar stock
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS estados_compra (
  id_estados_compra     SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(30) NOT NULL,
  nombre                VARCHAR(60) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  orden                 SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  es_final              TINYINT(1) NOT NULL DEFAULT 0,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_estados_compra (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compras (
  id_compras            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero                VARCHAR(30) NOT NULL,
  id_proveedores        INT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  id_estados_compra     SMALLINT UNSIGNED NOT NULL,
  id_almacenes_destino  SMALLINT UNSIGNED NULL,
  fecha_emision         DATE NOT NULL,
  fecha_recepcion       DATE NULL,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  descuento             DECIMAL(15,2) NOT NULL DEFAULT 0,
  impuestos             DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  forma_pago            ENUM('CONTADO','CREDITO','TRANSFERENCIA','CHEQUE','TARJETA','OTRO')
                          NOT NULL DEFAULT 'CONTADO',
  plazo_pago_dias       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  observaciones         TEXT NULL,
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_compras_numero (numero),
  KEY ix_compras_proveedor (id_proveedores, fecha_emision),
  KEY ix_compras_estado (id_estados_compra),
  CONSTRAINT fk_compras_proveedor FOREIGN KEY (id_proveedores)
    REFERENCES proveedores (id_proveedores),
  CONSTRAINT fk_compras_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_compras_estado FOREIGN KEY (id_estados_compra)
    REFERENCES estados_compra (id_estados_compra),
  CONSTRAINT fk_compras_almacen FOREIGN KEY (id_almacenes_destino)
    REFERENCES almacenes (id_almacenes) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compras_items (
  id_compras_items      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_compras            INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  descripcion           VARCHAR(200) NULL,
  cantidad              DECIMAL(15,3) NOT NULL DEFAULT 0,
  cantidad_recibida     DECIMAL(15,3) NOT NULL DEFAULT 0,
  id_unidades_medida    TINYINT UNSIGNED NULL,
  costo_unitario        DECIMAL(15,4) NOT NULL DEFAULT 0,
  descuento_pct         DECIMAL(5,2) NOT NULL DEFAULT 0,
  descuento_monto       DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  KEY ix_compras_items (id_compras),
  KEY ix_compras_items_producto (id_productos),
  CONSTRAINT fk_compras_items_compra FOREIGN KEY (id_compras)
    REFERENCES compras (id_compras) ON DELETE CASCADE,
  CONSTRAINT fk_compras_items_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_compras_items_unidad FOREIGN KEY (id_unidades_medida)
    REFERENCES unidades_medida (id_unidades_medida) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Ingreso de stock por recepcion de compra (verificar productos -> ingresar mercaderia).
CREATE TABLE IF NOT EXISTS recepciones_compra (
  id_recepciones_compra BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_compras            INT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  id_almacenes          SMALLINT UNSIGNED NOT NULL,
  fecha_recepcion       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tipo                  ENUM('TOTAL','PARCIAL') NOT NULL DEFAULT 'TOTAL',
  observaciones         TEXT NULL,
  KEY ix_recepciones_compra (id_compras),
  CONSTRAINT fk_recepciones_compra_compra FOREIGN KEY (id_compras)
    REFERENCES compras (id_compras) ON DELETE CASCADE,
  CONSTRAINT fk_recepciones_compra_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_recepciones_compra_almacen FOREIGN KEY (id_almacenes)
    REFERENCES almacenes (id_almacenes)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recepciones_items (
  id_recepciones_items  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_recepciones_compra BIGINT UNSIGNED NOT NULL,
  id_compras_items      BIGINT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  id_lotes              INT UNSIGNED NULL,
  cantidad_recibida     DECIMAL(15,3) NOT NULL DEFAULT 0,
  cantidad_rechazada    DECIMAL(15,3) NOT NULL DEFAULT 0,
  motivo_rechazo        VARCHAR(255) NULL,
  lote_codigo           VARCHAR(60) NULL,
  fecha_vencimiento     DATE NULL,
  KEY ix_recepciones_items (id_recepciones_compra),
  CONSTRAINT fk_recepciones_items_recepcion FOREIGN KEY (id_recepciones_compra)
    REFERENCES recepciones_compra (id_recepciones_compra) ON DELETE CASCADE,
  CONSTRAINT fk_recepciones_items_item_compra FOREIGN KEY (id_compras_items)
    REFERENCES compras_items (id_compras_items),
  CONSTRAINT fk_recepciones_items_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_recepciones_items_lote FOREIGN KEY (id_lotes)
    REFERENCES lotes (id_lotes) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- GESTION DE VENTAS
--   Cliente solicita producto -> verificar stock -> generacion de presupuesto
--   -> confirmacion -> registrar venta -> descontar stock -> generar comprobante
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS estados_venta (
  id_estados_venta      SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(30) NOT NULL,
  nombre                VARCHAR(60) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  orden                 SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  es_final              TINYINT(1) NOT NULL DEFAULT 0,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_estados_venta (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS presupuestos (
  id_presupuestos       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero                VARCHAR(30) NOT NULL,
  id_clientes           INT UNSIGNED NOT NULL,
  id_cotizaciones       INT UNSIGNED NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  id_listas_precios     INT UNSIGNED NULL,
  id_condicion_comercial INT UNSIGNED NULL,
  id_vendedores         INT UNSIGNED NULL,
  fecha_emision         DATE NOT NULL,
  fecha_validez         DATE NULL,
  fecha_confirmacion    DATE NULL,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  descuento             DECIMAL(15,2) NOT NULL DEFAULT 0,
  recargo               DECIMAL(15,2) NOT NULL DEFAULT 0,
  impuestos             DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  estado                ENUM('BORRADOR','ENVIADO','CONFIRMADO','RECHAZADO','VENCIDO','CONVERTIDO_EN_VENTA')
                          NOT NULL DEFAULT 'BORRADOR',
  observaciones         TEXT NULL,
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_presupuestos_numero (numero),
  KEY ix_presupuestos_cliente (id_clientes, fecha_emision),
  KEY ix_presupuestos_estado (estado, fecha_emision),
  CONSTRAINT fk_presupuestos_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_presupuestos_cotizacion FOREIGN KEY (id_cotizaciones)
    REFERENCES cotizaciones (id_cotizaciones) ON DELETE SET NULL,
  CONSTRAINT fk_presupuestos_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_presupuestos_lista FOREIGN KEY (id_listas_precios)
    REFERENCES listas_precios (id_listas_precios) ON DELETE SET NULL,
  CONSTRAINT fk_presupuestos_condicion FOREIGN KEY (id_condicion_comercial)
    REFERENCES condiciones_comerciales (id_condiciones_comerciales) ON DELETE SET NULL,
  CONSTRAINT fk_presupuestos_vendedor FOREIGN KEY (id_vendedores)
    REFERENCES vendedores (id_vendedores) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS presupuestos_items (
  id_presupuestos_items BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_presupuestos       INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  descripcion           VARCHAR(200) NULL,
  cantidad              DECIMAL(15,3) NOT NULL DEFAULT 1,
  id_unidades_medida    TINYINT UNSIGNED NULL,
  precio_unitario       DECIMAL(15,4) NOT NULL DEFAULT 0,
  descuento_pct         DECIMAL(5,2) NOT NULL DEFAULT 0,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  KEY ix_presupuestos_items (id_presupuestos),
  CONSTRAINT fk_presupuestos_items_presupuesto FOREIGN KEY (id_presupuestos)
    REFERENCES presupuestos (id_presupuestos) ON DELETE CASCADE,
  CONSTRAINT fk_presupuestos_items_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_presupuestos_items_unidad FOREIGN KEY (id_unidades_medida)
    REFERENCES unidades_medida (id_unidades_medida) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ventas (
  id_ventas             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero                VARCHAR(30) NOT NULL,
  id_clientes           INT UNSIGNED NOT NULL,
  id_presupuestos       INT UNSIGNED NULL,
  id_cotizaciones       INT UNSIGNED NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  id_vendedores         INT UNSIGNED NULL,
  id_listas_precios     INT UNSIGNED NULL,
  id_condicion_comercial INT UNSIGNED NULL,
  id_almacenes_origen   SMALLINT UNSIGNED NULL,
  id_estados_venta      SMALLINT UNSIGNED NOT NULL,
  fecha_venta           DATE NOT NULL,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  descuento             DECIMAL(15,2) NOT NULL DEFAULT 0,
  recargo               DECIMAL(15,2) NOT NULL DEFAULT 0,
  impuestos             DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  forma_pago            ENUM('CONTADO','CREDITO','TRANSFERENCIA','CHEQUE','TARJETA','OTRO')
                          NOT NULL DEFAULT 'CONTADO',
  observaciones         TEXT NULL,
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ventas_numero (numero),
  KEY ix_ventas_cliente (id_clientes, fecha_venta),
  KEY ix_ventas_fecha (fecha_venta),
  KEY ix_ventas_estado (id_estados_venta),
  CONSTRAINT fk_ventas_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes),
  CONSTRAINT fk_ventas_presupuesto FOREIGN KEY (id_presupuestos)
    REFERENCES presupuestos (id_presupuestos) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_cotizacion FOREIGN KEY (id_cotizaciones)
    REFERENCES cotizaciones (id_cotizaciones) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_ventas_vendedor FOREIGN KEY (id_vendedores)
    REFERENCES vendedores (id_vendedores) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_lista FOREIGN KEY (id_listas_precios)
    REFERENCES listas_precios (id_listas_precios) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_condicion FOREIGN KEY (id_condicion_comercial)
    REFERENCES condiciones_comerciales (id_condiciones_comerciales) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_almacen FOREIGN KEY (id_almacenes_origen)
    REFERENCES almacenes (id_almacenes) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_estado FOREIGN KEY (id_estados_venta)
    REFERENCES estados_venta (id_estados_venta)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ventas_items (
  id_ventas_items       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_ventas             INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  id_lotes              INT UNSIGNED NULL,
  descripcion           VARCHAR(200) NULL,
  cantidad              DECIMAL(15,3) NOT NULL DEFAULT 0,
  id_unidades_medida    TINYINT UNSIGNED NULL,
  precio_unitario       DECIMAL(15,4) NOT NULL DEFAULT 0,
  descuento_pct         DECIMAL(5,2) NOT NULL DEFAULT 0,
  recargo_pct           DECIMAL(5,2) NOT NULL DEFAULT 0,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  KEY ix_ventas_items (id_ventas),
  KEY ix_ventas_items_producto (id_productos),
  CONSTRAINT fk_ventas_items_venta FOREIGN KEY (id_ventas)
    REFERENCES ventas (id_ventas) ON DELETE CASCADE,
  CONSTRAINT fk_ventas_items_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_ventas_items_lote FOREIGN KEY (id_lotes)
    REFERENCES lotes (id_lotes) ON DELETE SET NULL,
  CONSTRAINT fk_ventas_items_unidad FOREIGN KEY (id_unidades_medida)
    REFERENCES unidades_medida (id_unidades_medida) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Comprobante generado al registrar la venta.
CREATE TABLE IF NOT EXISTS comprobantes (
  id_comprobantes       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tipo                  ENUM('FACTURA','PRESUPUESTO','REMITO','NOTA_CREDITO','RECIBO','COMPROBANTE_VENTA')
                          NOT NULL DEFAULT 'COMPROBANTE_VENTA',
  serie                 VARCHAR(10) NULL,
  numero                VARCHAR(30) NOT NULL,
  id_ventas             INT UNSIGNED NULL,
  id_presupuestos       INT UNSIGNED NULL,
  id_clientes           INT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  fecha_emision         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  impuestos             DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  archivo_path          VARCHAR(500) NULL,
  hash_documento        VARCHAR(100) NULL,
  estado                ENUM('GENERADO','ENVIADO','ANULADO') NOT NULL DEFAULT 'GENERADO',
  UNIQUE KEY uq_comprobantes (tipo, serie, numero),
  KEY ix_comprobantes_venta (id_ventas),
  CONSTRAINT fk_comprobantes_venta FOREIGN KEY (id_ventas)
    REFERENCES ventas (id_ventas) ON DELETE SET NULL,
  CONSTRAINT fk_comprobantes_presupuesto FOREIGN KEY (id_presupuestos)
    REFERENCES presupuestos (id_presupuestos) ON DELETE SET NULL,
  CONSTRAINT fk_comprobantes_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes),
  CONSTRAINT fk_comprobantes_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- COMISIONES (calculadas a partir de la venta y la asignacion del cliente)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS comisiones (
  id_comisiones          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_asignaciones_clientes INT UNSIGNED NULL,
  id_vendedores         INT UNSIGNED NOT NULL,
  id_clientes           INT UNSIGNED NOT NULL,
  id_ventas             INT UNSIGNED NULL,
  tipo                  ENUM('VENTA','COBRANZA','METRICA','BONO') NOT NULL DEFAULT 'VENTA',
  base                  DECIMAL(15,2) NOT NULL DEFAULT 0,
  porcentaje            DECIMAL(5,2) NOT NULL DEFAULT 0,
  monto                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  periodo               DATE NULL,
  estado                ENUM('CALCULADA','APROBADA','PAGADA','ANULADA') NOT NULL DEFAULT 'CALCULADA',
  id_usuarios_calculo   INT UNSIGNED NULL,
  id_usuarios_aprobacion INT UNSIGNED NULL,
  fecha_calculo         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_comisiones_venta (id_ventas, id_vendedores, tipo),
  KEY ix_comisiones_vendedor (id_vendedores, periodo),
  CONSTRAINT fk_comisiones_asignacion FOREIGN KEY (id_asignaciones_clientes)
    REFERENCES asignaciones_clientes (id_asignaciones_clientes) ON DELETE SET NULL,
  CONSTRAINT fk_comisiones_vendedor FOREIGN KEY (id_vendedores)
    REFERENCES vendedores (id_vendedores),
  CONSTRAINT fk_comisiones_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes),
  CONSTRAINT fk_comisiones_venta FOREIGN KEY (id_ventas)
    REFERENCES ventas (id_ventas) ON DELETE SET NULL,
  CONSTRAINT fk_comisiones_usuario_calculo FOREIGN KEY (id_usuarios_calculo)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_comisiones_usuario_aprobacion FOREIGN KEY (id_usuarios_aprobacion)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- CLAUSULAS CRUZADAS (referencias entre modulos)
-- ---------------------------------------------------------------------

ALTER TABLE cotizaciones
  DROP FOREIGN KEY IF EXISTS fk_cotizaciones_venta,
  ADD CONSTRAINT fk_cotizaciones_venta FOREIGN KEY (id_ventas)
    REFERENCES ventas (id_ventas) ON DELETE SET NULL;

ALTER TABLE reclamos
  DROP FOREIGN KEY IF EXISTS fk_reclamos_venta,
  DROP FOREIGN KEY IF EXISTS fk_reclamos_cotizacion,
  ADD CONSTRAINT fk_reclamos_venta FOREIGN KEY (id_ventas)
    REFERENCES ventas (id_ventas) ON DELETE SET NULL,
  ADD CONSTRAINT fk_reclamos_cotizacion FOREIGN KEY (id_cotizaciones)
    REFERENCES cotizaciones (id_cotizaciones) ON DELETE SET NULL;

ALTER TABLE reposiciones
  DROP FOREIGN KEY IF EXISTS fk_reposiciones_compra,
  ADD CONSTRAINT fk_reposiciones_compra FOREIGN KEY (id_compras)
    REFERENCES compras (id_compras) ON DELETE SET NULL;

SET FOREIGN_KEY_CHECKS = 1;
