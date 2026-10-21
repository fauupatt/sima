-- =====================================================================
-- SIMA  |  Vistas de consulta y reporting
--   Reportes de clientes (filtros por datos/periodos)
--   Consultar operaciones (compras / ventas)
--   Control de stock y reposicion (ROP / RP)
--   Actividad comercial del cliente
-- =====================================================================

USE sima;

-- ---------------------------------------------------------------------
-- Stock actual valorizado por producto / almacen / lote
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_stock_actual AS
SELECT
  s.id_almacenes,
  a.nombre                                        AS almacen,
  s.id_productos,
  p.sku,
  p.nombre                                        AS producto,
  c.nombre                                        AS categoria,
  s.id_lotes,
  l.codigo_lote,
  l.fecha_vencimiento,
  s.cantidad,
  s.cantidad_reservada,
  (s.cantidad - s.cantidad_reservada)             AS cantidad_disponible,
  s.stock_minimo,
  s.rop,
  s.rp,
  s.costo_promedio,
  ROUND(s.cantidad * s.costo_promedio, 2)         AS valor_stock,
  s.ultimo_movimiento
FROM inventario_stock s
INNER JOIN productos   p ON p.id_productos = s.id_productos
INNER JOIN almacenes   a ON a.id_almacenes = s.id_almacenes
LEFT  JOIN categorias c ON c.id_categorias = p.id_categorias
LEFT  JOIN lotes       l ON l.id_lotes      = s.id_lotes;

-- ---------------------------------------------------------------------
-- Productos por debajo del punto de reposicion (ROP) -> candidatas a reposicion
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_productos_bajo_minimo AS
SELECT
  s.id_almacenes,
  a.nombre                                        AS almacen,
  s.id_productos,
  p.sku,
  p.nombre                                        AS producto,
  COALESCE(s.stock_minimo, pol.stock_minimo, p.stock_minimo) AS stock_minimo,
  COALESCE(s.rop, pol.rop, p.rop)                 AS rop,
  COALESCE(s.rp, pol.rp, p.rp)                    AS rp,
  pol.cantidad_pedido,
  SUM(s.cantidad)                                 AS stock_actual,
  COALESCE(s.cantidad, 0) - COALESCE(s.rop, 0)   AS deficit,
  CASE
    WHEN pol.cantidad_pedido IS NOT NULL THEN pol.cantidad_pedido
    WHEN pol.rp IS NOT NULL THEN pol.rp
    ELSE GREATEST(COALESCE(s.rop, 0) - COALESCE(s.cantidad, 0), 0)
  END                                             AS cantidad_sugerida,
  pol.id_proveedores,
  pr.razon_social                                 AS proveedor,
  p.id_proveedor_habitual
FROM inventario_stock s
INNER JOIN productos p ON p.id_productos = s.id_productos
INNER JOIN almacenes a ON a.id_almacenes = s.id_almacenes
LEFT  JOIN inventario_politicas pol
       ON pol.id_productos = s.id_productos AND pol.id_almacenes = s.id_almacenes
LEFT  JOIN proveedores pr ON pr.id_proveedores = COALESCE(pol.id_proveedores, p.id_proveedor_habitual)
WHERE p.activo = 1
  AND p.dado_de_baja = 0
  AND (s.rop IS NOT NULL OR pol.rop IS NOT NULL OR p.rop IS NOT NULL)
GROUP BY
  s.id_almacenes, a.nombre, s.id_productos, p.sku, p.nombre,
  s.stock_minimo, pol.stock_minimo, p.stock_minimo,
  s.rop, pol.rop, p.rop, s.rp, pol.rp, p.rp,
  pol.cantidad_pedido, pol.id_proveedores, pr.razon_social, p.id_proveedor_habitual
HAVING SUM(s.cantidad) <= COALESCE(s.rop, pol.rop, p.rop, 0);

-- ---------------------------------------------------------------------
-- Consultar operaciones: compras y ventas unificadas (filtro por periodo)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_operaciones AS
SELECT
  'COMPRA'                                        AS tipo_operacion,
  c.id_compras                                     AS id_operacion,
  c.numero,
  c.fecha_emision                                  AS fecha,
  c.id_proveedores                                 AS id_contraparte,
  pr.razon_social                                  AS contraparte,
  c.total,
  c.moneda,
  c.id_usuarios,
  u.nombre                                         AS usuario,
  ec.nombre                                        AS estado,
  c.observaciones
FROM compras c
INNER JOIN proveedores      pr ON pr.id_proveedores = c.id_proveedores
INNER JOIN estados_compra   ec ON ec.id_estados_compra = c.id_estados_compra
INNER JOIN usuarios         u  ON u.id_usuarios    = c.id_usuarios
UNION ALL
SELECT
  'VENTA'                                         AS tipo_operacion,
  v.id_ventas                                     AS id_operacion,
  v.numero,
  v.fecha_venta                                    AS fecha,
  v.id_clientes                                    AS id_contraparte,
  cl.razon_social                                  AS contraparte,
  v.total,
  v.moneda,
  v.id_usuarios,
  u.nombre                                         AS usuario,
  ev.nombre                                        AS estado,
  v.observaciones
FROM ventas v
INNER JOIN clientes       cl ON cl.id_clientes  = v.id_clientes
INNER JOIN estados_venta  ev ON ev.id_estados_venta = v.id_estados_venta
INNER JOIN usuarios       u  ON u.id_usuarios   = v.id_usuarios;

-- ---------------------------------------------------------------------
-- Ficha integral del cliente (datos + lista de precios + condicion + zona/vendedor)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_clientes_detalle AS
SELECT
  cl.id_clientes,
  cl.codigo,
  cl.razon_social,
  cl.nombre_fantasia,
  cl.tipo_documento,
  cl.nro_documento,
  cl.email,
  cl.telefono,
  cl.ciudad,
  cl.provincia,
  cl.estado,
  cl.origen,
  cl.fecha_alta,
  cl.bloqueado_compra,
  cl.motivo_bloqueo,
  cl.saldo_deuda,
  cl.limite_credito,
  lp.nombre                                        AS lista_precios,
  lp.tipo                                          AS tipo_lista_precios,
  cc.nombre                                        AS condicion_comercial,
  cc.plazo_pago_dias,
  cc.descuento_pct                                 AS descuento_comercial,
  z.nombre                                         AS zona,
  v.nombre                                         AS vendedor,
  v.codigo                                         AS codigo_vendedor,
  (SELECT COUNT(*) FROM cotizaciones ct WHERE ct.id_clientes = cl.id_clientes)  AS cotizaciones,
  (SELECT COUNT(*) FROM ventas       vt WHERE vt.id_clientes = cl.id_clientes)  AS ventas,
  (SELECT COALESCE(SUM(vt.total), 0) FROM ventas vt WHERE vt.id_clientes = cl.id_clientes) AS total_vendido,
  (SELECT COUNT(*) FROM reclamos r WHERE r.id_clientes = cl.id_clientes)      AS reclamos
FROM clientes cl
LEFT JOIN listas_precios lp
       ON lp.id_listas_precios = COALESCE(cl.id_listas_precios,
            (SELECT id_listas_precios FROM clientes_listas_precios
              WHERE id_clientes = cl.id_clientes AND fecha_hasta IS NULL
              ORDER BY es_principal DESC, fecha_desde DESC LIMIT 1))
LEFT JOIN condiciones_comerciales cc
       ON cc.id_condiciones_comerciales = COALESCE(cl.id_condicion_comercial,
            (SELECT id_condicion_comercial FROM clientes_condiciones_comerciales
              WHERE id_clientes = cl.id_clientes AND fecha_hasta IS NULL
              ORDER BY fecha_desde DESC LIMIT 1))
LEFT JOIN asignaciones_clientes ac
       ON ac.id_clientes = cl.id_clientes AND ac.fecha_hasta IS NULL
LEFT JOIN zonas      z ON z.id_zonas      = ac.id_zonas
LEFT JOIN vendedores v ON v.id_vendedores = ac.id_vendedores;

-- ---------------------------------------------------------------------
-- Clientes bloqueados por deuda
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_clientes_bloqueados AS
SELECT
  cl.id_clientes,
  cl.codigo,
  cl.razon_social,
  cl.email,
  cl.telefono,
  cl.bloqueado_compra,
  cl.motivo_bloqueo,
  cl.bloqueado_en,
  u.nombre                                         AS bloqueado_por,
  COALESCE(SUM(d.saldo), 0)                       AS saldo_vencido,
  MIN(d.fecha_vencimiento)                        AS vencimiento_mas_antiguo,
  MAX(TIMESTAMPDIFF(DAY, d.fecha_vencimiento, CURDATE())) AS dias_vencimiento_max,
  b.id_bloqueos_clientes,
  b.estado                                        AS estado_bloqueo,
  n.estado                                        AS estado_notificacion,
  n.fecha_envio                                   AS notificacion_enviada
FROM clientes cl
LEFT JOIN bloqueos_clientes b
       ON b.id_clientes = cl.id_clientes AND b.estado = 'ACTIVO'
LEFT JOIN usuarios u ON u.id_usuarios = cl.bloqueado_por
LEFT JOIN clientes_deudas d
       ON d.id_clientes = cl.id_clientes AND d.estado = 'VENCIDO'
LEFT JOIN notificaciones n
       ON n.id_bloqueos_clientes = b.id_bloqueos_clientes
WHERE cl.bloqueado_compra = 1
GROUP BY cl.id_clientes, cl.codigo, cl.razon_social, cl.email, cl.telefono,
         cl.bloqueado_compra, cl.motivo_bloqueo, cl.bloqueado_en, u.nombre,
         b.id_bloqueos_clientes, b.estado, n.estado, n.fecha_envio;

-- ---------------------------------------------------------------------
-- Actividad comercial del cliente (ventas + cotizaciones + investigacion)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_actividad_comercial_cliente AS
SELECT
  cl.id_clientes,
  cl.razon_social,
  'VENTA'                                        AS tipo_actividad,
  v.numero                                       AS referencia,
  v.fecha_venta                                  AS fecha,
  v.total                                        AS monto,
  ev.nombre                                      AS estado,
  u.nombre                                       AS responsable
FROM ventas v
INNER JOIN clientes      cl ON cl.id_clientes = v.id_clientes
INNER JOIN estados_venta ev ON ev.id_estados_venta = v.id_estados_venta
INNER JOIN usuarios      u  ON u.id_usuarios  = v.id_usuarios
UNION ALL
SELECT
  cl.id_clientes,
  cl.razon_social,
  'COTIZACION',
  ct.numero,
  ct.fecha_emision,
  ct.total,
  ec.nombre,
  u.nombre
FROM cotizaciones ct
INNER JOIN clientes            cl ON cl.id_clientes = ct.id_clientes
INNER JOIN estados_cotizacion  ec ON ec.id_estados_cotizacion = ct.id_estados_cotizacion
INNER JOIN usuarios            u  ON u.id_usuarios  = ct.id_usuarios
UNION ALL
SELECT
  cl.id_clientes,
  cl.razon_social,
  'RECLAMO',
  r.numero,
  r.fecha_recepcion,
  r.monto_reclamado,
  er.nombre,
  u.nombre
FROM reclamos r
INNER JOIN clientes        cl ON cl.id_clientes = r.id_clientes
INNER JOIN estados_reclamo er ON er.id_estados_reclamo = r.id_estados_reclamo
INNER JOIN usuarios        u  ON u.id_usuarios  = r.id_usuarios_registro;

-- ---------------------------------------------------------------------
-- Metricas de reclamos por motivo de cierre (base del reporte de gestion)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_reclamos_metricas AS
SELECT
  mc.id_motivos_cierre_reclamo,
  mc.codigo                                        AS motivo_codigo,
  mc.nombre                                        AS motivo,
  mc.categoria,
  tr.codigo                                        AS tipo_codigo,
  tr.nombre                                        AS tipo,
  COUNT(r.id_reclamos)                             AS cantidad_reclamos,
  SUM(r.monto_reclamado)                           AS monto_total,
  AVG(TIMESTAMPDIFF(HOUR, r.fecha_recepcion, r.fecha_cierre)) AS horas_promedio_resolucion,
  SUM(CASE WHEN r.devolucion_autorizada = 1 THEN 1 ELSE 0 END) AS devoluciones_autorizadas
FROM motivos_cierre_reclamo mc
LEFT JOIN reclamos r         ON r.id_motivo_cierre = mc.id_motivos_cierre_reclamo
LEFT JOIN tipos_reclamo tr    ON tr.id_tipos_reclamo = r.id_tipos_reclamo
GROUP BY mc.id_motivos_cierre_reclamo, mc.codigo, mc.nombre, mc.categoria, tr.codigo, tr.nombre;

-- ---------------------------------------------------------------------
-- Comisiones por vendedor (liquidacion)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_comisiones_vendedor AS
SELECT
  v.id_vendedores,
  v.codigo                                         AS codigo_vendedor,
  v.nombre                                         AS vendedor,
  c.periodo,
  c.tipo,
  COUNT(c.id_comisiones)                           AS cantidad_comisiones,
  SUM(c.base)                                      AS base_total,
  AVG(c.porcentaje)                                AS porcentaje_promedio,
  SUM(c.monto)                                     AS monto_total,
  SUM(CASE WHEN c.estado = 'PAGADA' THEN c.monto ELSE 0 END) AS monto_pagado,
  SUM(CASE WHEN c.estado IN ('CALCULADA','APROBADA') THEN c.monto ELSE 0 END) AS monto_pendiente
FROM comisiones c
INNER JOIN vendedores v ON v.id_vendedores = c.id_vendedores
GROUP BY v.id_vendedores, v.codigo, v.nombre, c.periodo, c.tipo;

-- ---------------------------------------------------------------------
-- Trazabilidad de movimientos por producto (entradas / salidas / ajustes)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_movimientos_producto AS
SELECT
  m.id_inventario_movimientos,
  m.fecha_movimiento,
  m.tipo_movimiento,
  m.id_productos,
  p.sku,
  p.nombre                                        AS producto,
  m.id_almacenes,
  a.nombre                                        AS almacen,
  m.id_lotes,
  l.codigo_lote,
  m.cantidad,
  m.cantidad_previa,
  m.cantidad_posterior,
  m.costo_unitario,
  m.documento_tipo,
  m.documento_numero,
  m.motivo,
  u.nombre                                         AS usuario
FROM inventario_movimientos m
INNER JOIN productos p ON p.id_productos = m.id_productos
INNER JOIN almacenes a ON a.id_almacenes = m.id_almacenes
LEFT  JOIN lotes     l ON l.id_lotes      = m.id_lotes
INNER JOIN usuarios  u ON u.id_usuarios  = m.id_usuarios;
