-- =====================================================================
-- SIMA  |  Datos iniciales (catalogos, roles, permisos, usuario admin)
-- =====================================================================

USE sima;

-- ---------------------------------------------------------------------
-- Unidades de medida
-- ---------------------------------------------------------------------
INSERT IGNORE INTO unidades_medida (codigo, nombre, abreviatura, permite_decimales) VALUES
  ('UND','Unidad','UND',1),
  ('KG','Kilogramo','kg',1),
  ('LT','Litro','L',1),
  ('CAJA','Caja','CAJA',0),
  ('BOLSA','Bolsa','BOLSA',0),
  ('PALLET','Pallet','PAL',0),
  ('METRO','Metro','m',1);

-- ---------------------------------------------------------------------
-- Categorias
-- ---------------------------------------------------------------------
INSERT IGNORE INTO categorias (codigo, nombre) VALUES
  ('GENERAL','General'),
  ('INSUMOS','Insumos'),
  ('REPUESTOS','Repuestos'),
  ('SERVICIOS','Servicios');

-- ---------------------------------------------------------------------
-- Almacenes
-- ---------------------------------------------------------------------
INSERT IGNORE INTO almacenes (codigo, nombre, direccion) VALUES
  ('CENTRAL','Almacen Central','Casa Central'),
  ('SUC-01','Sucursal 01',''),
  ('SUC-02','Sucursal 02','');

-- ---------------------------------------------------------------------
-- Zonas (revision de clientes por zona)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO zonas (codigo, nombre, region) VALUES
  ('ZN-CEN','Zona Centro','Centro'),
  ('ZN-NOR','Zona Norte','Norte'),
  ('ZN-SUR','Zona Sur','Sur'),
  ('ZN-OES','Zona Oeste','Oeste');

-- ---------------------------------------------------------------------
-- Listas de precios
-- ---------------------------------------------------------------------
INSERT IGNORE INTO listas_precios (codigo, nombre, tipo, fecha_vigencia_desde, activa) VALUES
  ('LP-MAY','Lista Mayorista','MAYORISTA','2020-01-01',1),
  ('LP-MIN','Lista Minorista','MINORISTA','2020-01-01',1),
  ('LP-ESP','Lista Especial','ESPECIAL','2020-01-01',1);

-- ---------------------------------------------------------------------
-- Condiciones comerciales
-- ---------------------------------------------------------------------
INSERT IGNORE INTO condiciones_comerciales
  (codigo, nombre, plazo_pago_dias, descuento_pct, limite_credito, interes_mora_pct) VALUES
  ('CC-EFECT','Contado',0,0,0,0),
  ('CC-15','Credito 15 dias',15,0,500000,2.00),
  ('CC-30','Credito 30 dias',30,2,1000000,2.00),
  ('CC-60','Credito 60 dias',60,3,2500000,2.50);

-- ---------------------------------------------------------------------
-- Estados de cotizacion (carga de estado del proceso)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO estados_cotizacion (codigo, nombre, orden, es_final) VALUES
  ('BORRADOR','Borrador',1,0),
  ('EMITIDA','Emitida',2,0),
  ('ENVIADA','Enviada al cliente',3,0),
  ('EN_NEGOCIACION','En negociacion',4,0),
  ('ACEPTADA','Aceptada',5,1),
  ('RECHAZADA','Rechazada',6,1),
  ('VENCIDA','Vencida',7,1),
  ('CONVERTIDA','Convertida en venta',8,1);

-- ---------------------------------------------------------------------
-- Estados de reclamo
-- ---------------------------------------------------------------------
INSERT IGNORE INTO estados_reclamo (codigo, nombre, orden, es_final) VALUES
  ('RECIBIDO','Recibido',1,0),
  ('EN_PROCESAMIENTO','En procesamiento',2,0),
  ('ESPERA_DEVOLUCION','Espera de autorizacion de devolucion',3,0),
  ('DEVOLUCION_AUTORIZADA','Devolucion autorizada',4,0),
  ('RESUELTO','Resuelto',5,1),
  ('CERRADO','Cerrado',6,1),
  ('RECHAZADO','Rechazado',7,1);

-- ---------------------------------------------------------------------
-- Motivos de cierre de reclamo (base de las metricas)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO motivos_cierre_reclamo (codigo, nombre, categoria) VALUES
  ('MC-SOLUCION','Solucion en el momento','RESUELTO'),
  ('MC-REEMPLAZO','Reemplazo de mercaderia','RESUELTO'),
  ('MC-DEV_TOTAL','Devolucion total','DEVOLUCION'),
  ('MC-DEV_PARCIAL','Devolucion parcial','DEVOLUCION'),
  ('MC-CREDITO','Emision de nota de credito','DEVOLUCION'),
  ('MC-SIN_RESPUESTA','Sin respuesta del cliente','NO_RESUELTO'),
  ('MC-RECHAZADO','Reclamo rechazado','RECHAZADO'),
  ('MC-DUPLICADO','Reclamo duplicado','DUPLICADO'),
  ('MC-FUERA_ALCANCE','Fuera de alcance','FUERA_DE_ALCANCE');

-- ---------------------------------------------------------------------
-- Tipos de reclamo
-- ---------------------------------------------------------------------
INSERT IGNORE INTO tipos_reclamo (codigo, nombre, requiere_devolucion, sla_horas) VALUES
  ('TR-DEFECTUOSO','Producto defectuoso',1,72),
  ('TR-INCOMPLETO','Producto incompleto',1,48),
  ('TR-DANADO','Mercaderia danada en transporte',1,48),
  ('TR-FACTURACION','Error de facturacion',0,24),
  ('TR-ENTREGA','Demora en la entrega',0,72),
  ('TR-OTRO','Otro reclamo',0,72);

-- ---------------------------------------------------------------------
-- Estados de compra
-- ---------------------------------------------------------------------
INSERT IGNORE INTO estados_compra (codigo, nombre, orden, es_final) VALUES
  ('COTIZADA','Cotizada',1,0),
  ('CONFIRMADA','Confirmada',2,0),
  ('EN_TRANSITO','En transito',3,0),
  ('RECIBIDA','Recibida',4,1),
  ('PARCIAL','Recibida parcialmente',5,0),
  ('ANULADA','Anulada',6,1);

-- ---------------------------------------------------------------------
-- Estados de venta
-- ---------------------------------------------------------------------
INSERT IGNORE INTO estados_venta (codigo, nombre, orden, es_final) VALUES
  ('BORRADOR','Borrador',1,0),
  ('CONFIRMADA','Confirmada',2,0),
  ('PENDIENTE_PAGO','Pendiente de pago',3,0),
  ('PAGADA','Pagada',4,0),
  ('DESPACHADA','Despachada',5,0),
  ('FACTURADA','Facturada',6,1),
  ('ANULADA','Anulada',7,1);

-- ---------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------
INSERT IGNORE INTO roles (codigo, nombre, descripcion, es_sistema) VALUES
  ('ADMIN','Administrador','Acceso total al sistema',1),
  ('GERENTE','Gerente Comercial','Gestion comercial y reportes',1),
  ('VENDEDOR','Vendedor','Atencion de clientes y ventas',1),
  ('COMPRAS','Compras','Proveedores, compras e inventario',1),
  ('ALMACENERO','Almacenero','Gestion de stock y movimientos',1),
  ('CONTADOR','Contador','Operaciones, comprobantes y reportes',1),
  ('ATENCION','Atencion al Cliente','Reclamos y gestion de clientes',1);

-- ---------------------------------------------------------------------
-- Permisos (modulo x accion)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO permisos (modulo, accion, descripcion) VALUES
  ('CLIENTES','VER','Ver clientes'),            ('CLIENTES','CREAR','Registrar clientes'),
  ('CLIENTES','EDITAR','Modificar clientes'),   ('CLIENTES','ELIMINAR','Eliminar clientes'),
  ('CLIENTES','ASIGNAR','Asignar zona y vendedor'), ('CLIENTES','COMISION','Configurar comisiones'),
  ('CLIENTES','COTIZAR','Emitir cotizaciones'),  ('CLIENTES','BLOQUEAR','Bloquear compra por deuda'),
  ('CLIENTES','INVESTIGAR','Investigar actividad comercial'), ('CLIENTES','RECLAMOS','Gestionar reclamos'),
  ('USUARIOS','VER','Ver usuarios'),            ('USUARIOS','CREAR','Crear usuarios'),
  ('USUARIOS','EDITAR','Modificar datos y permisos de usuarios'), ('USUARIOS','ELIMINAR','Eliminar usuarios'),
  ('PROVEEDORES','VER','Ver proveedores'),      ('PROVEEDORES','CREAR','Registrar proveedores'),
  ('PROVEEDORES','EDITAR','Modificar proveedores'), ('PROVEEDORES','VALIDAR','Validar proveedores'),
  ('PROVEEDORES','ELIMINAR','Eliminar proveedores'),
  ('PRODUCTOS','VER','Ver productos'),          ('PRODUCTOS','CREAR','Registrar productos'),
  ('PRODUCTOS','EDITAR','Modificar productos'), ('PRODUCTOS','ELIMINAR','Dar de baja productos'),
  ('INVENTARIO','VER','Consultar stock'),       ('INVENTARIO','AJUSTAR','Registrar ajustes de stock'),
  ('INVENTARIO','INGRESAR','Ingresar mercaderia'), ('INVENTARIO','REPOSICION','Gestionar reposiciones'),
  ('COMPRAS','VER','Ver compras'),              ('COMPRAS','CREAR','Registrar compras'),
  ('COMPRAS','EDITAR','Modificar compras'),     ('COMPRAS','RECEPCION','Recibir mercaderia'),
  ('COMPRAS','ANULAR','Anular compras'),
  ('VENTAS','VER','Ver ventas'),                ('VENTAS','CREAR','Registrar ventas'),
  ('VENTAS','EDITAR','Modificar ventas'),       ('VENTAS','CONFIRMAR','Confirmar presupuestos'),
  ('VENTAS','ANULAR','Anular ventas'),
  ('REPORTES','VER','Consultar reportes'),      ('REPORTES','GENERAR','Generar reportes y graficos');

-- ---------------------------------------------------------------------
-- Asignacion de permisos por rol
-- ---------------------------------------------------------------------
-- ADMIN: todos los permisos
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r CROSS JOIN permisos p
 WHERE r.codigo = 'ADMIN';

-- GERENTE: gestion comercial completa + reportes
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r JOIN permisos p ON 1 = 1
 WHERE r.codigo = 'GERENTE'
   AND p.modulo IN ('CLIENTES','REPORTES')
   AND p.accion <> 'ELIMINAR';

-- VENDEDOR: atencion de clientes y ventas
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r JOIN permisos p ON 1 = 1
 WHERE r.codigo = 'VENDEDOR'
   AND ( (p.modulo = 'CLIENTES' AND p.accion IN ('VER','CREAR','EDITAR','COTIZAR','ASIGNAR'))
      OR (p.modulo = 'VENTAS'   AND p.accion IN ('VER','CREAR','CONFIRMAR'))
      OR (p.modulo = 'PRODUCTOS' AND p.accion = 'VER')
      OR (p.modulo = 'PROVEEDORES' AND p.accion = 'VER')
      OR (p.modulo = 'INVENTARIO' AND p.accion = 'VER')
      OR (p.modulo = 'REPORTES' AND p.accion IN ('VER','GENERAR')) );

-- COMPRAS: proveedores, compras e inventario
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r JOIN permisos p ON 1 = 1
 WHERE r.codigo = 'COMPRAS'
   AND ( (p.modulo = 'PROVEEDORES' AND p.accion <> 'ELIMINAR')
      OR (p.modulo = 'COMPRAS' AND p.accion <> 'ANULAR')
      OR (p.modulo = 'PRODUCTOS' AND p.accion IN ('VER','CREAR','EDITAR'))
      OR (p.modulo = 'INVENTARIO' AND p.accion IN ('VER','INGRESAR','REPOSICION'))
      OR (p.modulo = 'REPORTES' AND p.accion = 'VER') );

-- ALMACENERO: stock y movimientos
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r JOIN permisos p ON 1 = 1
 WHERE r.codigo = 'ALMACENERO'
   AND ( (p.modulo = 'INVENTARIO')
      OR (p.modulo = 'PRODUCTOS' AND p.accion = 'VER')
      OR (p.modulo = 'COMPRAS' AND p.accion IN ('VER','RECEPCION')) );

-- CONTADOR: operaciones y comprobantes
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r JOIN permisos p ON 1 = 1
 WHERE r.codigo = 'CONTADOR'
   AND ( (p.modulo = 'VENTAS' AND p.accion = 'VER')
      OR (p.modulo = 'COMPRAS' AND p.accion = 'VER')
      OR (p.modulo = 'CLIENTES' AND p.accion IN ('VER','BLOQUEAR'))
      OR (p.modulo = 'REPORTES') );

-- ATENCION AL CLIENTE: reclamos y datos de clientes
INSERT IGNORE INTO roles_permisos (id_roles, id_permisos)
SELECT r.id_roles, p.id_permisos FROM roles r JOIN permisos p ON 1 = 1
 WHERE r.codigo = 'ATENCION'
   AND ( (p.modulo = 'CLIENTES' AND p.accion IN ('VER','CREAR','EDITAR','RECLAMOS','BLOQUEAR','INVESTIGAR'))
      OR (p.modulo = 'VENTAS' AND p.accion = 'VER')
      OR (p.modulo = 'PRODUCTOS' AND p.accion = 'VER')
      OR (p.modulo = 'REPORTES' AND p.accion = 'VER') );

-- ---------------------------------------------------------------------
-- Usuario administrador
-- Clave inicial: "password" (bcrypt). requiere_cambio_clave = 1
-- ---------------------------------------------------------------------
INSERT IGNORE INTO usuarios
  (codigo, usuario, email, password_hash, nombre, apellido, cargo, activo, requiere_cambio_clave)
VALUES
  ('USR-001','admin','admin@sima.local',
   '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.',
   'Administrador','Sistema','Administrador del sistema',1,1);

INSERT IGNORE INTO usuarios_roles (id_usuarios, id_roles)
SELECT u.id_usuarios, r.id_roles
  FROM usuarios u JOIN roles r ON r.codigo = 'ADMIN'
 WHERE u.usuario = 'admin';

-- ---------------------------------------------------------------------
-- Reglas de negocio transversales
-- ---------------------------------------------------------------------
-- No permitir eliminar el ultimo usuario administrador activo.
DROP TRIGGER IF EXISTS trg_usuarios_no_baja_admin;

DELIMITER $$
CREATE TRIGGER trg_usuarios_no_baja_admin
BEFORE UPDATE ON usuarios
FOR EACH ROW
BEGIN
  IF OLD.eliminado = 0 AND NEW.eliminado = 1 THEN
    IF (SELECT COUNT(*)
          FROM usuarios u
          JOIN usuarios_roles ur ON ur.id_usuarios = u.id_usuarios
          JOIN roles r ON r.id_roles = ur.id_roles
         WHERE r.codigo = 'ADMIN' AND u.eliminado = 0 AND u.activo = 1 AND u.id_usuarios <> NEW.id_usuarios) = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar el ultimo usuario administrador activo';
    END IF;
  END IF;
END$$
DELIMITER ;

-- Auditoria automatica de cambios en productos (modificacion / baja).
DROP TRIGGER IF EXISTS trg_productos_auditoria;

DELIMITER $$
CREATE TRIGGER trg_productos_auditoria
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
  IF NOT (OLD.activo <=> NEW.activo AND OLD.dado_de_baja <=> NEW.dado_de_baja
          AND OLD.precio_venta <=> NEW.precio_venta AND OLD.precio_costo <=> NEW.precio_costo
          AND OLD.stock_minimo <=> NEW.stock_minimo AND OLD.rop <=> NEW.rop AND OLD.rp <=> NEW.rp
          AND OLD.nombre <=> NEW.nombre AND OLD.lt_dias <=> NEW.lt_dias
          AND OLD.cantidad_inicial <=> NEW.cantidad_inicial) THEN
    INSERT INTO productos_historial (id_productos, id_usuarios, datos_anteriores, datos_nuevos, comentario)
    VALUES (
      NEW.id_productos,
      NEW.baja_por,
      JSON_OBJECT('activo', OLD.activo, 'dado_de_baja', OLD.dado_de_baja, 'nombre', OLD.nombre,
                  'precio_venta', OLD.precio_venta, 'precio_costo', OLD.precio_costo,
                  'stock_minimo', OLD.stock_minimo, 'rop', OLD.rop, 'rp', OLD.rp,
                  'lt_dias', OLD.lt_dias, 'cantidad_inicial', OLD.cantidad_inicial),
      JSON_OBJECT('activo', NEW.activo, 'dado_de_baja', NEW.dado_de_baja, 'nombre', NEW.nombre,
                  'precio_venta', NEW.precio_venta, 'precio_costo', NEW.precio_costo,
                  'stock_minimo', NEW.stock_minimo, 'rop', NEW.rop, 'rp', NEW.rp,
                  'lt_dias', NEW.lt_dias, 'cantidad_inicial', NEW.cantidad_inicial),
      'Actualizacion automatica de producto'
    );
  END IF;
END$$
DELIMITER ;

-- Validar stock antes de permitir la baja de un producto.
DROP TRIGGER IF EXISTS trg_productos_baja_validacion;

DELIMITER $$
CREATE TRIGGER trg_productos_baja_validacion
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
  IF OLD.dado_de_baja = 0 AND NEW.dado_de_baja = 1 THEN
    IF (SELECT COALESCE(SUM(cantidad), 0) FROM inventario_stock WHERE id_productos = NEW.id_productos) > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no puede dadas de baja: tiene stock en almacen';
    END IF;
  END IF;
END$$
DELIMITER ;
