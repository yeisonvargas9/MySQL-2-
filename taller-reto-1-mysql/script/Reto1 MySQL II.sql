-- ============================================================
-- RETO: Transferencia Bancaria Segura con Procedimientos Almacenados
-- + Función definida por el usuario (CalcularImpuestoGMF)
-- ============================================================

CREATE DATABASE IF NOT EXISTS BancoDB;
USE BancoDB;

-- ------------------------------------------------------------
-- Limpieza previa (por si se re-ejecuta el script)
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS TransferirFondosConGMF;
DROP PROCEDURE IF EXISTS TransferirFondos;
DROP FUNCTION IF EXISTS CalcularImpuestoGMF;
DROP TABLE IF EXISTS impuestos_gmf;
DROP TABLE IF EXISTS historial_transferencias;
DROP TABLE IF EXISTS cuentas;

-- ------------------------------------------------------------
-- Paso 2: Tablas
-- ------------------------------------------------------------
CREATE TABLE cuentas (
    id_cuenta INT PRIMARY KEY,
    titular VARCHAR(100),
    saldo DECIMAL(10,2)
);

CREATE TABLE historial_transferencias (
    id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
    cuenta_origen INT,
    cuenta_destino INT,
    monto DECIMAL(10,2),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- Paso 3: Datos de prueba
-- ------------------------------------------------------------
INSERT INTO cuentas (id_cuenta, titular, saldo) VALUES
(1, 'Ana López', 5000.00),
(2, 'Carlos Pérez', 3000.00);

-- ------------------------------------------------------------
-- Paso 4: Procedimiento base TransferirFondos
-- ------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE TransferirFondos(
    IN p_origen INT,
    IN p_destino INT,
    IN p_monto DECIMAL(10,2),
    OUT p_codigo_respuesta INT
)
BEGIN
    DECLARE v_saldo_origen DECIMAL(10,2);

    -- Manejo de errores: cualquier excepción SQL hace rollback y retorna 500
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_codigo_respuesta = 500;
    END;

    START TRANSACTION;

    -- Bloquear la fila de la cuenta origen y leer su saldo
    SELECT saldo INTO v_saldo_origen
    FROM cuentas
    WHERE id_cuenta = p_origen
    FOR UPDATE;

    IF v_saldo_origen >= p_monto THEN
        -- Transferencia exitosa
        UPDATE cuentas SET saldo = saldo - p_monto WHERE id_cuenta = p_origen;
        UPDATE cuentas SET saldo = saldo + p_monto WHERE id_cuenta = p_destino;

        INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto)
        VALUES (p_origen, p_destino, p_monto);

        COMMIT;
        SET p_codigo_respuesta = 200;
    ELSE
        -- Saldo insuficiente
        ROLLBACK;
        SET p_codigo_respuesta = 400;
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- Extensión: columna de exención + tabla de auditoría del GMF
-- ------------------------------------------------------------
ALTER TABLE cuentas ADD COLUMN es_exenta BOOLEAN DEFAULT FALSE;

-- Marcar una cuenta como exenta (ejemplo)
UPDATE cuentas SET es_exenta = TRUE WHERE id_cuenta = 1;

CREATE TABLE impuestos_gmf (
    id_impuesto INT AUTO_INCREMENT PRIMARY KEY,
    id_transferencia INT,
    monto_transferido DECIMAL(12,2),
    valor_impuesto DECIMAL(12,2),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_transferencia) REFERENCES historial_transferencias(id_transferencia)
);

-- ------------------------------------------------------------
-- Función definida por el usuario: CalcularImpuestoGMF
-- ------------------------------------------------------------
DELIMITER //

CREATE FUNCTION CalcularImpuestoGMF(
    p_monto DECIMAL(12,2),
    p_es_exenta BOOLEAN
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE v_impuesto DECIMAL(12,2);

    IF p_es_exenta THEN
        SET v_impuesto = 0.00;
    ELSE
        -- 4x1000 equivale al 0.4% (monto * 0.004)
        SET v_impuesto = p_monto * 0.004;
    END IF;

    RETURN v_impuesto;
END //

DELIMITER ;

-- ------------------------------------------------------------
-- Procedimiento integrado: transferencia + cálculo de GMF
-- ------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE TransferirFondosConGMF(
    IN p_origen INT,
    IN p_destino INT,
    IN p_monto DECIMAL(12,2),
    OUT p_codigo_respuesta INT
)
BEGIN
    DECLARE v_saldo_origen DECIMAL(12,2);
    DECLARE v_es_exenta BOOLEAN;
    DECLARE v_impuesto DECIMAL(12,2);
    DECLARE v_total_debitar DECIMAL(12,2);
    DECLARE v_id_transferencia INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_codigo_respuesta = 500;
    END;

    IF p_monto <= 0 THEN
        SET p_codigo_respuesta = 401;
    ELSE
        START TRANSACTION;

        SELECT saldo, es_exenta INTO v_saldo_origen, v_es_exenta
        FROM cuentas
        WHERE id_cuenta = p_origen
        FOR UPDATE;

        -- Calcular el impuesto usando la función
        SET v_impuesto = CalcularImpuestoGMF(p_monto, v_es_exenta);
        SET v_total_debitar = p_monto + v_impuesto;

        IF v_saldo_origen >= v_total_debitar THEN
            UPDATE cuentas SET saldo = saldo - v_total_debitar WHERE id_cuenta = p_origen;
            UPDATE cuentas SET saldo = saldo + p_monto WHERE id_cuenta = p_destino;

            INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto)
            VALUES (p_origen, p_destino, p_monto);

            SET v_id_transferencia = LAST_INSERT_ID();

            INSERT INTO impuestos_gmf (id_transferencia, monto_transferido, valor_impuesto)
            VALUES (v_id_transferencia, p_monto, v_impuesto);

            COMMIT;
            SET p_codigo_respuesta = 200;
        ELSE
            ROLLBACK;
            SET p_codigo_respuesta = 400;
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- PRUEBAS
-- ============================================================

-- Ver estado inicial
SELECT * FROM cuentas;

-- Caso 1: transferencia exitosa sin GMF (cuenta 1 es exenta)
CALL TransferirFondosConGMF(1, 2, 1000, @codigo1);
SELECT @codigo1 AS codigo_caso1;

-- Caso 2: transferencia exitosa con GMF (cuenta 2 NO es exenta)
CALL TransferirFondosConGMF(2, 1, 1000, @codigo2);
SELECT @codigo2 AS codigo_caso2;

-- Caso 3: saldo insuficiente
CALL TransferirFondosConGMF(1, 2, 999999, @codigo3);
SELECT @codigo3 AS codigo_caso3;

-- Caso 4: monto inválido (<= 0)
CALL TransferirFondosConGMF(1, 2, -50, @codigo4);
SELECT @codigo4 AS codigo_caso4;

-- Verificar resultados finales
SELECT * FROM cuentas;
SELECT * FROM historial_transferencias;
SELECT * FROM impuestos_gmf;