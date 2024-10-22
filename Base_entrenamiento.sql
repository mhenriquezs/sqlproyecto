#Eliminar la base de datos si ya existe
DROP DATABASE IF EXISTS sistema_entrenamiento;

#Crear la base de datos
CREATE DATABASE sistema_entrenamiento;
USE sistema_entrenamiento;

#Crear tabla divisiones_org
CREATE TABLE divisiones_org (
    id_cargo INT,
    cargo VARCHAR(50),
    cargo_homologado VARCHAR(50),
    CECO VARCHAR(10),
    area VARCHAR(50),
    PRIMARY KEY (id_cargo, area) 
);

#Crear tabla empleados que depende de divisiones_org
CREATE TABLE empleados (
    employee_ID INT PRIMARY KEY,
    nombre_completo VARCHAR(50),
    RUT VARCHAR(15),
    email VARCHAR(30),
    region VARCHAR(30),
    fecha_ingreso DATE,
    id_cargo INT,
    area VARCHAR(50),
    supervisor_id INT,
    FOREIGN KEY (id_cargo, area) REFERENCES divisiones_org(id_cargo, area),
    FOREIGN KEY (supervisor_id) REFERENCES empleados(employee_ID) 
);

#Crear tabla elearning_cursos
CREATE TABLE elearning_cursos (
    item_ID VARCHAR(10) PRIMARY KEY,
    item_title VARCHAR(100),
    hour_credits DECIMAL(4,2)
);

#Crear tabla cursos_empleados
CREATE TABLE cursos_empleados (
    employee_ID INT,
    item_ID VARCHAR(10),
    completion_status VARCHAR(20),
    completion_date DATE,
    PRIMARY KEY (employee_ID, item_ID),
    FOREIGN KEY (employee_ID) REFERENCES empleados(employee_ID),
    FOREIGN KEY (item_ID) REFERENCES elearning_cursos(item_ID)
);

#Crear tabla acumulado_entrenamiento
CREATE TABLE acumulado_entrenamiento (
    reporte_id INT PRIMARY KEY,
    employee_ID INT,
    id_cargo INT, 
    area VARCHAR(50),  
    supervisor_id INT,
    total_horas_completadas DECIMAL(6,2),
    horas_completadas_año DECIMAL(6,2),
    FOREIGN KEY (employee_ID) REFERENCES empleados(employee_ID),
    FOREIGN KEY (supervisor_id) REFERENCES empleados(employee_ID),
    FOREIGN KEY (id_cargo, area) REFERENCES divisiones_org(id_cargo, area)  
);

SHOW TABLES;