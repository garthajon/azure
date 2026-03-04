-- -------------------------------------------------------
--  Create Database
-- -------------------------------------------------------
CREATE DATABASE IF NOT EXISTS DATA_STORE_OLIDS_UAT_PSEUDO;
USE DATABASE DATA_STORE_OLIDS_UAT_PSEUDO;
-- -------------------------------------------------------
--  Create Schema
-- -------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS DATA_STORE_OLIDS_UAT_PSEUDO.OLIDS_MASKED;
USE SCHEMA OLIDS_MASKED;

-- -------------------------------------------------------
--  Create Table
-- -------------------------------------------------------
CREATE OR REPLACE TABLE PATIENT (
    ID NUMBER PRIMARY KEY,
    NHS_NUMBER_HASH VARCHAR(64),
    BIRTH_YEAR NUMBER(4,0),
    BIRTH_MONTH NUMBER(2,0),
    DEATH_YEAR NUMBER(4,0),
    DEATH_MONTH NUMBER(2,0),
    GENDER_CONCEPT_ID NUMBER,
    RECORD_OWNER_ORGANISATION_CODE VARCHAR(20),
    LDS_DATETIME_DATA_ACQUIRED TIMESTAMP_NTZ,
    LDS_IS_DELETED BOOLEAN
);

-- -------------------------------------------------------
--  Insert 10 Synthetic Test Records
-- (Completely fake data — not real NHS data)
-- -------------------------------------------------------
INSERT INTO PATIENT (
    ID,
    NHS_NUMBER_HASH,
    BIRTH_YEAR,
    BIRTH_MONTH,
    DEATH_YEAR,
    DEATH_MONTH,
    GENDER_CONCEPT_ID,
    RECORD_OWNER_ORGANISATION_CODE,
    LDS_DATETIME_DATA_ACQUIRED,
    LDS_IS_DELETED
)
SELECT
    ID,
    TO_VARCHAR(SHA2(NHS_RAW, 256)) AS NHS_NUMBER_HASH,
    BIRTH_YEAR,
    BIRTH_MONTH,
    DEATH_YEAR,
    DEATH_MONTH,
    GENDER_CONCEPT_ID,
    RECORD_OWNER_ORGANISATION_CODE,
    CURRENT_TIMESTAMP() AS LDS_DATETIME_DATA_ACQUIRED,
    LDS_IS_DELETED
FROM (
    SELECT * FROM VALUES
        (1,  'NHS0001', 1980, 5,  NULL, NULL, 8507, 'ORG001', NULL),
        (2,  'NHS0002', 1975, 8,  NULL, NULL, 8532, 'ORG001', FALSE),
        (3,  'NHS0003', 1990, 2,  NULL, NULL, 8507, 'ORG002', FALSE),
        (4,  'NHS0004', 1968, 11, 2020, 3,    8532, 'ORG002', FALSE),
        (5,  'NHS0005', 2001, 7,  NULL, NULL, 8507, 'ORG003', NULL),
        (6,  'NHS0006', 1955, 1,  2018, 9,    8532, 'ORG003', FALSE),
        (7,  'NHS0007', 1988, 12, NULL, NULL, 8507, 'ORG004', FALSE),
        (8,  'NHS0008', 1972, 4,  NULL, NULL, 8532, 'ORG004', FALSE),
        (9,  'NHS0009', 1995, 9,  NULL, NULL, 8507, 'ORG005', NULL),
        (10, 'NHS0010', 1983, 6,  NULL, NULL, 8532, 'ORG005', FALSE)
) v (
    ID,
    NHS_RAW,
    BIRTH_YEAR,
    BIRTH_MONTH,
    DEATH_YEAR,
    DEATH_MONTH,
    GENDER_CONCEPT_ID,
    RECORD_OWNER_ORGANISATION_CODE,
    LDS_IS_DELETED
);
-- -------------------------------------------------------
--  Verify
-- -------------------------------------------------------
SELECT * FROM PATIENT;