-- Runs automatically as the healthcare user on XEPDB1 on first container start
-- gvenzl/oracle-xe executes scripts in /container-entrypoint-initdb.d/ as APP_USER

-- Drop tables safely if they already exist
BEGIN EXECUTE IMMEDIATE 'DROP TABLE claims CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE members CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ─────────────────────────────────────────
-- MEMBERS
-- ─────────────────────────────────────────
CREATE TABLE members (
    member_id       NUMBER PRIMARY KEY,
    first_name      VARCHAR2(50),
    last_name       VARCHAR2(50),
    date_of_birth   DATE,
    gender          VARCHAR2(10),
    plan_id         VARCHAR2(20),
    enrollment_date DATE
);

INSERT INTO members VALUES (1001, 'Alice',   'Johnson',  DATE '1985-03-12', 'Female', 'PLAN-GOLD-01',   DATE '2022-01-01');
INSERT INTO members VALUES (1002, 'Bob',     'Smith',    DATE '1978-07-22', 'Male',   'PLAN-SILVER-02', DATE '2021-06-15');
INSERT INTO members VALUES (1003, 'Carol',   'Davis',    DATE '1992-11-05', 'Female', 'PLAN-GOLD-01',   DATE '2023-03-01');
INSERT INTO members VALUES (1004, 'David',   'Martinez', DATE '1965-02-28', 'Male',   'PLAN-BRONZE-03', DATE '2020-09-10');
INSERT INTO members VALUES (1005, 'Eve',     'Wilson',   DATE '1990-08-14', 'Female', 'PLAN-SILVER-02', DATE '2022-11-20');
INSERT INTO members VALUES (1006, 'Frank',   'Anderson', DATE '1955-12-01', 'Male',   'PLAN-GOLD-01',   DATE '2019-04-05');
INSERT INTO members VALUES (1007, 'Grace',   'Thomas',   DATE '2000-05-30', 'Female', 'PLAN-BRONZE-03', DATE '2023-07-15');
INSERT INTO members VALUES (1008, 'Henry',   'Jackson',  DATE '1988-09-18', 'Male',   'PLAN-SILVER-02', DATE '2021-01-01');
INSERT INTO members VALUES (1009, 'Irene',   'White',    DATE '1973-04-25', 'Female', 'PLAN-GOLD-01',   DATE '2020-02-14');
INSERT INTO members VALUES (1010, 'James',   'Harris',   DATE '1995-06-08', 'Male',   'PLAN-BRONZE-03', DATE '2024-01-01');
INSERT INTO members VALUES (1011, 'Sophia',  'Lee',      DATE '1993-04-17', 'Female', 'PLAN-GOLD-01',   DATE '2024-03-01');
INSERT INTO members VALUES (1012, 'Michael', 'Brown',    DATE '1982-09-03', 'Male',   'PLAN-SILVER-02', DATE '2024-05-10');
INSERT INTO members VALUES (1013, 'Emma',    'Taylor',   DATE '1997-12-21', 'Female', 'PLAN-BRONZE-03', DATE '2025-01-15');

-- ─────────────────────────────────────────
-- CLAIMS
-- ─────────────────────────────────────────
CREATE TABLE claims (
    claim_id        VARCHAR2(20) PRIMARY KEY,
    member_id       NUMBER REFERENCES members(member_id),
    claim_date      DATE,
    diagnosis_code  VARCHAR2(20),
    procedure_code  VARCHAR2(20),
    amount          NUMBER(10,2),
    status          VARCHAR2(20)
);

INSERT INTO claims VALUES ('CLM-0001', 1001, DATE '2024-01-10', 'J06.9',   '99213', 150.00,  'PAID');
INSERT INTO claims VALUES ('CLM-0002', 1002, DATE '2024-01-15', 'M54.5',   '99214', 220.50,  'PAID');
INSERT INTO claims VALUES ('CLM-0003', 1003, DATE '2024-02-03', 'E11.9',   '99215', 310.00,  'PENDING');
INSERT INTO claims VALUES ('CLM-0004', 1004, DATE '2024-02-20', 'I10',     '93000', 450.75,  'PAID');
INSERT INTO claims VALUES ('CLM-0005', 1005, DATE '2024-03-05', 'J45.901', '94010', 275.00,  'PAID');
INSERT INTO claims VALUES ('CLM-0006', 1006, DATE '2024-03-18', 'Z00.00',  '99396', 190.00,  'DENIED');
INSERT INTO claims VALUES ('CLM-0007', 1007, DATE '2024-04-01', 'S93.401', '29540', 820.00,  'PAID');
INSERT INTO claims VALUES ('CLM-0008', 1008, DATE '2024-04-22', 'K21.0',   '43239', 1250.00, 'PENDING');
INSERT INTO claims VALUES ('CLM-0009', 1009, DATE '2024-05-10', 'F32.1',   '90834', 180.00,  'PAID');
INSERT INTO claims VALUES ('CLM-0010', 1010, DATE '2024-05-28', 'N39.0',   '99213', 140.00,  'PAID');

COMMIT;
