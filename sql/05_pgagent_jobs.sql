-- ============================================================
-- BLM4522 — Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma
-- BÖLÜM 5: ZAMANLAYICI — pgAGENT JOB TANIMLAMALARI
-- ============================================================
-- Proje maddesi: "Zamanlayıcılarla Yedekleme"
-- SQL Server Agent muadili: pgAgent (PostgreSQL extension)
-- Her yedek tipi için ayrı job tanımlanmıştır.
-- ============================================================

-- 5.1 Haftalık TAM yedek: Her Pazar 01:00
DO $$
DECLARE v_job_id INT;
BEGIN
    INSERT INTO pgagent.pga_job (jobjclid, jobname, jobdesc, jobhostagent, jobenabled)
    VALUES (1, 'DR_Weekly_Full_Backup', 'Her Pazar 01:00 tam yedek', '', TRUE)
    RETURNING jobid INTO v_job_id;

    INSERT INTO pgagent.pga_jobstep (jstjobid, jstname, jstenabled, jstkind, jstcode, jstdbname)
    VALUES (v_job_id, 'Full_Backup_Step', TRUE, 's',
            'SELECT * FROM recovery_mgmt.take_full_backup(''northwind'');',
            'northwind');

    INSERT INTO pgagent.pga_schedule
        (jscjobid, jscname, jscenabled, jscstart, jscminutes, jschours, jscweekdays, jscmonthdays, jscmonths)
    VALUES (v_job_id, 'Weekly_Sunday_01_00', TRUE, NOW(),
        '{t,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
        '{f,t,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
        '{t,f,f,f,f,f,f}',
        '{f,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,f}',
        '{t,t,t,t,t,t,t,t,t,t,t,t}');

    RAISE NOTICE 'Full Backup Job olusturuldu. ID: %', v_job_id;
END;
$$;

-- 5.2 ARTIK yedek: Her 6 saatte bir
--     En son başarılı FULL yedek dinamik olarak seçilir
DO $$
DECLARE v_job_id INT;
BEGIN
    INSERT INTO pgagent.pga_job (jobjclid, jobname, jobdesc, jobhostagent, jobenabled)
    VALUES (1, 'DR_Incremental_Backup_6h', 'Her 6 saatte bir artik yedek', '', TRUE)
    RETURNING jobid INTO v_job_id;

    INSERT INTO pgagent.pga_jobstep (jstjobid, jstname, jstenabled, jstkind, jstcode, jstdbname)
    VALUES (v_job_id, 'Incremental_Backup_Step', TRUE, 's',
        -- En güncel FULL yedek id'si ile ARTIK yedek çalıştır
        'SELECT * FROM recovery_mgmt.take_incremental_backup(
            (SELECT record_id FROM recovery_mgmt.backup_record
             WHERE backup_type = ''FULL'' AND status = ''SUCCESS''
             ORDER BY started_at DESC LIMIT 1)
        );',
        'northwind');

    RAISE NOTICE 'Incremental Backup Job olusturuldu. ID: %', v_job_id;
END;
$$;

-- 5.3 FARK yedek: Her gece 23:00
DO $$
DECLARE v_job_id INT;
BEGIN
    INSERT INTO pgagent.pga_job (jobjclid, jobname, jobdesc, jobhostagent, jobenabled)
    VALUES (1, 'DR_Differential_Backup_Daily', 'Her gece 23:00 fark yedegi', '', TRUE)
    RETURNING jobid INTO v_job_id;

    INSERT INTO pgagent.pga_jobstep (jstjobid, jstname, jstenabled, jstkind, jstcode, jstdbname)
    VALUES (v_job_id, 'Differential_Backup_Step', TRUE, 's',
        'SELECT * FROM recovery_mgmt.take_differential_backup(
            (SELECT record_id FROM recovery_mgmt.backup_record
             WHERE backup_type = ''FULL'' AND status = ''SUCCESS''
             ORDER BY started_at DESC LIMIT 1)
        );',
        'northwind');

    INSERT INTO pgagent.pga_schedule
        (jscjobid, jscname, jscenabled, jscstart, jscminutes, jschours, jscweekdays, jscmonthdays, jscmonths)
    VALUES (v_job_id, 'Daily_23_00', TRUE, NOW(),
        '{t,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
        '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,t}',
        '{t,t,t,t,t,t,t}',
        '{f,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,f}',
        '{t,t,t,t,t,t,t,t,t,t,t,t}');

    RAISE NOTICE 'Differential Backup Job olusturuldu. ID: %', v_job_id;
END;
$$;

-- Tanımlanan job'ları listele
SELECT jobid, jobname, jobenabled FROM pgagent.pga_job ORDER BY jobid;
