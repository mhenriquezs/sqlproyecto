#Eliminar la base de datos si ya existe
DROP DATABASE IF EXISTS sistema_entrenamiento;

#Crear la base de datos
CREATE DATABASE sistema_entrenamiento;
USE sistema_entrenamiento;

#Crear tabla divisiones_org
CREATE TABLE divisiones_org (
    id INT AUTO_INCREMENT PRIMARY KEY,
    cargo VARCHAR(50) NOT NULL,
    cargo_homologado VARCHAR(50),
    CECO VARCHAR(10) NOT NULL,
    area VARCHAR(50) NOT NULL
);
#Crear tabla empleados que depende de divisiones_org
CREATE TABLE empleados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(50) NOT NULL,
    RUT VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(50) UNIQUE NOT NULL,
    region VARCHAR(30) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    division_id INT NOT NULL,
    supervisor_id INT DEFAULT NULL,
    FOREIGN KEY (division_id) REFERENCES divisiones_org(id),
    FOREIGN KEY (supervisor_id) REFERENCES empleados(id)
);

#Crear tabla elearning_cursos
CREATE TABLE elearning_cursos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    horas DECIMAL(5, 2) NOT NULL
);

#Crear tabla cursos_empleados
CREATE TABLE cursos_empleados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    empleado_id INT NOT NULL,
    curso_id INT NOT NULL,
    estado VARCHAR(20) NOT NULL,
    fecha_completado DATE DEFAULT NULL,
    FOREIGN KEY (empleado_id) REFERENCES empleados(id),
    FOREIGN KEY (curso_id) REFERENCES elearning_cursos(id)
);

CREATE TABLE auditoria (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tabla_afectada VARCHAR(50) NOT NULL,
    accion VARCHAR(10) NOT NULL,
    registro_id INT NOT NULL,
    fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP
);

SHOW TABLES;

 #CREAR LA VISTA ACUMULADO_ENTRENAMIENTO
CREATE OR REPLACE VIEW acumulado_entrenamiento AS
SELECT 
    e.id AS empleado_id,
    e.nombre_completo,
    e.email,
    d.area,
    SUM(c.horas) AS total_horas_completadas,
    SUM(CASE 
        WHEN ce.fecha_completado >= DATE_FORMAT(CURDATE(), '%Y-01-01') THEN c.horas 
        ELSE 0 
    END) AS horas_completadas_anio
FROM 
    empleados e
JOIN 
    cursos_empleados ce ON e.id = ce.empleado_id
JOIN 
    elearning_cursos c ON ce.curso_id = c.id
JOIN 
    divisiones_org d ON e.division_id = d.id
WHERE 
    ce.estado = 'Completado'
GROUP BY 
    e.id, e.nombre_completo, e.email, d.area;
    
SELECT * FROM acumulado_entrenamiento;

	#CREAR LA VISTA DE CURSOS PENDIENTES POR EMPLEADO
CREATE OR REPLACE VIEW cursos_pendientes AS
SELECT 
    e.id AS empleado_id,
    e.nombre_completo,
    c.titulo AS curso_pendiente
FROM 
    empleados e
JOIN 
    cursos_empleados ce ON e.id = ce.empleado_id
JOIN 
    elearning_cursos c ON ce.curso_id = c.id
WHERE 
    ce.estado = 'En Progreso';

SELECT * FROM cursos_pendientes;

	#CREAR LA VISTA DE CAPACITACION POR DIVISION
    
CREATE OR REPLACE VIEW capacitacion_division AS
SELECT 
    d.area,
    COUNT(DISTINCT ce.empleado_id) AS empleados_capacitados,
    SUM(c.horas) AS horas_totales
FROM 
    divisiones_org d
JOIN 
    empleados e ON d.id = e.division_id
JOIN 
    cursos_empleados ce ON e.id = ce.empleado_id
JOIN 
    elearning_cursos c ON ce.curso_id = c.id
WHERE 
    ce.estado = 'Completado'
GROUP BY 
    d.area;
    
    SELECT * FROM capacitacion_division;
    
	#CREAR VISTA DE CURSOS MAS ASIGNADOS
CREATE OR REPLACE VIEW cursos_mas_solicitados AS
SELECT 
    c.titulo AS curso,
    COUNT(ce.id) AS total_asignaciones
FROM 
    elearning_cursos c
JOIN 
    cursos_empleados ce ON c.id = ce.curso_id
GROUP BY 
    c.id, c.titulo
ORDER BY 
    total_asignaciones DESC;
    
    SELECT * FROM cursos_mas_solicitados;
    
    #CREAR VISTA DE SUPERVISORES Y NUMERO DE SUBORDINADOS
CREATE OR REPLACE VIEW supervisores_equipo AS
SELECT 
    e.id AS supervisor_id,
    e.nombre_completo AS supervisor,
    COUNT(emp.id) AS empleados_a_cargo
FROM 
    empleados e
LEFT JOIN 
    empleados emp ON e.id = emp.supervisor_id
WHERE 
    e.supervisor_id IS NULL 
GROUP BY 
    e.id, e.nombre_completo;
    
    SELECT * FROM supervisores_equipo;
    
	#CREAR VISTA COUNT PERSONAS NO CUMPLEN 40 HORAS POR SUPERVISOR
    
    CREATE OR REPLACE VIEW supervisores_bajo_cumplimiento AS
SELECT 
    s.id AS supervisor_id,
    s.nombre_completo AS supervisor,
    COUNT(e.id) AS empleados_no_cumplen
FROM 
    empleados s
JOIN 
    empleados e ON s.id = e.supervisor_id
LEFT JOIN 
    cursos_empleados ce ON e.id = ce.empleado_id
LEFT JOIN 
    elearning_cursos c ON ce.curso_id = c.id
WHERE 
    s.supervisor_id IS NULL
    AND (
        SELECT 
            SUM(c.horas) 
        FROM 
            cursos_empleados ce2
        JOIN 
            elearning_cursos c2 ON ce2.curso_id = c2.id
        WHERE 
            ce2.empleado_id = e.id
            AND ce2.estado = 'Completado'
            AND ce2.fecha_completado >= DATE_FORMAT(CURDATE(), '%Y-01-01')
    ) < 40
GROUP BY 
    s.id, s.nombre_completo
ORDER BY 
    empleados_no_cumplen DESC;
    
    SELECT * FROM supervisores_bajo_cumplimiento;
    
    #CREAR VISTA AREA CON PERSONAS QUE NO CUMPLEN
    
CREATE OR REPLACE VIEW areas_bajo_cumplimiento AS
SELECT 
    d.area,
    COUNT(e.id) AS empleados_no_cumplen
FROM 
    divisiones_org d
LEFT JOIN 
    empleados e ON d.id = e.division_id
LEFT JOIN 
    (
        SELECT 
            ce.empleado_id,
            SUM(c.horas) AS horas_totales
        FROM 
            cursos_empleados ce
        JOIN 
            elearning_cursos c ON ce.curso_id = c.id
        WHERE 
            ce.estado = 'Completado'
            AND ce.fecha_completado >= DATE_FORMAT(CURDATE(), '%Y-01-01')
        GROUP BY 
            ce.empleado_id
    ) t_horas ON e.id = t_horas.empleado_id
WHERE 
    (t_horas.horas_totales IS NULL OR t_horas.horas_totales < 40)
GROUP BY 
    d.area
ORDER BY 
    empleados_no_cumplen DESC;
    
    SELECT * FROM areas_bajo_cumplimiento;
    
    #CREAR STORED PROCEDURE PARA ASIGNAR MASIVAMENTE CURSOS A PERSONAS DE UNA MISMA DIVISION
    
DELIMITER //
CREATE PROCEDURE asignar_cursos_por_division(
    IN division INT,
    IN curso INT
)
BEGIN
    INSERT INTO cursos_empleados (empleado_id, curso_id, estado)
    SELECT 
        e.id AS empleado_id,
        curso AS curso_id,
        'Not Started' AS estado
    FROM 
        empleados e
    WHERE 
        e.division_id = division;
END //
DELIMITER ;

	#EJEMPLO DE LLAMADA
    
    CALL asignar_cursos_por_division(3, 1);
    
    #CREAR STORED PROCEDURE DE RESUMEN DE CAPACITACION POR EMPLEADO
    
DELIMITER //
CREATE PROCEDURE resumen_capacitacion_empleado(
    IN empleado_id INT
)
BEGIN
    SELECT 
        c.titulo AS curso,
        ce.estado AS estado,
        ce.fecha_completado AS fecha,
        c.horas AS horas
    FROM 
        cursos_empleados ce
    JOIN 
        elearning_cursos c ON ce.curso_id = c.id
    WHERE 
        ce.empleado_id = empleado_id;
END //
DELIMITER ;

	#EJEMPLO DE RESUMEN DE CAPACITACION POR EMPLEADO
    
    CALL resumen_capacitacion_empleado(3);
    
	#CREAR PROCEDIMIENTO DE EMPLEADOS QUE NO CUMPLEN CON 40 HORAS 
    
   DROP PROCEDURE IF EXISTS empleados_no_cumplen;

DELIMITER //

CREATE PROCEDURE empleados_no_cumplen()
BEGIN
    SELECT 
        e.id AS empleado_id,
        e.nombre_completo AS empleado,
        s.nombre_completo AS supervisor,
        COALESCE(SUM(c.horas), 0) AS horas_completadas
    FROM 
        empleados e
    LEFT JOIN 
        empleados s ON e.supervisor_id = s.id
    LEFT JOIN 
        cursos_empleados ce ON e.id = ce.empleado_id
    LEFT JOIN 
        elearning_cursos c ON ce.curso_id = c.id
    WHERE 
        ce.estado = 'Completado'
        OR ce.estado IS NULL
    GROUP BY 
        e.id, e.nombre_completo, s.nombre_completo
    HAVING 
        horas_completadas < 40
    ORDER BY 
        horas_completadas ASC;
END //

DELIMITER ;
    CALL empleados_no_cumplen();
    
#TRIGGER DE ELIMINACION DE REGISTROS ASOCIADOS AL EMPLEADO SI ES DESVINCULADO

	DELIMITER //

CREATE TRIGGER eliminar_cursos_empleado
AFTER DELETE ON empleados
FOR EACH ROW
BEGIN
    DELETE FROM cursos_empleados WHERE empleado_id = OLD.id;
END //

DELIMITER ;
    
    #TRIGGER 2: ELIMINAR O ACTUALIZAR EMPLEADOS ASOCIADOS A UN CARGO

DELIMITER //

CREATE TRIGGER actualizar_empleados_cargo
AFTER DELETE ON divisiones_org
FOR EACH ROW
BEGIN
    UPDATE empleados 
    SET division_id = NULL
    WHERE division_id = OLD.id;
END //

DELIMITER ;

#TRIGGER 3: ACTUALIZAR ESTADO AL COMPLETAR UN CURSO

DELIMITER //

CREATE TRIGGER actualizar_estado_curso
BEFORE UPDATE ON cursos_empleados
FOR EACH ROW
BEGIN
    IF NEW.fecha_completado IS NOT NULL THEN
        SET NEW.estado = 'Completed';
    END IF;
END //

DELIMITER ;

#TRIGGER 4: REGISTRO DE ELIMINACIONES EN EMPLEADOS

DELIMITER //

CREATE TRIGGER auditoria_eliminar_empleado
AFTER DELETE ON empleados
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, accion, registro_id)
    VALUES ('empleados', 'DELETE', OLD.id);
END //

DELIMITER ;

#TRIGGER 5: REGISTRO DE INSERCIONES EN CURSOS_EMPLEADOS

DELIMITER //

CREATE TRIGGER auditoria_insertar_curso
AFTER INSERT ON cursos_empleados
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, accion, registro_id)
    VALUES ('cursos_empleados', 'INSERT', NEW.id);
END //

DELIMITER ;


#CREAR FUNCION PERSONALIZADA PORCENTAJE DE CURSOS COMPLETADOS POR EMPLEADO

DELIMITER //

CREATE FUNCTION porcentaje_cursos_completados(empleado_id INT)
RETURNS DECIMAL(5, 2)
DETERMINISTIC
BEGIN
    DECLARE total_cursos INT;
    DECLARE cursos_completados INT;
    DECLARE porcentaje DECIMAL(5, 2);

    -- Contar cursos asignados
    SELECT COUNT(*) INTO total_cursos
    FROM cursos_empleados
    WHERE empleado_id = empleado_id;

    -- Contar cursos completados
    SELECT COUNT(*) INTO cursos_completados
    FROM cursos_empleados
    WHERE empleado_id = empleado_id AND estado = 'Completado';

    -- Calcular porcentaje
    IF total_cursos = 0 THEN
        SET porcentaje = 0; -- Evitar división por cero
    ELSE
        SET porcentaje = (cursos_completados / total_cursos) * 100;
    END IF;

    RETURN porcentaje;
END //

DELIMITER ;

#EJEMPLO

SELECT porcentaje_cursos_completados(1);

#CREAR FUNCION 2: TOTAL DE HORAS COMPLETADAS POR EMPLEADO

DELIMITER //

CREATE FUNCTION total_horas_completadas(empleado_id INT)
RETURNS DECIMAL(6, 2)
DETERMINISTIC
BEGIN
    DECLARE total_horas DECIMAL(6, 2);

    -- Calcular horas completadas
    SELECT COALESCE(SUM(c.horas), 0) INTO total_horas
    FROM cursos_empleados ce
    JOIN elearning_cursos c ON ce.curso_id = c.id
    WHERE ce.empleado_id = empleado_id AND ce.estado = 'Completado';

    RETURN total_horas;
END //

DELIMITER ;

#EJEMPLO

SELECT total_horas_completadas(1);

