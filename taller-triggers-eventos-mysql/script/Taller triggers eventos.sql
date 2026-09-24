-- ==============================================================================
-- TALLER PRÁCTICO: TRIGGERS Y EVENTOS EN MYSQL (BancoDB)
-- ==============================================================================
-- Objetivo: Comprender la creación y funcionamiento de Triggers (reactividad en
-- tiempo real) y Eventos (programación temporal de tareas) sobre la base de datos BancoDB.
-- ==============================================================================

USE BancoDB;

-- ------------------------------------------------------------------------------
-- PARTE 0: TABLAS DE AUDITORÍA Y MÉTRICAS (Estructura de Soporte)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS auditoria_saldos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cuenta INT NOT NULL,
    saldo_anterior DECIMAL(10,2) NOT NULL,
    saldo_nuevo DECIMAL(10,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cuenta) REFERENCES cuentas(id_cuenta)
);

CREATE TABLE IF NOT EXISTS metricas_diarias (
    id_metrica INT AUTO_INCREMENT PRIMARY KEY,
    fecha_metrica DATE NOT NULL,
    total_cuentas INT NOT NULL,
    saldo_total_sistema DECIMAL(12,2) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Columna necesaria para el manejo de estado de las cuentas (Activa/Inactiva)
ALTER TABLE cuentas
ADD COLUMN estado VARCHAR(20) NOT NULL DEFAULT 'Activa';

SET GLOBAL event_scheduler = ON;

-- ==============================================================================
-- PARTE 1: DEMOSTRACIÓN GUIADA EN CLASE (EXPLICACIÓN DEL PROFESOR)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1.1 TRIGGER: Auditoría Automática de Cambios de Saldo (AFTER UPDATE)
-- ------------------------------------------------------------------------------

DELIMITER //

DROP TRIGGER IF EXISTS trg_auditar_cambio_saldo //

CREATE TRIGGER trg_auditar_cambio_saldo
AFTER UPDATE ON cuentas
FOR EACH ROW
BEGIN
    IF OLD.saldo <> NEW.saldo THEN
        INSERT INTO auditoria_saldos (id_cuenta, saldo_anterior, saldo_nuevo, usuario)
        VALUES (NEW.id_cuenta, OLD.saldo, NEW.saldo, USER());
    END IF;
END //

DELIMITER ;

-- Prueba:
-- UPDATE cuentas SET saldo = saldo + 500.00 WHERE id_cuenta = 1;
-- SELECT * FROM auditoria_saldos;

-- ------------------------------------------------------------------------------
-- 1.2 EVENTO: Resumen Periódico de Métricas del Banco (RECURRING)
-- ------------------------------------------------------------------------------

DELIMITER //

DROP EVENT IF EXISTS evt_registrar_metricas_diarias //

CREATE EVENT evt_registrar_metricas_diarias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Consolida el saldo total y cantidad de cuentas activas diariamente'
DO
BEGIN
    INSERT INTO metricas_diarias (fecha_metrica, total_cuentas, saldo_total_sistema)
    SELECT CURDATE(), COUNT(id_cuenta), IFNULL(SUM(saldo), 0.00)
    FROM cuentas
    WHERE estado = 'Activa';
END //

DELIMITER ;

-- Prueba:
-- SHOW EVENTS FROM BancoDB;
-- SELECT * FROM metricas_diarias;

-- ==============================================================================
-- PARTE 2: RETO AUTÓNOMO
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- EJERCICIO 1 (TRIGGER): Validación de Transferencias (BEFORE INSERT)
-- ------------------------------------------------------------------------------

DELIMITER //

DROP TRIGGER IF EXISTS trg_validar_transferencia //

CREATE TRIGGER trg_validar_transferencia
BEFORE INSERT ON historial_transferencias
FOR EACH ROW
BEGIN
    IF NEW.monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto de la transferencia debe ser mayor a cero';
    END IF;

    IF NEW.cuenta_origen = NEW.cuenta_destino THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de origen y destino no pueden ser iguales';
    END IF;
END //

DELIMITER ;

-- Pruebas:
-- Debe fallar (monto <= 0)
INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto) VALUES (1, 2, 0);

-- Debe fallar (misma cuenta)
INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto) VALUES (1, 1, 100);

-- Debe pasar
INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto) VALUES (1, 2, 100);

-- ------------------------------------------------------------------------------
-- EJERCICIO 2 (EVENTO): Inactivación Automática de Cuentas en Cero
-- ------------------------------------------------------------------------------

DELIMITER //

DROP EVENT IF EXISTS evt_inactivar_cuentas_vacias //

CREATE EVENT evt_inactivar_cuentas_vacias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Inactiva automáticamente las cuentas con saldo en cero'
DO
BEGIN
    UPDATE cuentas
    SET estado = 'Inactiva'
    WHERE saldo = 0.00
      AND estado = 'Activa';
END //

DELIMITER ;

-- Pruebas:
SHOW TRIGGERS FROM BancoDB;
SHOW EVENTS FROM BancoDB;

UPDATE cuentas SET saldo = 0.00 WHERE id_cuenta = 2;
SELECT id_cuenta, saldo, estado FROM cuentas WHERE id_cuenta = 2;

-- Ejecución manual de la lógica del evento (para no esperar el intervalo)
UPDATE cuentas SET estado = 'Inactiva' WHERE saldo = 0.00 AND estado = 'Activa';
SELECT id_cuenta, saldo, estado FROM cuentas WHERE id_cuenta = 2;

SELECT id_cuenta, saldo, estado FROM cuentas;










