-- ==============================================================================
-- TALLER PRÁCTICO: OPTIMIZACIÓN DE CONSULTAS Y RENDIMIENTO EN MYSQL (BancoDB)
-- ==============================================================================
-- Objetivo: Que los estudiantes diagnostiquen consultas lentas usando EXPLAIN ANALYZE,
-- identifiquen lecturas completas de tabla (Table Scans), reescriban consultas
-- de forma sargable y apliquen índices compuestos y cubrientes sobre la base de datos bancaria.
-- ==============================================================================

USE BancoDB;

-- ------------------------------------------------------------------------------
-- PARTE 0: ESTRUCTURA DE TABLAS E POBLAMIENTO DE DATOS MASIVOS
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS impuestos_gmf;
DROP TABLE IF EXISTS historial_transferencias;
DROP TABLE IF EXISTS cuentas;

CREATE TABLE cuentas (
    id_cuenta INT PRIMARY KEY AUTO_INCREMENT,
    titular VARCHAR(100) NOT NULL,
    tipo_cuenta VARCHAR(20) NOT NULL DEFAULT 'Ahorros',
    saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    estado VARCHAR(20) NOT NULL DEFAULT 'Activa',
    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE historial_transferencias (
    id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
    cuenta_origen INT NOT NULL,
    cuenta_destino INT NOT NULL,
    monto DECIMAL(12, 2) NOT NULL,
    estado_transferencia VARCHAR(20) NOT NULL DEFAULT 'Exitosa',
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cuenta_origen) REFERENCES cuentas(id_cuenta),
    FOREIGN KEY (cuenta_destino) REFERENCES cuentas(id_cuenta)
);

-- Procedimiento auxiliar para generar un volumen masivo de prueba (para notar diferencias de tiempo)
DELIMITER //
CREATE PROCEDURE CargarDatosPrueba()
BEGIN
    DECLARE i INT DEFAULT 1;

    -- Insertar 1,000 cuentas
    WHILE i <= 1000 DO
        INSERT INTO cuentas (titular, tipo_cuenta, saldo, estado, fecha_apertura)
        VALUES (
            CONCAT('Cliente_', i),
            IF(i % 2 = 0, 'Ahorros', 'Corriente'),
            ROUND(RAND() * 10000000, 2),
            IF(i % 10 = 0, 'Bloqueada', 'Activa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
    END WHILE;

    -- Insertar 10,000 transferencias
    SET i = 1;
    WHILE i <= 10000 DO
        INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto, estado_transferencia, fecha)
        VALUES (
            FLOOR(1 + RAND() * 999),
            FLOOR(1 + RAND() * 999),
            ROUND(1000 + RAND() * 500000, 2),
            IF(i % 15 = 0, 'Fallida', 'Exitosa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 180) DAY)
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

-- Ejecutar la carga masiva
CALL CargarDatosPrueba();
DROP PROCEDURE IF EXISTS CargarDatosPrueba;


-- ==============================================================================
-- PARTE 1: DEMOSTRACIÓN GUIADA EN CLASE (PROFESOR)
-- ==============================================================================

-- PROBLEMA: Búsqueda de transferencias por estado y rango de fechas sin índice secundario.
-- Analizar el costo de ejecución antes de optimizar:
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';
-- RESULTADO: Table scan on historial_transferencias (cost=1006 rows=9986) rows=10000
-- DIAGNÓSTICO: Se observa 'Table scan' y un costo alto porque no existe índice secundario aún.

-- SOLUCIÓN DEMOSTRATIVA: Crear índice compuesto ordenado por discriminación.
CREATE INDEX idx_transf_estado_fecha ON historial_transferencias(estado_transferencia, fecha);

-- RE-EVALUACIÓN con 'Exitosa' (baja selectividad, ~93% de las filas):
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';
-- RESULTADO: Sigue siendo Table scan (cost=1038 rows=10142, rows leídas=10000).
-- CONCLUSIÓN: El índice existe pero el optimizador lo descarta porque 'Exitosa' representa
-- ~93% de los datos; para ese volumen es más barato leer toda la tabla que ir saltando
-- entre índice y tabla (baja selectividad = índice ignorado).

-- RE-EVALUACIÓN con 'Fallida' (alta selectividad, ~6.7% de las filas):
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Fallida'
  AND fecha >= '2026-01-01 00:00:00';
-- RESULTADO: Index range scan on historial_transferencias using idx_transf_estado_fecha
-- (cost=300 rows=666, rows leídas=666).
-- CONCLUSIÓN CLAVE DE LA PARTE 1: el mismo índice puede ser usado o ignorado por MySQL
-- dependiendo de la selectividad de la condición. Con 'Fallida' (pocas filas) sí lo usa;
-- con 'Exitosa' (muchas filas) prefiere Table scan. La cardinalidad del filtro decide.


-- ==============================================================================
-- PARTE 2: EJERCICIOS PRÁCTICOS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- EJERCICIO 1: Diagnóstico de "Non-Sargable Query" (Uso de Funciones en WHERE)
-- ------------------------------------------------------------------------------
-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE DATE(fecha) = '2026-02-15';
-- RESULTADO: Table scan on historial_transferencias (cost=1038 rows=10142, rows leídas=10000).

-- 1. ¿Por qué NO se usa el índice?
-- Porque la columna 'fecha' está envuelta en la función DATE(), obligando a MySQL a calcular
-- DATE(fecha) para CADA fila antes de comparar. El índice guarda los valores crudos de fecha,
-- no el resultado de aplicarle una función, así que no puede usarse: la consulta deja de ser
-- "sargable" (Search ARGument ABLE).

-- 2. Reescritura sargable (rango de fechas, sin función sobre la columna):
EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE fecha >= '2026-02-15 00:00:00'
  AND fecha < '2026-02-16 00:00:00';
-- RESULTADO: Sigue en Table scan (cost=1038, rows leídas=10000), porque el único índice
-- existente (idx_transf_estado_fecha) empieza por 'estado_transferencia', no por 'fecha',
-- así que tampoco sirve aquí.

-- Para completar la demostración, se crea un índice dedicado a 'fecha':
CREATE INDEX idx_transf_fecha ON historial_transferencias(fecha);

EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE fecha >= '2026-02-15 00:00:00'
  AND fecha < '2026-02-16 00:00:00';
-- RESULTADO: Index range scan on historial_transferencias using idx_transf_fecha
-- (cost=0.71 rows=1). Costo bajó de 1038 a 0.71.

-- 3. COMPARACIÓN Y CONCLUSIÓN EJERCICIO 1:
--    a) DATE(fecha)=...           -> Table scan, cost=1038 (no sargable)
--    b) fecha entre rango, sin índice adecuado -> Table scan, cost=1038 (sargable pero sin índice útil)
--    c) fecha entre rango, con idx_transf_fecha -> Index range scan, cost=0.71
-- Ser sargable es NECESARIO pero NO SUFICIENTE: solo al combinar consulta sargable +
-- índice adecuado sobre la columna correcta se logra la mejora real de rendimiento.


-- ------------------------------------------------------------------------------
-- EJERCICIO 2: Optimización mediante Índices Cubrientes (Covering Index)
-- ------------------------------------------------------------------------------
-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';
-- RESULTADO: Table scan on cuentas (cost=102 rows=1000, rows leídas=900 que cumplen filtro).

-- 1. Impacto de SELECT * vs columnas específicas:
-- SELECT * obliga a traer TODAS las columnas de la tabla, incluso si un índice ya localizó
-- rápido las filas. Eso fuerza un "bookmark lookup" (saltar del índice a la tabla base para
-- completar las columnas faltantes). Pedir solo las columnas necesarias permite que, si esas
-- columnas están dentro del índice, MySQL nunca tenga que tocar la tabla base.

-- 2. Diseño del índice cubriente (columna del WHERE primero, luego las columnas retornadas):
CREATE INDEX idx_cuentas_estado_cubriente
ON cuentas(estado, titular, saldo, tipo_cuenta);

-- 3. Verificación:
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';
-- RESULTADO: "Covering index lookup on cuentas using idx_cuentas_estado_cubriente" (cost=136 rows=900).
-- CONCLUSIÓN: MySQL resuelve toda la consulta leyendo solo el índice, sin ir a la tabla base.
-- El costo numérico subió levemente (102 -> 136) porque el número de filas no bajó (estado
-- 'Activa' tampoco es muy selectivo, ~90% de los datos), pero la ganancia real está en evitar
-- el acceso adicional a la tabla (menos I/O), no en reducir filas escaneadas.


-- ------------------------------------------------------------------------------
-- EJERCICIO 3: Optimización de Filtros Combinados y JOINs
-- ------------------------------------------------------------------------------
-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;
-- RESULTADO:
--   - historial_transferencias (ht): Table scan (cost=1038 rows=10142, rows leídas=10000)
--     -> esta es la tabla con Full Table Scan, por el filtro monto > 300000 sin índice.
--   - cuentas (c): Single-row index lookup using PRIMARY (id_cuenta=ht.cuenta_origen)
--     -> ya es eficiente porque el JOIN usa la llave primaria, siempre indexada.

-- 1. Tabla escaneada por completo: historial_transferencias (ht).

-- Primer intento de índice (columna de igualdad + rango, orden "clásico"):
CREATE INDEX idx_transf_origen_monto ON historial_transferencias(cuenta_origen, monto);
-- (No se re-ejecuta el EXPLAIN aquí porque no aplica: la consulta no filtra por cuenta_origen
--  con una condición de igualdad -el JOIN recorre ht fila a fila-, así que este índice
--  no puede usarse por la regla del prefijo izquierdo.)

-- Segundo intento: índice simple sobre la columna de filtro real (monto):
CREATE INDEX idx_transf_monto ON historial_transferencias(monto);

EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;
-- RESULTADO: Sigue en Table scan sobre ht (cost=1038, rows leídas=10000).
-- El índice idx_transf_monto es válido en diseño pero el optimizador lo descarta porque
-- monto > 300000 retiene ~39.6% de las filas (3962 de 10000): baja selectividad, igual que
-- pasó con 'Exitosa' en la Parte 1. Con esa proporción, Table scan sigue siendo más barato
-- que saltar entre índice y tabla miles de veces.

-- 2. Índices creados: idx_transf_origen_monto(cuenta_origen, monto) e idx_transf_monto(monto).

-- 3. Justificación del orden de columnas / conclusión EJERCICIO 3:
-- En índices compuestos, las columnas de igualdad deben ir antes que las de rango (regla del
-- prefijo izquierdo). Aquí el filtro sobre 'ht' no tiene ninguna condición de igualdad (el
-- JOIN recorre la tabla fila por fila), por eso ningún índice compuesto ayuda. El verdadero
-- cuello de botella no es la falta de índice, sino la baja selectividad de 'monto > 300000':
-- el optimizador decide correctamente que un Table scan es más eficiente que usar el índice
-- para casi el 40% de los datos. La tabla 'cuentas' nunca fue un problema porque el JOIN
-- usa su llave primaria.

-- ==============================================================================
-- FIN DEL TALLER
-- ==============================================================================
