-- =====================================================================
-- SIMA  |  Catalogo maestro
-- Módulos: Gestión de Proveedores | Gestión de Productos | Gestión de Clientes (base)
-- =====================================================================

USE sima;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- GESTION DE PROVEEDORES
--   Alta de proveedor -> Carga de datos -> Validacion -> Proveedor registrado
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS proveedores (
  id_proveedores        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  razon_social          VARCHAR(150) NOT NULL,
  nombre_fantasia       VARCHAR(150) NULL,
  cuit                  VARCHAR(13)  NULL,
  tipo_documento        ENUM('CUIT','CUIL','DNI','OTRO') NOT NULL DEFAULT 'CUIT',
  nro_documento         VARCHAR(30)  NULL,
  email                 VARCHAR(150) NULL,
  telefono              VARCHAR(30)  NULL,
  direccion             VARCHAR(200) NULL,
  ciudad                VARCHAR(100) NULL,
  provincia             VARCHAR(100) NULL,
  codigo_postal         VARCHAR(20)  NULL,
  pais                  VARCHAR(60)  NOT NULL DEFAULT 'Argentina',
  contacto_nombre       VARCHAR(150) NULL,
  contacto_email        VARCHAR(150) NULL,
  contacto_telefono     VARCHAR(30)  NULL,
  plazo_entrega_dias    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  condiciones_pago      VARCHAR(100) NULL,
  banco                 VARCHAR(120) NULL,
  cuenta_bancaria       VARCHAR(60)  NULL,
  -- Estado del proceso de alta
  estado                ENUM('ALTA','EN_VALIDACION','VALIDADO','RECHAZADO','SUSPENDIDO','INACTIVO')
                          NOT NULL DEFAULT 'ALTA',
  validado_por          INT UNSIGNED NULL,
  validado_en           DATETIME NULL,
  motivo_rechazo        VARCHAR(255) NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  fecha_alta            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_baja            DATETIME NULL,
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_proveedores_codigo (codigo),
  UNIQUE KEY uq_proveedores_cuit (cuit),
  KEY ix_proveedores_estado (estado),
  KEY ix_proveedores_razon (razon_social),
  CONSTRAINT fk_proveedores_validado_por FOREIGN KEY (validado_por)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Historial del proceso de alta/validacion del proveedor.
CREATE TABLE IF NOT EXISTS proveedores_estados (
  id_proveedores_estados BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_proveedores        INT UNSIGNED NOT NULL,
  estado_anterior       VARCHAR(30) NULL,
  estado_nuevo          VARCHAR(30) NOT NULL,
  id_usuarios           INT UNSIGNED NULL,
  comentario            VARCHAR(255) NULL,
  fecha                 DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_proveedores_estados (id_proveedores, fecha),
  CONSTRAINT fk_proveedores_estados_prov FOREIGN KEY (id_proveedores)
    REFERENCES proveedores (id_proveedores) ON DELETE CASCADE,
  CONSTRAINT fk_proveedores_estados_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- GESTION DE PRODUCTOS
--   Alta: carga de datos (sku, cantidad, lt, ...) -> validacion -> producto registrado
--   Modificacion: seleccionar -> modificar -> validar -> actualizar
--   Baja: seleccionar -> verificar uso/stock -> dar de baja
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS productos (
  id_productos          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku                   VARCHAR(50)  NOT NULL,
  codigo_barras         VARCHAR(50)  NULL,
  nombre                VARCHAR(200) NOT NULL,
  descripcion           TEXT NULL,
  id_categorias         SMALLINT UNSIGNED NULL,
  id_unidades_medida    TINYINT UNSIGNED NOT NULL,
  -- Datos de la ficha (alta)
  cantidad_inicial      DECIMAL(15,3) NOT NULL DEFAULT 0,
  lt_dias               SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Lead time / plazo de entrega en dias',
  vida_util_dias        SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Vida util desde el ingreso',
  precio_venta          DECIMAL(15,4) NOT NULL DEFAULT 0,
  precio_costo          DECIMAL(15,4) NOT NULL DEFAULT 0,
  tasa_iva              DECIMAL(5,2)  NOT NULL DEFAULT 0,
  moneda                CHAR(3)      NOT NULL DEFAULT 'ARS',
  -- Politica de inventario (ROP / RP / stock minimo)
  stock_minimo          DECIMAL(15,3) NOT NULL DEFAULT 0,
  stock_maximo          DECIMAL(15,3) NULL,
  rop                   DECIMAL(15,3) NULL COMMENT 'Reorder point: punto de reposicion',
  rp                    DECIMAL(15,3) NULL COMMENT 'Reorder quantity: cantidad a reponer',
  id_proveedor_habitual INT UNSIGNED NULL,
  id_almacen_default    INT UNSIGNED NULL,
  -- Trazabilidad
  exige_lote            TINYINT(1)   NOT NULL DEFAULT 0,
  es_perecedero         TINYINT(1)   NOT NULL DEFAULT 0,
  controlado_por_serie  TINYINT(1)   NOT NULL DEFAULT 0,
  -- Estado
  activo                TINYINT(1)   NOT NULL DEFAULT 1,
  dado_de_baja          TINYINT(1)   NOT NULL DEFAULT 0,
  fecha_baja            DATETIME NULL,
  motivo_baja           VARCHAR(255) NULL,
  baja_por              INT UNSIGNED NULL,
  stock_en_baja         DECIMAL(15,3) NOT NULL DEFAULT 0 COMMENT 'Snapshot del stock al dar de baja',
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_productos_sku (sku),
  KEY ix_productos_categoria (id_categorias),
  KEY ix_productos_nombre (nombre),
  KEY ix_productos_estado (activo, dado_de_baja),
  CONSTRAINT fk_productos_categoria FOREIGN KEY (id_categorias)
    REFERENCES categorias (id_categorias) ON DELETE SET NULL,
  CONSTRAINT fk_productos_unidad FOREIGN KEY (id_unidades_medida)
    REFERENCES unidades_medida (id_unidades_medida),
  CONSTRAINT fk_productos_proveedor FOREIGN KEY (id_proveedor_habitual)
    REFERENCES proveedores (id_proveedores) ON DELETE SET NULL,
  CONSTRAINT fk_productos_almacen FOREIGN KEY (id_almacen_default)
    REFERENCES almacenes (id_almacenes) ON DELETE SET NULL,
  CONSTRAINT fk_productos_baja_por FOREIGN KEY (baja_por)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Historial de modificaciones del producto (seleccionar -> modificar -> validar -> actualizar).
CREATE TABLE IF NOT EXISTS productos_historial (
  id_productos_historial BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_productos          INT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NULL,
  version               INT UNSIGNED NOT NULL DEFAULT 1,
  datos_anteriores      JSON NULL,
  datos_nuevos          JSON NULL,
  comentario            VARCHAR(255) NULL,
  fecha                 DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_productos_historial (id_productos, fecha),
  CONSTRAINT fk_productos_historial_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos) ON DELETE CASCADE,
  CONSTRAINT fk_productos_historial_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Lotes (trazabilidad de mercaderia perecedera).
CREATE TABLE IF NOT EXISTS lotes (
  id_lotes              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_productos          INT UNSIGNED NOT NULL,
  codigo_lote           VARCHAR(60) NOT NULL,
  fecha_ingreso         DATE NULL,
  fecha_vencimiento     DATE NULL,
  proveedor_lote        VARCHAR(100) NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_lotes (id_productos, codigo_lote),
  CONSTRAINT fk_lotes_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ALMACENES (origen del stock)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS almacenes (
  id_almacenes          SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  nombre                VARCHAR(100) NOT NULL,
  direccion             VARCHAR(200) NULL,
  responsable           INT UNSIGNED NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_almacenes_codigo (codigo),
  CONSTRAINT fk_almacenes_responsable FOREIGN KEY (responsable)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- GESTION DE CLIENTES (base comercial)
--   - Listas de precios y condiciones comerciales asignadas al cliente
--   - Zonas y vendedores
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS zonas (
  id_zonas              SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  nombre                VARCHAR(100) NOT NULL,
  region                VARCHAR(100) NULL,
  id_usuarios_responsable INT UNSIGNED NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_zonas_codigo (codigo),
  CONSTRAINT fk_zonas_responsable FOREIGN KEY (id_usuarios_responsable)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vendedores (
  id_vendedores         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuarios           INT UNSIGNED NOT NULL,
  codigo                VARCHAR(20)  NOT NULL,
  nombre                VARCHAR(120) NOT NULL,
  email                 VARCHAR(150) NULL,
  telefono              VARCHAR(30)  NULL,
  id_zonas_default      SMALLINT UNSIGNED NULL,
  comision_base_pct     DECIMAL(5,2) NOT NULL DEFAULT 0,
  comision_maxima_pct   DECIMAL(5,2) NOT NULL DEFAULT 0,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_vendedores_usuario (id_usuarios),
  UNIQUE KEY uq_vendedores_codigo (codigo),
  CONSTRAINT fk_vendedores_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE CASCADE,
  CONSTRAINT fk_vendedores_zona FOREIGN KEY (id_zonas_default)
    REFERENCES zonas (id_zonas) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Listas de precios (asignacion al cliente + items por producto).
CREATE TABLE IF NOT EXISTS listas_precios (
  id_listas_precios     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  nombre                VARCHAR(100) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  tipo                  ENUM('MAYORISTA','MINORISTA','ESPECIAL','PROMOCIONAL','INTERNA') NOT NULL DEFAULT 'MAYORISTA',
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  fecha_vigencia_desde  DATE NOT NULL,
  fecha_vigencia_hasta  DATE NULL,
  id_usuarios_creacion  INT UNSIGNED NULL,
  activa                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_listas_precios_codigo (codigo),
  CONSTRAINT fk_listas_precios_usuario FOREIGN KEY (id_usuarios_creacion)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS listas_precios_items (
  id_listas_precios     INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  precio                DECIMAL(15,4) NOT NULL DEFAULT 0,
  descuento_pct         DECIMAL(5,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (id_listas_precios, id_productos),
  CONSTRAINT fk_listas_items_lista FOREIGN KEY (id_listas_precios)
    REFERENCES listas_precios (id_listas_precios) ON DELETE CASCADE,
  CONSTRAINT fk_listas_items_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Condicion comercial (plazo de pago, credito, recargos, mora).
CREATE TABLE IF NOT EXISTS condiciones_comerciales (
  id_condiciones_comerciales INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  nombre                VARCHAR(100) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  plazo_pago_dias       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  descuento_pct         DECIMAL(5,2) NOT NULL DEFAULT 0,
  recargo_pct           DECIMAL(5,2) NOT NULL DEFAULT 0,
  limite_credito        DECIMAL(15,2) NOT NULL DEFAULT 0,
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  interes_mora_pct      DECIMAL(5,2) NOT NULL DEFAULT 0,
  requiere_anticipo     TINYINT(1) NOT NULL DEFAULT 0,
  anticipo_pct          DECIMAL(5,2) NOT NULL DEFAULT 0,
  activa                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_condiciones_codigo (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clientes (
  id_clientes           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  tipo_cliente          ENUM('PERSONA','JURIDICA') NOT NULL DEFAULT 'JURIDICA',
  razon_social          VARCHAR(150) NOT NULL,
  nombre_fantasia       VARCHAR(150) NULL,
  tipo_documento        ENUM('CUIT','CUIL','DNI','PASAPORTE','OTRO') NOT NULL DEFAULT 'CUIT',
  nro_documento         VARCHAR(30) NULL,
  email                 VARCHAR(150) NULL,
  telefono              VARCHAR(30)  NULL,
  direccion             VARCHAR(200) NULL,
  ciudad                VARCHAR(100) NULL,
  provincia             VARCHAR(100) NULL,
  codigo_postal         VARCHAR(20)  NULL,
  pais                  VARCHAR(60)  NOT NULL DEFAULT 'Argentina',
  -- Origen y estado del proceso de alta
  origen                ENUM('PROSPECTO_COTIZACION','VENTA','WEB','REFERIDO','MANUAL','OTRO')
                          NOT NULL DEFAULT 'PROSPECTO_COTIZACION',
  estado                ENUM('PROSPECTO','POTENCIAL','ACTIVO','INACTIVO','SUSPENDIDO','BAJA')
                          NOT NULL DEFAULT 'PROSPECTO',
  fecha_alta            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_activacion      DATETIME NULL,
  id_usuarios_alta      INT UNSIGNED NULL,
  id_usuarios_ultima_modificacion INT UNSIGNED NULL,
  -- Condiciones comerciales y lista de precios por defecto
  id_listas_precios     INT UNSIGNED NULL,
  id_condicion_comercial INT UNSIGNED NULL,
  limite_credito        DECIMAL(15,2) NOT NULL DEFAULT 0,
  saldo_deuda           DECIMAL(15,2) NOT NULL DEFAULT 0,
  -- Bloqueo de compra
  bloqueado_compra      TINYINT(1) NOT NULL DEFAULT 0,
  motivo_bloqueo        VARCHAR(255) NULL,
  bloqueado_por         INT UNSIGNED NULL,
  bloqueado_en          DATETIME NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_clientes_codigo (codigo),
  UNIQUE KEY uq_clientes_documento (tipo_documento, nro_documento),
  KEY ix_clientes_razon (razon_social),
  KEY ix_clientes_estado (estado),
  KEY ix_clientes_bloqueo (bloqueado_compra),
  CONSTRAINT fk_clientes_lista_precios FOREIGN KEY (id_listas_precios)
    REFERENCES listas_precios (id_listas_precios) ON DELETE SET NULL,
  CONSTRAINT fk_clientes_condicion FOREIGN KEY (id_condicion_comercial)
    REFERENCES condiciones_comerciales (id_condiciones_comerciales) ON DELETE SET NULL,
  CONSTRAINT fk_clientes_alta_por FOREIGN KEY (id_usuarios_alta)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_clientes_mod_por FOREIGN KEY (id_usuarios_ultima_modificacion)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_clientes_bloqueo_por FOREIGN KEY (bloqueado_por)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Asignacion de listas de precios por cliente (puede tener varias vigentes).
CREATE TABLE IF NOT EXISTS clientes_listas_precios (
  id_clientes           INT UNSIGNED NOT NULL,
  id_listas_precios     INT UNSIGNED NOT NULL,
  fecha_desde           DATE NOT NULL,
  fecha_hasta           DATE NULL,
  es_principal          TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id_clientes, id_listas_precios, fecha_desde),
  CONSTRAINT fk_clientes_listas_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_clientes_listas_lista FOREIGN KEY (id_listas_precios)
    REFERENCES listas_precios (id_listas_precios) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clientes_condiciones_comerciales (
  id_clientes           INT UNSIGNED NOT NULL,
  id_condicion_comercial INT UNSIGNED NOT NULL,
  fecha_desde           DATE NOT NULL,
  fecha_hasta           DATE NULL,
  PRIMARY KEY (id_clientes, id_condicion_comercial, fecha_desde),
  CONSTRAINT fk_clientes_cond_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_clientes_cond_cond FOREIGN KEY (id_condicion_comercial)
    REFERENCES condiciones_comerciales (id_condiciones_comerciales) ON DELETE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
