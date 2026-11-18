-- KAN-986 follow-up (PEER 16482): cron_job_run_details_prune deletes by primary-key ranges, under a time budget.
--
-- 20261117164404's version ran up to 10 x "DELETE ... WHERE runid IN (SELECT ... ORDER BY runid LIMIT 100000)", each a
-- sequential scan plus sort of cron.job_run_details, in ONE cron statement under the cluster statement_timeout of 2 min.
-- Live record (job 13): the first run, 2026-11-17 17:23, failed "canceling statement due to statement timeout"; the
-- 18:23 run succeeded in 107 s, only just under the limit; later runs took 6-60 s once the backlog was gone
-- (2026-11-18 05:04: 57 492 rows, 248 older than 7 days).
-- New body (same signature, CREATE OR REPLACE, ACL kept):
--   1. the cutoff runid is found ONCE by a binary search over runid through the primary key (runid grows with
--      start_time), about 20 index probes, no sequential scan;
--   2. rows are deleted in runid ranges of p_batch (default 10 000) from the smallest runid up to the cutoff, each a
--      primary-key range scan; a row is deleted only if it also ended (or started, when still running) before the cutoff;
--   3. the run stops after p_max_batches ranges or 90 s of work, whichever comes first; the next hourly run continues.
-- The cron command is changed with cron.alter_job to "SET statement_timeout = '15min'; SELECT ...", so even a slow
-- run is not cancelled at 2 min.

DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.cron_job_run_details_prune(interval,integer,integer)'::regprocedure))
       <> '7ef38a724be66ea90fa17785253ebd10' THEN
    RAISE EXCEPTION 'KAN-986c pre: cron_job_run_details_prune is not the 20261117164404 version';
  END IF;
  IF (SELECT command FROM cron.job WHERE jobname = 'kan986_prune_cron_run_details_hourly')
       IS DISTINCT FROM 'SELECT public.cron_job_run_details_prune()' THEN
    RAISE EXCEPTION 'KAN-986c pre: prune job command changed';
  END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.cron_job_run_details_prune(
  p_keep interval DEFAULT '7 days', p_batch integer DEFAULT 10000, p_max_batches integer DEFAULT 1000)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_cut   timestamptz := now() - p_keep;
  v_t0    timestamptz := clock_timestamp();
  v_lo    bigint;
  v_hi    bigint;
  v_top   bigint;
  v_mid   bigint;
  v_st    timestamptz;
  v_total bigint := 0;
  v_n     bigint;
  v_i     integer := 0;
BEGIN
  IF p_keep IS NULL OR p_keep < interval '1 day' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'cron_job_run_details_prune: keep at least 1 day';
  END IF;

  SELECT min(runid), max(runid) INTO v_lo, v_top FROM cron.job_run_details;   -- primary key ends
  IF v_lo IS NULL THEN RETURN 0; END IF;

  -- binary search: v_hi = the largest runid whose next row started before the cutoff
  v_hi := v_lo - 1;
  WHILE v_lo <= v_top LOOP
    v_mid := v_lo + (v_top - v_lo) / 2;
    SELECT d.start_time INTO v_st FROM cron.job_run_details d WHERE d.runid >= v_mid ORDER BY d.runid LIMIT 1;
    IF v_st IS NOT NULL AND v_st < v_cut THEN
      v_hi := v_mid; v_lo := v_mid + 1;
    ELSE
      v_top := v_mid - 1;
    END IF;
  END LOOP;

  SELECT min(runid) INTO v_lo FROM cron.job_run_details;
  WHILE v_lo <= v_hi AND v_i < p_max_batches AND clock_timestamp() - v_t0 < interval '90 seconds' LOOP
    DELETE FROM cron.job_run_details d
     WHERE d.runid >= v_lo AND d.runid < v_lo + p_batch AND d.runid <= v_hi
       AND coalesce(d.end_time, d.start_time) < v_cut;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_total := v_total + v_n;
    v_lo := v_lo + p_batch;
    v_i := v_i + 1;
  END LOOP;
  RETURN v_total;
END;
$function$;

SELECT cron.alter_job((SELECT jobid FROM cron.job WHERE jobname = 'kan986_prune_cron_run_details_hourly'),
                      command := $cmd$SET statement_timeout = '15min'; SELECT public.cron_job_run_details_prune()$cmd$);

DO $post$
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.cron_job_run_details_prune(interval,integer,integer)'::regprocedure)
       IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR (SELECT command FROM cron.job WHERE jobname = 'kan986_prune_cron_run_details_hourly')
       IS DISTINCT FROM $cmd$SET statement_timeout = '15min'; SELECT public.cron_job_run_details_prune()$cmd$
     OR NOT (SELECT active FROM cron.job WHERE jobname = 'kan986_prune_cron_run_details_hourly') THEN
    -- the retention job (kan986_notifications_retention_daily) is not touched here; its on/off state is not asserted
    RAISE EXCEPTION 'KAN-986c post: ACL, job command or prune job state not as intended';
  END IF;
  IF pg_get_functiondef('public.cron_job_run_details_prune(interval,integer,integer)'::regprocedure) ~ 'IN \(SELECT' THEN
    RAISE EXCEPTION 'KAN-986c post: old IN (SELECT ...) delete still present';
  END IF;
END
$post$;
