# sima

Proyecto Sima.

## Base de datos (MariaDB)

El modelo de datos de los modulos de **Gestion de Clientes**, **Gestion de Usuarios**,
**Gestion de Compras**, **Gestion de Proveedores**, **Gestion de Ventas**,
**Gestion de Productos** y **Gestion de Inventario** esta en [`db/`](db/README.md).

```bash
mysql -u root -p < db/00_ejecutar.sql
```

Incluye 63 tablas, 9 vistas, 9 procedimientos almacenados y 3 triggers de negocio.
La documentacion del mapeo flujo -> tabla esta en [`db/README.md`](db/README.md).
