/*
 *
-- Tabla original (sin normalizar)

CREATE TABLE RegistroHospital (
PacienteID int,
NombrePaciente varchar(100),
FechaNacimiento date,
MedicoID int,
NombreMedico varchar(100),
Especialidad varchar(100),
FechaVisita datetime,
DescripcionTratamiento varchar(255),
Medicamento varchar(100),
Dosis varchar(50)
);

*/

-- Tablas normalizadas

CREATE TABLE Paciente (
    PacienteID int PRIMARY KEY AUTO_INCREMENT,
    NombrePaciente varchar(100) NOT NULL,
    FechaNacimiento date NOT NULL
);

CREATE TABLE Medico (
    MedicoID int PRIMARY KEY AUTO_INCREMENT,
    NombreMedico varchar(100) NOT NULL,
    Especialidad varchar(100) NOT NULL
);

CREATE TABLE Medicamento (
    MedicamentoID int PRIMARY KEY AUTO_INCREMENT,
    NombreMedicamento varchar(100) NOT NULL,
    Dosis varchar(100) NOT NULL
);

CREATE TABLE Visita (
    PacienteID int NOT NULL,
    MedicoID int NOT NULL,
    FechaVisita datetime NOT NULL,
    DescripcionTratamiento varchar(255) NOT NULL,

    CONSTRAINT PK_Visita PRIMARY KEY (PacienteID, MedicoID, FechaVisita),
    CONSTRAINT FK_Visita_Paciente FOREIGN KEY (PacienteID) REFERENCES Paciente(PacienteID),
    CONSTRAINT FK_Visita_Medico   FOREIGN KEY (MedicoID)   REFERENCES Medico(MedicoID)
);

CREATE TABLE VisitaMedicamento (
    PacienteID int NOT NULL,
    MedicoID int NOT NULL,
    FechaVisita datetime NOT NULL,
    MedicamentoID int NOT NULL,
    Dosis varchar(100) NOT NULL,
    Frecuencia int NOT NULL,

    CONSTRAINT PK_VisitaMedicamento PRIMARY KEY (PacienteID, MedicoID, FechaVisita, MedicamentoID),
    CONSTRAINT FK_VM_Visita FOREIGN KEY (PacienteID, MedicoID, FechaVisita) REFERENCES Visita(PacienteID, MedicoID, FechaVisita),
    CONSTRAINT FK_VM_Medicamento FOREIGN KEY (MedicamentoID) REFERENCES Medicamento(MedicamentoID)
);

-- Inserción de datos

INSERT INTO Paciente (PacienteID, NombrePaciente, FechaNacimiento) VALUES
(1,  'Juan Pérez',       '1985-04-12'),
(2,  'Ana Gómez',        '1990-11-23'),
(3,  'Carlos Mendoza',   '1975-07-05'),
(4,  'Sofía Ramírez',    '2000-02-14'),
(5,  'Luis Castro',      '1962-09-30'),
(6,  'Elena Morales',    '1995-12-03'),
(7,  'Pedro Vargas',     '1988-06-19'),
(8,  'Lucía Fernández',  '2005-03-25'),
(9,  'Jorge Herrera',    '1970-10-10'),
(10, 'Valeria Ortiz',    '1992-05-18');

INSERT INTO Medico (MedicoID, NombreMedico, Especialidad) VALUES
(101, 'Dr. Carlos Ruiz',     'Cardiología'),
(102, 'Dra. Laura Torres',   'Pediatría'),
(103, 'Dr. Miguel Ángel',    'Traumatología'),
(104, 'Dra. Elena Vargas',   'Dermatología'),
(105, 'Dr. Javier Soto',     'Gastroenterología'),
(106, 'Dra. Patricia Ramos', 'Neurología');

INSERT INTO Medicamento (MedicamentoID, NombreMedicamento, Dosis) VALUES
(1,  'Losartán',             '50mg'),
(2,  'Amoxicilina',          '500mg'),
(3,  'Ibuprofeno',           '600mg'),
(4,  'Hidrocortisona',       '1% crema'),
(5,  'Amiodarona',           '200mg'),
(6,  'Omeprazol',            '20mg'),
(7,  'Tramadol',             '50mg'),
(8,  'Multivitamínico',      '1 tableta'),
(9,  'Sumatriptán',          '50mg'),
(10, 'Peróxido de benzoilo', '5% gel');

INSERT INTO Visita (PacienteID, MedicoID, FechaVisita, DescripcionTratamiento) VALUES
(1,  101, '2026-06-01 09:30:00', 'Control de presión arterial'),
(2,  102, '2026-06-01 10:15:00', 'Infección respiratoria leve'),
(3,  103, '2026-06-02 11:00:00', 'Esguince de tobillo derecho'),
(4,  104, '2026-06-03 15:45:00', 'Dermatitis atópica'),
(5,  101, '2026-06-04 08:20:00', 'Arritmia leve'),
(6,  105, '2026-06-04 12:00:00', 'Gastritis aguda'),
(7,  103, '2026-06-05 16:30:00', 'Dolor lumbar crónico'),
(8,  102, '2026-06-06 09:00:00', 'Control de crecimiento'),
(9,  106, '2026-06-06 11:30:00', 'Migraña tensional'),
(10, 104, '2026-06-07 14:00:00', 'Acné severo');

INSERT INTO VisitaMedicamento (PacienteID, MedicoID, FechaVisita, MedicamentoID, Dosis, Frecuencia) VALUES
(1,  101, '2026-06-01 09:30:00', 1,  '50mg',      8),
(2,  102, '2026-06-01 10:15:00', 2,  '500mg',     8),
(3,  103, '2026-06-02 11:00:00', 3,  '600mg',     8),
(4,  104, '2026-06-03 15:45:00', 4,  '1% crema',  8),
(5,  101, '2026-06-04 08:20:00', 5,  '200mg',     8),
(6,  105, '2026-06-04 12:00:00', 6,  '20mg',      8),
(7,  103, '2026-06-05 16:30:00', 7,  '50mg',      8),
(8,  102, '2026-06-06 09:00:00', 8,  '1 tableta', 8),
(9,  106, '2026-06-06 11:30:00', 9,  '50mg',      8),
(10, 104, '2026-06-07 14:00:00', 10, '5% gel',    8);