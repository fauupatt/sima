-- =====================================================================
-- SIMA  |  Modulo Gestion de Clientes
--   - Prospectos y cotizaciones (registro de cliente)
--   - Asignacion a zonas/vendedores y comisiones
--   - Reportes de clientes
--   - Investigacion de cliente
--   - Gestion de reclamos
--   - Bloqueo de cuenta por deuda
-- =====================================================================

USE sima;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- PROSPECTOS  (origen del flujo: prospecto solicita cotizacion)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS prospectos (
  id_prospectos         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(20)  NOT NULL,
  razon_social          VARCHAR(150) NOT NULL,
  nombre_fantasia       VARCHAR(150) NULL,
  tipo_documento        ENUM('CUIT','CUIL','DNI','PASAPORTE','OTRO') NOT NULL DEFAULT 'CUIT',
  nro_documento         VARCHAR(30)  NULL,
  email                 VARCHAR(150) NULL,
  telefono              VARCHAR(30)  NULL,
  ciudad                VARCHAR(100) NULL,
  provincia             VARCHAR(100) NULL,
  origen                ENUM('WEB','TELEFONO','VISITA','FERIA','REFERIDO','OTRO') NOT NULL DEFAULT 'OTRO',
  estado                ENUM('NUEVO','EN_COTIZACION','COTIZADO','CONVERTIDO','DESCARTADO','PERDIDO')
                          NOT NULL DEFAULT 'NUEVO',
  id_clientes           INT UNSIGNED NULL COMMENT 'Cliente generado al convertir',
  id_vendedores         INT UNSIGNED NULL,
  id_zonas              SMALLINT UNSIGNED NULL,
  id_usuarios_alta      INT UNSIGNED NULL,
  fecha_alta            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_conversion      DATETIME NULL,
  motivo_descarte       VARCHAR(255) NULL,
  observacion           TEXT NULL,
  UNIQUE KEY uq_prospectos_codigo (codigo),
  KEY ix_prospectos_estado (estado),
  KEY ix_prospectos_documento (tipo_documento, nro_documento),
  CONSTRAINT fk_prospectos_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE SET NULL,
  CONSTRAINT fk_prospectos_vendedor FOREIGN KEY (id_vendedores)
    REFERENCES vendedores (id_vendedores) ON DELETE SET NULL,
  CONSTRAINT fk_prospectos_zona FOREIGN KEY (id_zonas)
    REFERENCES zonas (id_zonas) ON DELETE SET NULL,
  CONSTRAINT fk_prospectos_alta_por FOREIGN KEY (id_usuarios_alta)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ASIGNACION A VENDEDORES (revision de clientes por zona)
--   -> Asignacion del cliente a una zona o a un vendedor
--   -> Configuracion de comisiones
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS asignaciones_clientes (
  id_asignaciones_clientes INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_clientes           INT UNSIGNED NOT NULL,
  id_zonas              SMALLINT UNSIGNED NULL,
  id_vendedores         INT UNSIGNED NULL,
  tipo_asignacion       ENUM('ZONA','VENDEDOR') NOT NULL DEFAULT 'VENDEDOR',
  fecha_desde           DATE NOT NULL,
  fecha_hasta           DATE NULL,
  comision_pct          DECIMAL(5,2) NOT NULL DEFAULT 0,
  comision_base_monto   DECIMAL(15,2) NOT NULL DEFAULT 0,
  comision_maxima_monto DECIMAL(15,2) NULL,
  id_usuarios_asignacion INT UNSIGNED NULL,
  motivo                VARCHAR(255) NULL,
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_asignaciones_vigente (id_clientes, tipo_asignacion, fecha_desde),
  KEY ix_asignaciones_cliente (id_clientes, fecha_hasta),
  KEY ix_asignaciones_vendedor (id_vendedores, fecha_desde),
  KEY ix_asignaciones_zona (id_zonas, fecha_desde),
  CONSTRAINT fk_asignaciones_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_asignaciones_zona FOREIGN KEY (id_zonas)
    REFERENCES zonas (id_zonas) ON DELETE SET NULL,
  CONSTRAINT fk_asignaciones_vendedor FOREIGN KEY (id_vendedores)
    REFERENCES vendedores (id_vendedores) ON DELETE SET NULL,
  CONSTRAINT fk_asignaciones_usuario FOREIGN KEY (id_usuarios_asignacion)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- COTIZACIONES (ligadas a productos existentes)
--   Prospecto solicita cotizacion -> cliente dado de alta -> lista de precios
--   y condicion comercial -> emision de cotizacion -> carga de estado del proceso
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS estados_cotizacion (
  id_estados_cotizacion SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo               VARCHAR(30) NOT NULL,
  nombre               VARCHAR(60) NOT NULL,
  descripcion          VARCHAR(255) NULL,
  orden                SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  es_final             TINYINT(1) NOT NULL DEFAULT 0,
  activo               TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_estados_cotizacion (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cotizaciones (
  id_cotizaciones       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero                VARCHAR(30) NOT NULL,
  id_clientes           INT UNSIGNED NOT NULL,
  id_prospectos         INT UNSIGNED NULL,
  id_usuarios           INT UNSIGNED NOT NULL COMMENT 'Emisor',
  id_listas_precios     INT UNSIGNED NULL,
  id_condicion_comercial INT UNSIGNED NULL,
  id_estados_cotizacion SMALLINT UNSIGNED NOT NULL,
  fecha_emision         DATE NOT NULL,
  fecha_validez         DATE NULL,
  fecha_cierre          DATE NULL,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  descuento             DECIMAL(15,2) NOT NULL DEFAULT 0,
  recargo               DECIMAL(15,2) NOT NULL DEFAULT 0,
  impuestos            DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  moneda                CHAR(3) NOT NULL DEFAULT 'ARS',
  observaciones         TEXT NULL,
  -- Estado de la carga del proceso
  estado_carga          ENUM('PENDIENTE','CARGADO','ERROR') NOT NULL DEFAULT 'PENDIENTE',
  id_ventas             INT UNSIGNED NULL COMMENT 'Cotizacion convertida en venta',
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cotizaciones_numero (numero),
  KEY ix_cotizaciones_cliente (id_clientes, fecha_emision),
  KEY ix_cotizaciones_estado (id_estados_cotizacion, fecha_emision),
  CONSTRAINT fk_cotizaciones_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_cotizaciones_prospecto FOREIGN KEY (id_prospectos)
    REFERENCES prospectos (id_prospectos) ON DELETE SET NULL,
  CONSTRAINT fk_cotizaciones_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_cotizaciones_lista FOREIGN KEY (id_listas_precios)
    REFERENCES listas_precios (id_listas_precios) ON DELETE SET NULL,
  CONSTRAINT fk_cotizaciones_condicion FOREIGN KEY (id_condicion_comercial)
    REFERENCES condiciones_comerciales (id_condiciones_comerciales) ON DELETE SET NULL,
  CONSTRAINT fk_cotizaciones_estado FOREIGN KEY (id_estados_cotizacion)
    REFERENCES estados_cotizacion (id_estados_cotizacion)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cotizaciones_items (
  id_cotizaciones_items BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_cotizaciones       INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NOT NULL,
  descripcion           VARCHAR(200) NULL,
  cantidad              DECIMAL(15,3) NOT NULL DEFAULT 1,
  id_unidades_medida    TINYINT UNSIGNED NULL,
  precio_lista          DECIMAL(15,4) NOT NULL DEFAULT 0,
  precio_unitario       DECIMAL(15,4) NOT NULL DEFAULT 0,
  descuento_pct         DECIMAL(5,2) NOT NULL DEFAULT 0,
  descuento_monto       DECIMAL(15,2) NOT NULL DEFAULT 0,
  recargo_pct           DECIMAL(5,2) NOT NULL DEFAULT 0,
  subtotal              DECIMAL(15,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  KEY ix_cotizaciones_items (id_cotizaciones),
  CONSTRAINT fk_cotizaciones_items_cotizacion FOREIGN KEY (id_cotizaciones)
    REFERENCES cotizaciones (id_cotizaciones) ON DELETE CASCADE,
  CONSTRAINT fk_cotizaciones_items_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos),
  CONSTRAINT fk_cotizaciones_items_unidad FOREIGN KEY (id_unidades_medida)
    REFERENCES unidades_medida (id_unidades_medida) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Traza del estado del proceso de cotizacion.
CREATE TABLE IF NOT EXISTS cotizaciones_estados_historial (
  id_cotizaciones_estados_historial BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_cotizaciones       INT UNSIGNED NOT NULL,
  id_estados_cotizacion SMALLINT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NULL,
  comentario            VARCHAR(255) NULL,
  fecha                 DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cotizaciones_historial (id_cotizaciones, fecha),
  CONSTRAINT fk_cotizaciones_historial_cotizacion FOREIGN KEY (id_cotizaciones)
    REFERENCES cotizaciones (id_cotizaciones) ON DELETE CASCADE,
  CONSTRAINT fk_cotizaciones_historial_estado FOREIGN KEY (id_estados_cotizacion)
    REFERENCES estados_cotizacion (id_estados_cotizacion),
  CONSTRAINT fk_cotizaciones_historial_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- INVESTIGACION DE CLIENTE
--   Seleccion de cliente -> busqueda en la web -> resultados sobre
--   actividad comercial del cliente
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS investigaciones (
  id_investigaciones    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_clientes           INT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  tipo                  ENUM('WEB','REDES','REGISTROS','OTRO') NOT NULL DEFAULT 'WEB',
  consulta              VARCHAR(200) NULL COMMENT 'Texto de busqueda',
  fuente                VARCHAR(100) NULL COMMENT 'Motor / sitio consultado',
  fecha_consulta        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado                ENUM('PENDIENTE','EN_CURSO','COMPLETADA','ERROR') NOT NULL DEFAULT 'PENDIENTE',
  resumen               TEXT NULL,
  actividad_comercial   ENUM('ACTIVO','INACTIVO','POTENCIAL','INDETERMINADO') NULL,
  id_usuarios_asignado  INT UNSIGNED NULL,
  UNIQUE KEY uq_investigaciones (id_clientes, fecha_consulta),
  KEY ix_investigaciones_cliente (id_clientes),
  CONSTRAINT fk_investigaciones_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_investigaciones_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_investigaciones_asignado FOREIGN KEY (id_usuarios_asignado)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS investigacion_resultados (
  id_investigacion_resultados BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_investigaciones    INT UNSIGNED NOT NULL,
  tipo                  ENUM('WEB','NOTICIA','RED_SOCIAL','REGISTRO','OTRO') NOT NULL DEFAULT 'WEB',
  titulo                VARCHAR(300) NULL,
  url                   VARCHAR(500) NULL,
  dominio               VARCHAR(150) NULL,
  extracto              TEXT NULL,
  fecha_publicacion     DATE NULL,
  relevante             TINYINT(1) NOT NULL DEFAULT 0,
  fecha_registro        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_investigacion_resultados (id_investigaciones),
  CONSTRAINT fk_investigacion_resultados_investigacion FOREIGN KEY (id_investigaciones)
    REFERENCES investigaciones (id_investigaciones) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Actividad comercial detectada del cliente.
CREATE TABLE IF NOT EXISTS investigacion_actividad_comercial (
  id_investigacion_actividad_comercial BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_investigaciones    INT UNSIGNED NOT NULL,
  tipo                  ENUM('COMPRA','VENTA','INAUGURACION','FERIA','CONTRATO','LICITACION','OTRO')
                          NOT NULL DEFAULT 'OTRO',
  descripcion           VARCHAR(300) NULL,
  fecha                 DATE NULL,
  monto                 DECIMAL(15,2) NULL,
  fuente                VARCHAR(200) NULL,
  KEY ix_investigacion_actividad (id_investigaciones),
  CONSTRAINT fk_investigacion_actividad_investigacion FOREIGN KEY (id_investigaciones)
    REFERENCES investigaciones (id_investigaciones) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- GESTION DE RECLAMOS
--   Recepcion -> registro del reclamo (detalles) -> autorizacion de devolucion
--   -> asignacion de responsable -> cierre con motivo para metricas
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tipos_reclamo (
  id_tipos_reclamo      SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(30) NOT NULL,
  nombre                VARCHAR(100) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  requiere_devolucion   TINYINT(1) NOT NULL DEFAULT 0,
  sla_horas             SMALLINT UNSIGNED NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_tipos_reclamo (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS estados_reclamo (
  id_estados_reclamo    SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(30) NOT NULL,
  nombre                VARCHAR(60) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  orden                 SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  es_final              TINYINT(1) NOT NULL DEFAULT 0,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_estados_reclamo (codigo)
) ENGINE=InnoDB;

-- Motivo de cierre: base de las metricas de reclamos.
CREATE TABLE IF NOT EXISTS motivos_cierre_reclamo (
  id_motivos_cierre_reclamo SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(30) NOT NULL,
  nombre                VARCHAR(100) NOT NULL,
  descripcion           VARCHAR(255) NULL,
  categoria             ENUM('RESUELTO','RECHAZADO','DUPLICADO','FUERA_DE_ALCANCE','NO_RESUELTO','DEVOLUCION')
                          NOT NULL DEFAULT 'RESUELTO',
  activa                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_motivos_cierre (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reclamos (
  id_reclamos           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero                VARCHAR(30) NOT NULL,
  id_clientes           INT UNSIGNED NOT NULL,
  id_tipos_reclamo      SMALLINT UNSIGNED NOT NULL,
  id_ventas             INT UNSIGNED NULL,
  id_cotizaciones       INT UNSIGNED NULL,
  id_productos          INT UNSIGNED NULL,
  -- Recepcion
  id_usuarios_registro  INT UNSIGNED NOT NULL,
  fecha_recepcion       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  canal                 ENUM('TELEFONO','EMAIL','WEB','PRESENCIAL','OTRO') NOT NULL DEFAULT 'TELEFONO',
  prioridad             ENUM('BAJA','MEDIA','ALTA','URGENTE') NOT NULL DEFAULT 'MEDIA',
  descripcion           TEXT NOT NULL COMMENT 'Detalle del reclamo',
  monto_reclamado       DECIMAL(15,2) NOT NULL DEFAULT 0,
  -- Estado del proceso
  id_estados_reclamo    SMALLINT UNSIGNED NOT NULL,
  -- Asignacion de responsable
  id_usuarios_responsable INT UNSIGNED NULL,
  fecha_asignacion      DATETIME NULL,
  -- Autorizacion de devolucion
  devolucion_autorizada TINYINT(1) NOT NULL DEFAULT 0,
  devolucion_autorizada_por INT UNSIGNED NULL,
  devolucion_autorizada_en DATETIME NULL,
  -- Cierre
  fecha_cierre          DATETIME NULL,
  id_usuarios_cierre    INT UNSIGNED NULL,
  id_motivo_cierre      SMALLINT UNSIGNED NULL,
  resolucion            TEXT NULL,
  activo                TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_reclamos_numero (numero),
  KEY ix_reclamos_cliente (id_clientes, fecha_recepcion),
  KEY ix_reclamos_estado (id_estados_reclamo),
  KEY ix_reclamos_responsable (id_usuarios_responsable),
  KEY ix_reclamos_motivo_cierre (id_motivo_cierre),
  CONSTRAINT fk_reclamos_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_reclamos_tipo FOREIGN KEY (id_tipos_reclamo)
    REFERENCES tipos_reclamo (id_tipos_reclamo),
  CONSTRAINT fk_reclamos_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos) ON DELETE SET NULL,
  CONSTRAINT fk_reclamos_registro_por FOREIGN KEY (id_usuarios_registro)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_reclamos_responsable FOREIGN KEY (id_usuarios_responsable)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_reclamos_autoriza_por FOREIGN KEY (devolucion_autorizada_por)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_reclamos_cierre_por FOREIGN KEY (id_usuarios_cierre)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_reclamos_estado FOREIGN KEY (id_estados_reclamo)
    REFERENCES estados_reclamo (id_estados_reclamo),
  CONSTRAINT fk_reclamos_motivo_cierre FOREIGN KEY (id_motivo_cierre)
    REFERENCES motivos_cierre_reclamo (id_motivos_cierre_reclamo) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Detalles / evidencias / acciones del reclamo.
CREATE TABLE IF NOT EXISTS reclamos_detalles (
  id_reclamos_detalles  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reclamos           INT UNSIGNED NOT NULL,
  tipo                  ENUM('DETALLE','EVIDENCIA','DOCUMENTO','ACCION','RECLAMO_PROVEEDOR') NOT NULL DEFAULT 'DETALLE',
  descripcion           TEXT NULL,
  archivo_path          VARCHAR(500) NULL,
  id_usuarios           INT UNSIGNED NULL,
  fecha                 DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_reclamos_detalles (id_reclamos),
  CONSTRAINT fk_reclamos_detalles_reclamo FOREIGN KEY (id_reclamos)
    REFERENCES reclamos (id_reclamos) ON DELETE CASCADE,
  CONSTRAINT fk_reclamos_detalles_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Autorizacion de devolucion (total / parcial / credito / reemplazo).
CREATE TABLE IF NOT EXISTS reclamos_devoluciones (
  id_reclamos_devoluciones BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reclamos           INT UNSIGNED NOT NULL,
  id_productos          INT UNSIGNED NULL,
  cantidad              DECIMAL(15,3) NOT NULL DEFAULT 0,
  monto                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  tipo_devolucion       ENUM('TOTAL','PARCIAL','CREDITO','REEMPLAZO') NOT NULL DEFAULT 'TOTAL',
  estado                ENUM('SOLICITADA','AUTORIZADA','RECHAZADA','EJECUTADA') NOT NULL DEFAULT 'SOLICITADA',
  id_usuarios_solicita  INT UNSIGNED NULL,
  fecha_solicitud       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_usuarios_autoriza  INT UNSIGNED NULL,
  fecha_autorizacion    DATETIME NULL,
  motivo_rechazo        VARCHAR(255) NULL,
  fecha_ejecucion       DATETIME NULL,
  KEY ix_reclamos_devoluciones (id_reclamos),
  CONSTRAINT fk_reclamos_devoluciones_reclamo FOREIGN KEY (id_reclamos)
    REFERENCES reclamos (id_reclamos) ON DELETE CASCADE,
  CONSTRAINT fk_reclamos_devoluciones_producto FOREIGN KEY (id_productos)
    REFERENCES productos (id_productos) ON DELETE SET NULL,
  CONSTRAINT fk_reclamos_devoluciones_solicita FOREIGN KEY (id_usuarios_solicita)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_reclamos_devoluciones_autoriza FOREIGN KEY (id_usuarios_autoriza)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reclamos_historial (
  id_reclamos_historial  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reclamos           INT UNSIGNED NOT NULL,
  id_estados_reclamo    SMALLINT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NULL,
  comentario            VARCHAR(255) NULL,
  fecha                 DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_reclamos_historial (id_reclamos, fecha),
  CONSTRAINT fk_reclamos_historial_reclamo FOREIGN KEY (id_reclamos)
    REFERENCES reclamos (id_reclamos) ON DELETE CASCADE,
  CONSTRAINT fk_reclamos_historial_estado FOREIGN KEY (id_estados_reclamo)
    REFERENCES estados_reclamo (id_estados_reclamo),
  CONSTRAINT fk_reclamos_historial_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- BLOQUEO DE CUENTA POR DEUDA
--   Eleccion del cliente -> eliminacion (aclaracion) -> confirmacion
--   -> bloqueo de compra -> notificacion al cliente
-- ---------------------------------------------------------------------

-- Origen de la deuda del cliente (cuenta corriente).
CREATE TABLE IF NOT EXISTS clientes_deudas (
  id_clientes_deudas    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_clientes           INT UNSIGNED NOT NULL,
  documento_tipo        ENUM('VENTA','COMPRA','REPARTO','AJUSTE','OTRO') NOT NULL DEFAULT 'VENTA',
  documento_id          INT UNSIGNED NULL,
  documento_numero      VARCHAR(30) NULL,
  monto_original        DECIMAL(15,2) NOT NULL DEFAULT 0,
  saldo                 DECIMAL(15,2) NOT NULL DEFAULT 0,
  fecha_emision         DATE NOT NULL,
  fecha_vencimiento     DATE NOT NULL,
  dias_vencimiento      SMALLINT UNSIGNED NULL,
  estado                ENUM('AL_DIA','VENCIDO','PAGADO','ANULADO','EN_COBRANZA') NOT NULL DEFAULT 'AL_DIA',
  id_usuarios_registro  INT UNSIGNED NULL,
  KEY ix_clientes_deudas (id_clientes, estado, fecha_vencimiento),
  CONSTRAINT fk_clientes_deudas_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_clientes_deudas_usuario FOREIGN KEY (id_usuarios_registro)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bloqueos_clientes (
  id_bloqueos_clientes  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_clientes           INT UNSIGNED NOT NULL,
  id_usuarios           INT UNSIGNED NOT NULL COMMENT 'Quien ejecuta el bloqueo',
  monto_deuda           DECIMAL(15,2) NOT NULL DEFAULT 0,
  dias_vencimiento      SMALLINT UNSIGNED NULL,
  motivo                VARCHAR(255) NOT NULL,
  observacion           TEXT NULL,
  fecha_bloqueo         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_desbloqueo      DATETIME NULL,
  id_usuarios_desbloqueo INT UNSIGNED NULL,
  estado                ENUM('ACTIVO','LEVANTADO','ANULADO') NOT NULL DEFAULT 'ACTIVO',
  id_notificaciones     INT UNSIGNED NULL,
  KEY ix_bloqueos_clientes (id_clientes, estado),
  CONSTRAINT fk_bloqueos_clientes_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_bloqueos_clientes_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios),
  CONSTRAINT fk_bloqueos_clientes_desbloqueo_por FOREIGN KEY (id_usuarios_desbloqueo)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Notificaciones (al cliente por bloqueo, avisos de reclamo, etc.).
CREATE TABLE IF NOT EXISTS notificaciones (
  id_notificaciones     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_clientes           INT UNSIGNED NULL,
  id_usuarios_destino   INT UNSIGNED NULL,
  id_bloqueos_clientes  BIGINT UNSIGNED NULL,
  destinatario          VARCHAR(150) NULL,
  canal                 ENUM('EMAIL','SMS','WHATSAPP','INTERNO','PUSH') NOT NULL DEFAULT 'EMAIL',
  tipo                  VARCHAR(60) NOT NULL COMMENT 'Ej: BLOQUEO_COMPRA, RECLAMO_RECIBIDO, CIERRE_RECLAMO',
  asunto                VARCHAR(200) NULL,
  mensaje               TEXT NULL,
  estado                ENUM('PENDIENTE','ENVIADA','FALLIDA','LEIDA') NOT NULL DEFAULT 'PENDIENTE',
  fecha_envio           DATETIME NULL,
  fecha_lectura         DATETIME NULL,
  error                 VARCHAR(500) NULL,
  creado_en             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_notificaciones_cliente (id_clientes, creado_en),
  KEY ix_notificaciones_estado (estado, creado_en),
  CONSTRAINT fk_notificaciones_cliente FOREIGN KEY (id_clientes)
    REFERENCES clientes (id_clientes) ON DELETE CASCADE,
  CONSTRAINT fk_notificaciones_usuario FOREIGN KEY (id_usuarios_destino)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_notificaciones_bloqueo FOREIGN KEY (id_bloqueos_clientes)
    REFERENCES bloqueos_clientes (id_bloqueos_clientes) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- REPORTES DE CLIENTES
--   Filtrado por datos / periodos -> documento excel -> graficos
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS reportes (
  id_reportes           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                VARCHAR(40) NOT NULL,
  nombre                VARCHAR(150) NOT NULL,
  modulo                VARCHAR(50) NOT NULL,
  tipo                  ENUM('TABLA','EXCEL','CSV','PDF','GRAFICO') NOT NULL DEFAULT 'TABLA',
  parametros            JSON NULL COMMENT 'Filtros aplicados: datos, periodos, zonas, vendedor, estado',
  columnas              JSON NULL,
  id_usuarios           INT UNSIGNED NOT NULL,
  fecha_desde           DATE NULL,
  fecha_hasta           DATE NULL,
  archivo_path          VARCHAR(500) NULL,
  hash_archivo          VARCHAR(100) NULL,
  estado                ENUM('PENDIENTE','GENERADO','ERROR') NOT NULL DEFAULT 'PENDIENTE',
  error                 VARCHAR(500) NULL,
  duracion_seg          DECIMAL(10,3) NULL,
  generado_en           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_reportes_codigo (codigo),
  KEY ix_reportes_usuario (id_usuarios, generado_en),
  CONSTRAINT fk_reportes_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
