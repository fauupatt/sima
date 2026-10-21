-- =====================================================================
-- SIMA  |  Esquema de base de datos - MariaDB 10.5+
-- Módulo: Nucleo transversal (usuarios, auditoria, catalogos base)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS sima
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sima;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 1. CATALOGOS BASE
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS unidades_medida (
  id_unidades_medida   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo               VARCHAR(10)  NOT NULL,
  nombre               VARCHAR(50)  NOT NULL,
  abreviatura          VARCHAR(10)  NOT NULL,
  permite_decimales    TINYINT(1)   NOT NULL DEFAULT 0,
  activo               TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categorias (
  id_categorias        SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo               VARCHAR(20)  NOT NULL,
  nombre               VARCHAR(100) NOT NULL,
  id_categoria_padre   SMALLINT UNSIGNED NULL,
  activo               TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT fk_categorias_padre FOREIGN KEY (id_categoria_padre)
    REFERENCES categorias (id_categorias) ON DELETE SET NULL,
  UNIQUE KEY uq_categorias_codigo (codigo)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. MODULO GESTION DE USUARIOS
--    - Flujo de autenticacion: valida password + rol -> acceso permitido/denegado
--    - Gestion de usuario: modificar datos / permisos / accesos
--    - Eliminacion de usuario (baja logica, preserva historico)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS roles (
  id_roles             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo               VARCHAR(40)  NOT NULL,
  nombre               VARCHAR(100) NOT NULL,
  descripcion          VARCHAR(255) NULL,
  es_sistema           TINYINT(1)   NOT NULL DEFAULT 0,
  activo               TINYINT(1)   NOT NULL DEFAULT 1,
  creado_en            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_roles_codigo (codigo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS permisos (
  id_permisos          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  modulo               VARCHAR(50)  NOT NULL,
  accion               VARCHAR(50)  NOT NULL,
  descripcion          VARCHAR(200) NULL,
  UNIQUE KEY uq_permisos (modulo, accion)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS roles_permisos (
  id_roles             INT UNSIGNED NOT NULL,
  id_permisos          INT UNSIGNED NOT NULL,
  PRIMARY KEY (id_roles, id_permisos),
  CONSTRAINT fk_roles_permisos_rol FOREIGN KEY (id_roles)
    REFERENCES roles (id_roles) ON DELETE CASCADE,
  CONSTRAINT fk_roles_permisos_permiso FOREIGN KEY (id_permisos)
    REFERENCES permisos (id_permisos) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS usuarios (
  id_usuarios             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo                  VARCHAR(20)  NOT NULL,
  usuario                 VARCHAR(50)  NOT NULL,
  email                   VARCHAR(150) NOT NULL,
  password_hash           VARCHAR(255) NOT NULL,
  nombre                  VARCHAR(100) NOT NULL,
  apellido                VARCHAR(120) NULL,
  documento               VARCHAR(30)  NULL,
  telefono                VARCHAR(30)  NULL,
  cargo                   VARCHAR(100) NULL,
  id_unidad_medida        TINYINT UNSIGNED NULL,
  activo                  TINYINT(1)   NOT NULL DEFAULT 1,
  eliminado               TINYINT(1)   NOT NULL DEFAULT 0,
  eliminado_en            DATETIME     NULL,
  eliminado_por           INT UNSIGNED NULL,
  requiere_cambio_clave   TINYINT(1)   NOT NULL DEFAULT 1,
  clave_actualizada_en    DATETIME     NULL,
  ultimo_acceso           DATETIME     NULL,
  intentos_fallidos       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  bloqueado_hasta         DATETIME     NULL,
  creado_en               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_usuarios_codigo (codigo),
  UNIQUE KEY uq_usuarios_usuario (usuario),
  UNIQUE KEY uq_usuarios_email (email),
  CONSTRAINT fk_usuarios_unidad FOREIGN KEY (id_unidad_medida)
    REFERENCES unidades_medida (id_unidades_medida) ON DELETE SET NULL
) ENGINE=InnoDB;

ALTER TABLE usuarios
  DROP FOREIGN KEY IF EXISTS fk_usuarios_eliminado_por,
  ADD CONSTRAINT fk_usuarios_eliminado_por FOREIGN KEY (eliminado_por)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL;

-- Un usuario puede tener mas de un rol (acceso por modulo).
CREATE TABLE IF NOT EXISTS usuarios_roles (
  id_usuarios          INT UNSIGNED NOT NULL,
  id_roles             INT UNSIGNED NOT NULL,
  asignado_en         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  asignado_por        INT UNSIGNED NULL,
  PRIMARY KEY (id_usuarios, id_roles),
  CONSTRAINT fk_usuarios_roles_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE CASCADE,
  CONSTRAINT fk_usuarios_roles_rol FOREIGN KEY (id_roles)
    REFERENCES roles (id_roles) ON DELETE CASCADE,
  CONSTRAINT fk_usuarios_roles_asignado_por FOREIGN KEY (asignado_por)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Permisos directos por usuario (ALLOW/DENY) por encima de los del rol.
CREATE TABLE IF NOT EXISTS usuarios_permisos (
  id_usuarios          INT UNSIGNED NOT NULL,
  id_permisos          INT UNSIGNED NOT NULL,
  tipo                 ENUM('ALLOW','DENY') NOT NULL DEFAULT 'ALLOW',
  asignado_en          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuarios, id_permisos),
  CONSTRAINT fk_usuarios_permisos_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE CASCADE,
  CONSTRAINT fk_usuarios_permisos_permiso FOREIGN KEY (id_permisos)
    REFERENCES permisos (id_permisos) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Sesiones activas (login + cierre).
CREATE TABLE IF NOT EXISTS sesiones (
  id_sesiones          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuarios          INT UNSIGNED NOT NULL,
  token                VARCHAR(255) NOT NULL,
  ip                   VARCHAR(45)  NULL,
  user_agent           VARCHAR(255) NULL,
  inicio_sesion        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ultimo_uso           DATETIME NULL,
  cierre_sesion        DATETIME NULL,
  motivo_cierre        ENUM('LOGOUT','EXPIRACION','TIMEOUT','ADMIN','CAMBIO_CLAVE') NULL,
  activo               TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_sesiones_token (token),
  KEY ix_sesiones_usuario (id_usuarios, activo),
  CONSTRAINT fk_sesiones_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Traza del flujo de autenticacion: permite medir accesos permitidos/denegados.
CREATE TABLE IF NOT EXISTS intentos_autenticacion (
  id_intentos_autenticacion BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuarios          INT UNSIGNED NULL,
  usuario_intento      VARCHAR(50)  NOT NULL,
  email_intento        VARCHAR(150) NULL,
  exito                TINYINT(1)   NOT NULL DEFAULT 0,
  motivo               ENUM('OK','CREDENCIALES_INVALIDAS','USUARIO_INACTIVO','USUARIO_BLOQUEADO',
                            'ROL_SIN_ACCESO','CUENTA_ELIMINADA','IP_BLOQUEADA') NOT NULL,
  id_roles_resuelto    INT UNSIGNED NULL,
  ip                   VARCHAR(45)  NULL,
  user_agent           VARCHAR(255) NULL,
  fecha                DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_intentos_fecha (fecha),
  KEY ix_intentos_usuario (usuario_intento, fecha),
  CONSTRAINT fk_intentos_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL,
  CONSTRAINT fk_intentos_rol FOREIGN KEY (id_roles_resuelto)
    REFERENCES roles (id_roles) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Recuperacion de clave / invitaciones / cambio de clave.
CREATE TABLE IF NOT EXISTS tokens_recuperacion (
  id_tokens_recuperacion BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuarios          INT UNSIGNED NOT NULL,
  token_hash           VARCHAR(255) NOT NULL,
  tipo                 ENUM('RECUPERACION','CAMBIO_CLAVE','INVITACION') NOT NULL DEFAULT 'RECUPERACION',
  expira_en            DATETIME NOT NULL,
  usado                TINYINT(1) NOT NULL DEFAULT 0,
  usado_en             DATETIME NULL,
  creado_en            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tokens_hash (token_hash),
  KEY ix_tokens_usuario (id_usuarios, tipo),
  CONSTRAINT fk_tokens_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. AUDITORIA TRANSVERSAL
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS auditoria (
  id_auditoria         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuarios          INT UNSIGNED NULL,
  modulo               VARCHAR(50)  NOT NULL,
  entidad              VARCHAR(60)  NOT NULL,
  id_entidad           BIGINT UNSIGNED NULL,
  operacion            ENUM('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','APROBACION','ANULACION') NOT NULL,
  descripcion          VARCHAR(255) NULL,
  datos_antes          JSON NULL,
  datos_despues        JSON NULL,
  ip                   VARCHAR(45)  NULL,
  fecha                DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_auditoria_entidad (entidad, id_entidad),
  KEY ix_auditoria_fecha (fecha),
  CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuarios)
    REFERENCES usuarios (id_usuarios) ON DELETE SET NULL
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
