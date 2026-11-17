-- ===================================================================================
-- PROJETO: SISTEMA DE CONTROLE DE VACINAÇÃO E NOTIFICAÇÃO — CLÍNICA VETERINÁRIA
-- INSTITUIÇÃO: SENAI (Unidade Curricular: Banco de Dados)
-- DOCENTE: Prof. Tércio B. Ribeiro
-- SGBD ALVO: Microsoft SQL Server (T-SQL)
-- DESCRIÇÃO: Script DDL de criação do banco de dados, tabelas, constraints, índices
--            e queries analíticas para notificação de tutores (cães e gatos).
-- ===================================================================================

-- 1. CRIAÇÃO DO BANCO DE DADOS
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'ClinicaVeterinaria')
BEGIN
    CREATE DATABASE ClinicaVeterinaria;
END
GO

USE ClinicaVeterinaria;
GO

-- ===================================================================================
-- 2. ELIMINAÇÃO PREVENTIVA DE TABELAS (ORDEM INVERSA DE DEPENDÊNCIAS)
-- ===================================================================================
IF OBJECT_ID(N'dbo.APLICACAO_VACINA', N'U') IS NOT NULL DROP TABLE dbo.APLICACAO_VACINA;
IF OBJECT_ID(N'dbo.ANIMAL', N'U') IS NOT NULL DROP TABLE dbo.ANIMAL;
IF OBJECT_ID(N'dbo.VACINA', N'U') IS NOT NULL DROP TABLE dbo.VACINA;
IF OBJECT_ID(N'dbo.CLIENTE', N'U') IS NOT NULL DROP TABLE dbo.CLIENTE;
GO

-- ===================================================================================
-- 3. CRIAÇÃO DAS TABELAS
-- ===================================================================================

-- -----------------------------------------------------------------------------------
-- TABELA: CLIENTE (Tutor responsável pelos animais)
-- -----------------------------------------------------------------------------------
CREATE TABLE dbo.CLIENTE (
    id_cliente      INT IDENTITY(1,1) NOT NULL,
    nome            VARCHAR(50)       NOT NULL,
    sobrenome       VARCHAR(50)       NOT NULL,
    telefone        VARCHAR(20)       NOT NULL,
    
    -- Decomposição do atributo composto 'endereço' (1FN)
    rua             VARCHAR(100)      NOT NULL,
    numero          VARCHAR(10)       NOT NULL,
    complemento     VARCHAR(50)       NULL,
    bairro          VARCHAR(50)       NOT NULL,
    cidade          VARCHAR(50)       NOT NULL,
    estado          CHAR(2)           NOT NULL,
    cep             CHAR(9)           NOT NULL,

    CONSTRAINT PK_CLIENTE PRIMARY KEY CLUSTERED (id_cliente)
);
GO

-- -----------------------------------------------------------------------------------
-- TABELA: ANIMAL (Paciente atendido - Cão ou Gato)
-- -----------------------------------------------------------------------------------
CREATE TABLE dbo.ANIMAL (
    id_animal       INT IDENTITY(1,1) NOT NULL,
    nome            VARCHAR(50)       NOT NULL,
    data_nascimento DATE              NOT NULL,
    especie         VARCHAR(30)       NOT NULL,
    raca            VARCHAR(50)       NOT NULL,
    cor             VARCHAR(30)       NOT NULL,
    sexo            CHAR(1)           NOT NULL,
    id_cliente      INT               NOT NULL,

    CONSTRAINT PK_ANIMAL PRIMARY KEY CLUSTERED (id_animal),
    CONSTRAINT FK_ANIMAL_CLIENTE FOREIGN KEY (id_cliente) 
        REFERENCES dbo.CLIENTE (id_cliente)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    CONSTRAINT CK_ANIMAL_SEXO CHECK (sexo IN ('M', 'F'))
);
GO

-- -----------------------------------------------------------------------------------
-- TABELA: VACINA (Catálogo de imunizantes e controle de lote)
-- -----------------------------------------------------------------------------------
CREATE TABLE dbo.VACINA (
    id_vacina       INT IDENTITY(1,1) NOT NULL,
    nome            VARCHAR(100)      NOT NULL,
    laboratorio     VARCHAR(100)      NOT NULL,
    lote            VARCHAR(30)       NOT NULL,

    CONSTRAINT PK_VACINA PRIMARY KEY CLUSTERED (id_vacina)
);
GO

-- -----------------------------------------------------------------------------------
-- TABELA: APLICACAO_VACINA (Entidade associativa N:N com suporte a notificação)
-- -----------------------------------------------------------------------------------
CREATE TABLE dbo.APLICACAO_VACINA (
    id_aplicacao        INT IDENTITY(1,1) NOT NULL,
    id_animal           INT               NOT NULL,
    id_vacina           INT               NOT NULL,
    data_aplicacao      DATE              NOT NULL,
    
    -- Atributos de planejamento do próximo reforço para disparo de alertas/notificações
    id_proxima_vacina   INT               NULL,
    data_proxima_vacina DATE              NULL,

    CONSTRAINT PK_APLICACAO_VACINA PRIMARY KEY CLUSTERED (id_aplicacao),
    
    CONSTRAINT FK_APLICACAO_ANIMAL FOREIGN KEY (id_animal) 
        REFERENCES dbo.ANIMAL (id_animal)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT FK_APLICACAO_VACINA FOREIGN KEY (id_vacina) 
        REFERENCES dbo.VACINA (id_vacina)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    CONSTRAINT FK_APLICACAO_PROXIMA_VACINA FOREIGN KEY (id_proxima_vacina) 
        REFERENCES dbo.VACINA (id_vacina)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,

    -- Validação: a data do próximo reforço deve ser posterior ou igual à aplicação atual
    CONSTRAINT CK_APLICACAO_DATAS CHECK (
        data_proxima_vacina IS NULL OR data_proxima_vacina >= data_aplicacao
    )
);
GO

-- ===================================================================================
-- 4. ÍNDICES DE PERFORMANCE E CONSULTAS FREQUENTES
-- ===================================================================================

-- Índice estratégico para o motor de notificações (busca rápida por período de vencimento)
CREATE NONCLUSTERED INDEX IX_APLICACAO_DATA_PROXIMA 
ON dbo.APLICACAO_VACINA (data_proxima_vacina)
INCLUDE (id_animal, id_proxima_vacina)
WHERE data_proxima_vacina IS NOT NULL;
GO

-- Índices nas Chaves Estrangeiras para otimizar JOINs
CREATE NONCLUSTERED INDEX IX_ANIMAL_ID_CLIENTE ON dbo.ANIMAL (id_cliente);
CREATE NONCLUSTERED INDEX IX_APLICACAO_ID_ANIMAL ON dbo.APLICACAO_VACINA (id_animal);
CREATE NONCLUSTERED INDEX IX_APLICACAO_ID_VACINA ON dbo.APLICACAO_VACINA (id_vacina);
CREATE NONCLUSTERED INDEX IX_APLICACAO_ID_PROXIMA_VACINA ON dbo.APLICACAO_VACINA (id_proxima_vacina);
GO

-- ===================================================================================
-- 5. CARGA DE DADOS DE TESTE (POVOAMENTO DE DEMONSTRAÇÃO)
-- ===================================================================================

-- A. Clientes
INSERT INTO dbo.CLIENTE (nome, sobrenome, telefone, rua, numero, complemento, bairro, cidade, estado, cep)
VALUES 
('Carlos', 'Eduardo Silva', '(11) 98765-4321', 'Rua das Flores', '120', 'Apto 42B', 'Jardins', 'São Paulo', 'SP', '01401-000'),
('Mariana', 'Albuquerque', '(21) 99123-8877', 'Av. Atlântica', '1500', NULL, 'Copacabana', 'Rio de Janeiro', 'RJ', '22070-001'),
('Renato', 'Ferreira Lima', '(31) 98456-1122', 'Rua da Bahia', '450', 'Casa 2', 'Lourdes', 'Belo Horizonte', 'MG', '30160-011');
GO

-- B. Animais (Cães e Gatos)
INSERT INTO dbo.ANIMAL (nome, data_nascimento, especie, raca, cor, sexo, id_cliente)
VALUES
('Thor', '2022-04-10', 'Canina', 'Golden Retriever', 'Dourado', 'M', 1),
('Luna', '2023-01-15', 'Felina', 'Siamês', 'Branco e Marrom', 'F', 1),
('Pipoca', '2021-08-20', 'Canina', 'Sem Raça Definida (SRD)', 'Caramelo', 'F', 2),
('Mimi', '2024-02-05', 'Felina', 'Persa', 'Branco', 'F', 3);
GO

-- C. Catálogo de Vacinas
INSERT INTO dbo.VACINA (nome, laboratorio, lote)
VALUES
('V10 Polivalente Canina', 'Zoetis', 'LOT-2026-V10-A'),
('Antirrábica Felina/Canina (Defensor)', 'Zoetis', 'LOT-2026-RAB-09'),
('Quádrupla Felina (Feline 4)', 'Boehringer Ingelheim', 'LOT-2026-FEL-03'),
('Giardiavax Canina', 'Zoetis', 'LOT-2026-GIA-14'),
('Leishmaniose (Leish-Tec)', 'CEVA Saúde Animal', 'LOT-2026-LEI-01');
GO

-- D. Aplicações de Vacinas e Agendamento da Próxima Dose
INSERT INTO dbo.APLICACAO_VACINA (id_animal, id_vacina, data_aplicacao, id_proxima_vacina, data_proxima_vacina)
VALUES
-- Thor tomou V10 em 01/03/2026 e terá reforço anual de V10 em 01/03/2027
(1, 1, '2026-03-01', 1, '2027-03-01'),

-- Luna (Gata) tomou Quádrupla em 10/02/2026 e precisa de reforço em 10/03/2026 (Próxima Notificação ativa!)
(2, 3, '2026-02-10', 3, '2026-03-10'),

-- Pipoca tomou Antirrábica em 15/01/2026 e precisa tomar V10 em 25/02/2026
(3, 2, '2026-01-15', 1, '2026-02-25'),

-- Mimi filhote tomou Quádrupla em 01/02/2026 e tem 2ª dose prevista para 01/03/2026
(4, 3, '2026-02-01', 3, '2026-03-01');
GO

-- ===================================================================================
-- 6. CONSULTAS DE NEGÓCIO E RELATÓRIOS DO SISTEMA
-- ===================================================================================

-- -----------------------------------------------------------------------------------
-- QUERY 1: RELATÓRIO DO MOTOR DE NOTIFICAÇÃO PREDITIVA
-- Objetivo: Identificar tutores e pets que possuem vacinas a vencer nos próximos 30 dias.
-- Esta query é a base para o disparo de mensagens via WhatsApp/SMS/E-mail.
-- -----------------------------------------------------------------------------------
SELECT 
    c.nome + ' ' + c.sobrenome          AS tutor_nome,
    c.telefone                          AS tutor_telefone,
    c.cidade + '/' + c.estado           AS tutor_localizacao,
    a.nome                              AS pet_nome,
    a.especie                           AS pet_especie,
    a.raca                              AS pet_raca,
    v_atual.nome                        AS ultima_vacina_tomada,
    av.data_aplicacao                   AS data_ultima_aplicacao,
    v_prox.nome                         AS proxima_vacina_indicada,
    av.data_proxima_vacina              AS data_reforco_previsto,
    DATEDIFF(DAY, GETDATE(), av.data_proxima_vacina) AS dias_para_vencimento
FROM dbo.APLICACAO_VACINA av
INNER JOIN dbo.ANIMAL a 
    ON av.id_animal = a.id_animal
INNER JOIN dbo.CLIENTE c 
    ON a.id_cliente = c.id_cliente
INNER JOIN dbo.VACINA v_atual 
    ON av.id_vacina = v_atual.id_vacina
LEFT JOIN dbo.VACINA v_prox 
    ON av.id_proxima_vacina = v_prox.id_vacina
WHERE av.data_proxima_vacina IS NOT NULL
ORDER BY av.data_proxima_vacina ASC;
GO

-- -----------------------------------------------------------------------------------
-- QUERY 2: CARTEIRINHA DIGITAL DE VACINAÇÃO (HISTÓRICO DO ANIMAL)
-- Exemplo: Consultar todo o histórico de vacinas do paciente 'Thor' (id_animal = 1)
-- -----------------------------------------------------------------------------------
SELECT 
    a.nome                              AS pet_nome,
    a.especie,
    v.nome                              AS vacina_aplicada,
    v.laboratorio                       AS fabricante,
    v.lote                              AS lote_fabricacao,
    CONVERT(VARCHAR(10), av.data_aplicacao, 103) AS data_aplicacao_br,
    ISNULL(v_prox.nome, 'Nenhum reforço pendente') AS proxima_vacina,
    ISNULL(CONVERT(VARCHAR(10), av.data_proxima_vacina, 103), 'N/A') AS data_proxima_vacina_br
FROM dbo.APLICACAO_VACINA av
INNER JOIN dbo.ANIMAL a 
    ON av.id_animal = a.id_animal
INNER JOIN dbo.VACINA v 
    ON av.id_vacina = v.id_vacina
LEFT JOIN dbo.VACINA v_prox 
    ON av.id_proxima_vacina = v_prox.id_vacina
WHERE a.nome = 'Thor'
ORDER BY av.data_aplicacao DESC;
GO

-- -----------------------------------------------------------------------------------
-- QUERY 3: ESTATÍSTICA DE IMUNIZAÇÃO POR LABORATÓRIO E VACINA
-- -----------------------------------------------------------------------------------
SELECT 
    v.laboratorio,
    v.nome AS vacina,
    COUNT(av.id_aplicacao) AS total_doses_aplicadas
FROM dbo.VACINA v
LEFT JOIN dbo.APLICACAO_VACINA av 
    ON v.id_vacina = av.id_vacina
GROUP BY v.laboratorio, v.nome
ORDER BY total_doses_aplicadas DESC;
GO
