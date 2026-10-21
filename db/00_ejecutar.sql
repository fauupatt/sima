-- =====================================================================
-- SIMA  |  Script principal de instalacion
--
-- Uso (desde la raiz del repositorio):
--   mysql -u root -p < db/00_ejecutar.sql
--
-- ATENCION: este script DROPea y recrea la base de datos "sima".
-- Para una instalacion sobre una base existente, ejecutar los archivos
-- 01..07 en orden manualmente (sin el DROP).
-- =====================================================================

DROP DATABASE IF EXISTS sima;

SOURCE db/01_esquema.sql;
SOURCE db/02_catalogos.sql;
SOURCE db/03_clientes.sql;
SOURCE db/04_operaciones.sql;
SOURCE db/05_vistas.sql;
SOURCE db/06_procedimientos.sql;
SOURCE db/07_datos_iniciales.sql;

SELECT 'SIMA: instalacion completada' AS resultado,
       (SELECT COUNT(*) FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = 'sima' AND TABLE_TYPE = 'BASE TABLE') AS tablas,
       (SELECT COUNT(*) FROM information_schema.VIEWS
         WHERE TABLE_SCHEMA = 'sima') AS vistas,
       (SELECT COUNT(*) FROM information_schema.ROUTINES
         WHERE ROUTINE_SCHEMA = 'sima' AND ROUTINE_TYPE = 'PROCEDURE') AS procedimientos,
       (SELECT COUNT(*) FROM information_schema.TRIGGERS
         WHERE TRIGGER_SCHEMA = 'sima') AS triggers;
