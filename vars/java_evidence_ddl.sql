-- =====================================================================
-- Java Footprint Evidence — schema upgrade (Tier 1 + Tier 2)
-- Run ONCE per repository (US: mtaheri@dbai, EU: mtaheri@DBAINFO).
-- Idempotent: re-running is safe; ALTERs / CREATE are guarded.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON

-- ---------------------------------------------------------------------
-- 1) Add per-install evidence columns to JAVA_SCAN_INSTALLS
-- ---------------------------------------------------------------------
DECLARE
  PROCEDURE add_col(p_col VARCHAR2, p_def VARCHAR2) IS
    n NUMBER;
  BEGIN
    SELECT COUNT(*) INTO n
      FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'JAVA_SCAN_INSTALLS' AND COLUMN_NAME = p_col;
    IF n = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE JAVA_SCAN_INSTALLS ADD ('||p_col||' '||p_def||')';
      DBMS_OUTPUT.PUT_LINE('  + added '||p_col);
    ELSE
      DBMS_OUTPUT.PUT_LINE('  = '||p_col||' already present');
    END IF;
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('JAVA_SCAN_INSTALLS — adding evidence columns:');
  add_col('IS_SYMLINK',              'VARCHAR2(1)');
  add_col('RPM_OWNER',               'VARCHAR2(256)');
  add_col('RPM_INSTALL_DATE',        'VARCHAR2(40)');
  add_col('RUNTIME_NAME',            'VARCHAR2(256)');
  add_col('IS_HEADLESS',             'VARCHAR2(1)');
  add_col('IS_ALTERNATIVES_DEFAULT', 'VARCHAR2(1)');
  add_col('LIVE_PROCS',              'NUMBER');
END;
/

-- ---------------------------------------------------------------------
-- 2) Create JAVA_HOST_EVIDENCE (host-level Tier-2 evidence)
-- ---------------------------------------------------------------------
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM USER_TABLES WHERE TABLE_NAME = 'JAVA_HOST_EVIDENCE';
  IF n = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE JAVA_HOST_EVIDENCE (
        RUN_ID                NUMBER         NOT NULL,
        HOSTNAME              VARCHAR2(256)  NOT NULL,
        CHECK_TS              TIMESTAMP      DEFAULT SYSTIMESTAMP,
        RUNNING_PROC_COUNT    NUMBER,
        RUNNING_PROC_USERS    VARCHAR2(500),
        RUNNING_PROC_HOMES    VARCHAR2(2000),
        LISTENING_PORTS       VARCHAR2(500),
        ENV_REFS_COUNT        NUMBER,
        ENV_REFS_FILES        VARCHAR2(2000),
        SYSTEMD_UNITS         VARCHAR2(2000),
        CRON_REFS             VARCHAR2(2000),
        LEGACY_RPMS_PRESENT   VARCHAR2(500),
        ALTERNATIVES_TARGET   VARCHAR2(500),
        CONSTRAINT JAVA_HOST_EVIDENCE_PK PRIMARY KEY (RUN_ID, HOSTNAME)
      )
    ]';
    DBMS_OUTPUT.PUT_LINE('JAVA_HOST_EVIDENCE — created');
    EXECUTE IMMEDIATE 'CREATE INDEX JAVA_HOST_EVIDENCE_IX1 ON JAVA_HOST_EVIDENCE (HOSTNAME)';
    DBMS_OUTPUT.PUT_LINE('JAVA_HOST_EVIDENCE_IX1 — created');
  ELSE
    DBMS_OUTPUT.PUT_LINE('JAVA_HOST_EVIDENCE — already present');
  END IF;
END;
/

-- ---------------------------------------------------------------------
-- 3) Convenience view: latest evidence per host
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW V_JAVA_HOST_EVIDENCE_LATEST AS
SELECT e.*
  FROM JAVA_HOST_EVIDENCE e
 WHERE (e.HOSTNAME, e.RUN_ID) IN
       (SELECT HOSTNAME, MAX(RUN_ID) FROM JAVA_HOST_EVIDENCE GROUP BY HOSTNAME);

-- ---------------------------------------------------------------------
-- 4) Sanity check
-- ---------------------------------------------------------------------
PROMPT
PROMPT === Verification ===
SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH
  FROM USER_TAB_COLUMNS
 WHERE TABLE_NAME = 'JAVA_SCAN_INSTALLS'
   AND COLUMN_NAME IN ('IS_SYMLINK','RPM_OWNER','RPM_INSTALL_DATE',
                       'RUNTIME_NAME','IS_HEADLESS','IS_ALTERNATIVES_DEFAULT','LIVE_PROCS')
 ORDER BY COLUMN_ID;

SELECT TABLE_NAME FROM USER_TABLES WHERE TABLE_NAME = 'JAVA_HOST_EVIDENCE';

EXIT;
