# Base de datos SIMA (MariaDB 10.5+)

Modelado de almacenamiento de los flujos de los modulos **Gestion de Clientes**,
**Gestion de Usuarios**, **Gestion de Compras**, **Gestion de Proveedores**,
**Gestion de Ventas**, **Gestion de Productos** y **Gestion de Inventario**.

## Instalacion

Desde la raiz del repositorio:

```bash
mysql -u root -p < db/00_ejecutar.sql
```

El script principal dropea y recrea la base `sima`. Para instalar sobre una base
existente, ejecutar los archivos `01`..`07` en orden.

Clave inicial del administrador: `password` (bcrypt). El usuario `admin` queda con
`requiere_cambio_clave = 1`, por lo que la aplicacion debe forzar el cambio en el
primer inicio de sesion.

## Archivos

| Archivo | Contenido |
|---|---|
| `00_ejecutar.sql` | Script principal (drop + create + carga) |
| `01_esquema.sql` | Nucleo: catalogos base, usuarios/roles/permisos, sesiones, auditoria |
| `02_catalogos.sql` | Proveedores, productos, lotes, almacenes, zonas, vendedores, listas de precios, condiciones comerciales, clientes |
| `03_clientes.sql` | Prospectos, asignaciones, cotizaciones, investigaciones, reclamos, bloqueos, deudas, notificaciones, reportes |
| `04_operaciones.sql` | Inventario (stock, movimientos, ROP/RP, reposiciones), compras, recepciones, presupuestos, ventas, comprobantes, comisiones |
| `05_vistas.sql` | Vistas de consulta y reporting |
| `06_procedimientos.sql` | Procedimientos almacenados de los flujos |
| `07_datos_iniciales.sql` | Catalogos, roles, permisos, admin, triggers de negocio |

## Mapeo flujo -> almacenamiento

### Modulo Gestion de Clientes

| Flujo | Paso | Tablas |
|---|---|---|
| Registro de cliente | Prospecto solicita cotizacion | `prospectos` |
| | Validacion de existencia / alta en Gestion de clientes | `clientes` (unicidad por `tipo_documento` + `nro_documento`), `sp_registrar_cliente` |
| | Carga de datos (razon social / nombre / datos) | `clientes` |
| | Asignacion de lista de precios | `listas_precios`, `listas_precios_items`, `clientes_listas_precios` |
| | Asignacion de condicion comercial | `condiciones_comerciales`, `clientes_condiciones_comerciales` |
| | Emision de cotizacion ligada a productos | `cotizaciones`, `cotizaciones_items` |
| | Carga de estado del proceso | `estados_cotizacion`, `cotizaciones_estados_historial` |
| Asignacion a vendedores | Revision de clientes por zona | `zonas`, `asignaciones_clientes` |
| | Asignacion de zona o vendedor | `asignaciones_clientes.tipo_asignacion` |
| | Configuracion de comisiones | `asignaciones_clientes.comision_pct`, `vendedores`, `comisiones` |
| Reportes de clientes | Filtro por datos / periodos | `reportes.parametros` (JSON), `vw_clientes_detalle` |
| | Generacion de documento excel | `reportes.tipo`, `reportes.archivo_path` |
| | Generacion de graficos | `reportes.tipo = 'GRAFICO'`, `vw_actividad_comercial_cliente`, `vw_comisiones_vendedor` |
| Investigacion de cliente | Seleccion de cliente | `investigaciones.id_clientes` |
| | Busqueda de informacion en la web | `investigaciones` (consulta, fuente, fecha) |
| | Resultados sobre actividad comercial | `investigacion_resultados`, `investigacion_actividad_comercial` |
| Gestion de reclamos | Recepcion | `reclamos` (canal, fecha_recepcion, id_usuarios_registro) |
| | Registro del reclamo (detalles) | `reclamos.descripcion`, `reclamos_detalles` |
| | Autorizacion de devolucion | `reclamos_devoluciones`, `reclamos.devolucion_autorizada*` |
| | Asignacion de responsable | `reclamos.id_usuarios_responsable`, `reclamos_historial` |
| | Cierre con motivo (metricas) | `reclamos.id_motivo_cierre`, `motivos_cierre_reclamo`, `vw_reclamos_metricas` |
| Bloqueo por deuda | Eleccion del cliente | `clientes_deudas` (vencidas) |
| | Confirmacion | `sp_bloquear_cliente` |
| | Bloqueo de compra | `clientes.bloqueado_compra`, `bloqueos_clientes` |
| | Notificacion a cliente | `notificaciones` (tipo `BLOQUEO_COMPRA`) |

### Modulo Gestion de Usuarios

| Flujo | Paso | Tablas |
|---|---|---|
| Autenticacion | Ingreso de credenciales | `intentos_autenticacion` |
| | Validacion de password y rol | `usuarios.password_hash`, `usuarios_roles`, `roles`, `roles_permisos`, `sp_autenticar_usuario` |
| | Otorgar o denegar acceso a modulos | `permisos` (modulo x accion), `usuarios_permisos` (ALLOW/DENY), `sesiones` |
| Gestion de usuario | Modificar datos / permisos / accesos | `usuarios`, `usuarios_roles`, `usuarios_permisos` |
| | Validar y actualizar | `auditoria` (trigger / SP) |
| Eliminacion de usuario | Seleccion, eliminacion, confirmacion | `usuarios.eliminado` (baja logica), `sp_eliminar_usuario`, trigger `trg_usuarios_no_baja_admin` |

### Modulo Gestion de Compras

| Flujo | Paso | Tablas |
|---|---|---|
| Registro de compras | Seleccionar proveedor | `proveedores`, `compras.id_proveedores` |
| | Seleccionar productos | `compras_items` |
| | Registrar compra | `compras`, `compras_items`, `estados_compra` |
| | Actualizar stock | `sp_movimiento_stock` -> `inventario_stock`, `inventario_movimientos` |

### Modulo Gestion de Proveedores

| Flujo | Paso | Tablas |
|---|---|---|
| Registro de proveedores | Alta y carga de datos | `proveedores` |
| | Validacion | `proveedores.estado`, `proveedores_estados` (historial) |
| | Proveedor registrado | `proveedores.estado = 'VALIDADO'` |

### Modulo Gestion de Ventas

| Flujo | Paso | Tablas |
|---|---|---|
| Consultar operaciones | Seleccionar periodo / filtro | `vw_operaciones` (compras + ventas unificadas) |
| | Consultar compras / ventas | `vw_operaciones`, `compras`, `ventas` |
| | Mostrar resultados | `vw_operaciones` |
| Registro de ventas | Cliente solicita producto | `presupuestos`, `presupuestos_items` |
| | Verificar stock | `inventario_stock`, `vw_stock_actual` |
| | Generacion de presupuesto | `presupuestos`, `presupuestos_items` |
| | Confirmacion | `presupuestos.estado`, `estados_venta` |
| | Registrar venta y descontar stock | `sp_registrar_venta`, `ventas`, `ventas_items`, `inventario_movimientos` |
| | Generar comprobante | `comprobantes` |

### Modulo Gestion de Productos

| Flujo | Paso | Tablas |
|---|---|---|
| Alta de productos | Carga de datos (sku, cantidad, lt, ...) | `productos` (sku, cantidad_inicial, lt_dias, vida_util_dias, ...) |
| | Validacion | `productos.activo`, `sku` unico |
| | Producto registrado | `productos` |
| Modificacion de producto | Seleccionar, modificar, validar, actualizar | `productos`, `productos_historial` (trigger) |
| Baja de producto | Seleccionar productos | `productos` |
| | Verificar uso / stock | trigger `trg_productos_baja_validacion` |
| | Dar de baja | `productos.dado_de_baja`, `fecha_baja`, `motivo_baja`, `stock_en_baja` |

### Modulo Gestion de Inventario

| Flujo | Paso | Tablas |
|---|---|---|
| Control de stock | Consultar stock | `inventario_stock`, `vw_stock_actual` |
| | Comparar con stock minimo (ROP, RP) | `inventario_politicas`, `productos.rop/rp/stock_minimo`, `vw_productos_bajo_minimo` |
| | Generar reposicion | `sp_evaluar_reposiciones`, `reposiciones`, `reposiciones_detalle` |
| Movimientos de inventario | Seleccionar producto, consultar movimientos | `inventario_movimientos`, `vw_movimientos_producto` |
| | Mostrar entradas / salidas / ajustes | `inventario_movimientos.tipo_movimiento` |
| Ingreso de stock | Recepcion de compra, verificar productos | `recepciones_compra`, `recepciones_items` |
| | Ingresar mercaderia | `sp_movimiento_stock('ENTRADA', ...)` |
| | Actualizar stock | `inventario_stock` |
| Salida de stock | Venta, verificar disponibilidad | `sp_registrar_venta` (valida stock) |
| | Entregar producto | `ventas_items`, `inventario_movimientos` |
| | Actualizar stock | `inventario_stock` |
| Ajuste | Detectar diferencia, registrar ajuste | `sp_movimiento_stock('AJUSTE', ...)` con cantidad con signo |
| | Actualizar stock | `inventario_stock` |

## Procedimientos almacenados

| Procedimiento | Proposito |
|---|---|
| `sp_movimiento_stock` | Entrada / salida / ajuste de stock (punto de entrada transaccional) |
| `sp_registrar_movimiento_inventario` | Logica de movimiento sin control transaccional (uso interno) |
| `sp_evaluar_reposiciones` | Compara stock contra ROP y genera reposiciones por proveedor |
| `sp_registrar_venta` | Registra la venta, descuenta stock, genera comprobante y calcula comision |
| `sp_registrar_cliente` | Convierte un prospecto en cliente con lista de precios, condicion y asignacion |
| `sp_bloquear_cliente` | Bloquea la compra por deuda y genera la notificacion |
| `sp_cerrar_reclamo` | Cierra el reclamo con motivo (metrica de gestion) |
| `sp_autenticar_usuario` | Valida credenciales y rol, registra el intento y concede o deniega acceso |
| `sp_eliminar_usuario` | Baja logica de usuario y cierre de sus sesiones |

## Vistas

| Vista | Proposito |
|---|---|
| `vw_stock_actual` | Stock valorizado por producto / almacen / lote |
| `vw_productos_bajo_minimo` | Productos en o por debajo del ROP con cantidad sugerida (RP) |
| `vw_operaciones` | Compras y ventas unificadas para el reporte de operaciones |
| `vw_clientes_detalle` | Ficha integral del cliente con lista, condicion, zona, vendedor y totales |
| `vw_clientes_bloqueados` | Clientes bloqueados por deuda y estado de la notificacion |
| `vw_actividad_comercial_cliente` | Actividad comercial del cliente (ventas, cotizaciones, reclamos) |
| `vw_reclamos_metricas` | Reclamos agrupados por motivo de cierre (metricas de gestion) |
| `vw_comisiones_vendedor` | Liquidacion de comisiones por vendedor y periodo |
| `vw_movimientos_producto` | Trazabilidad de movimientos por producto |

## Notas de implementacion

- La numeracion de comprobantes (`ventas.numero`, `cotizaciones.numero`) se genera
  por conteo diario. En alta concurrencia conviene reemplazarla por una secuencia
  (`SEQUENCE` en MariaDB 10.3+ o tabla de correlativos con `LOCK`).
- `sp_registrar_venta` recibe los items como JSON:
  `[{"id_productos":1,"cantidad":2,"precio_unitario":100,"descuento_pct":0,"id_lotes":null}]`
- La validacion de password en `sp_autenticar_usuario` compara el hash recibido
  contra `usuarios.password_hash`; el algoritmo (bcrypt/argon2) es responsabilidad
  de la aplicacion.
- Los triggers `trg_productos_baja_validacion` y `trg_usuarios_no_baja_admin`
  protegen reglas de negocio que no pueden depender solo de la UI.
