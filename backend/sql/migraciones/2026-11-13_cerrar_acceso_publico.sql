-- ============================================================================
-- Migración 2026-11-13: cerrar el acceso público (anon key) a datos y funciones
-- ============================================================================
--
-- PROBLEMA
-- La anon key de Supabase es pública: viaja dentro del APK y cualquiera puede
-- extraerla. Con ella se podía, sin pasar por la API:
--   1. Ejecutar las funciones rpc_* (SECURITY DEFINER). Las de ADMIN solo
--      comprobaban el parámetro p_rol que envía el cliente, así que bastaba con
--      enviar p_rol = 'ADMIN' para, por ejemplo, aprobar el propio pago sin
--      pagar y obtener un Ticket QR válido.
--   2. Leer todas las reservas y pagos (políticas USING (true)): nombre, DNI,
--      teléfono y correo de todos los clientes, y los números de operación.
--
-- POR QUÉ SE PUEDE CERRAR SIN ROMPER NADA
-- - La app solo usa la API propia (el APK se compila con ALLOW_SUPABASE_DIRECT=false).
-- - La API se conecta con DATABASE_URL como dueño de las tablas (db_mode
--   POSTGRES_POOL) y no llama a ninguna función rpc_*.
-- - El catálogo (complejos, canchas, extras) sigue siendo de lectura pública:
--   no tiene datos personales.
--
-- No se borra ninguna función ni dato: solo se quitan permisos. Para deshacerlo,
-- ver el bloque "REVERTIR" al final.
--
-- Cómo aplicarlo: Supabase → SQL Editor → pegar y ejecutar este archivo, o
--   psql "$DATABASE_URL" -f backend/sql/migraciones/2026-11-13_cerrar_acceso_publico.sql
-- ============================================================================

BEGIN;

-- 1. Funciones rpc_*: nadie fuera del servidor puede ejecutarlas.
--    En PostgreSQL las funciones se crean con EXECUTE para PUBLIC, por eso se
--    revoca también a PUBLIC (no basta con anon y authenticated).
DO $$
DECLARE
    f RECORD;
BEGIN
    FOR f IN
        SELECT p.oid::regprocedure AS firma
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname LIKE 'rpc\_%'
    LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.firma);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.firma);
    END LOOP;
END $$;

-- 2. Reservas, extras de reservas y pagos: sin lectura pública (datos personales).
DROP POLICY IF EXISTS "anon_select_reservas" ON reservas;
DROP POLICY IF EXISTS "anon_select_reserva_extras" ON reserva_extras;
DROP POLICY IF EXISTS "anon_select_pagos" ON pagos;
REVOKE SELECT ON reservas, reserva_extras, pagos FROM anon, authenticated;

-- 3. Que las funciones que se creen en el futuro tampoco nazcan públicas.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

COMMIT;

-- ============================================================================
-- VERIFICACIÓN (debe devolver 0 filas en ambas consultas)
-- ============================================================================
-- Funciones rpc_* que anon todavía puede ejecutar:
--   SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname = 'public' AND p.proname LIKE 'rpc\_%'
--     AND has_function_privilege('anon', p.oid, 'EXECUTE');
--
-- Tablas con datos personales que anon todavía puede leer:
--   SELECT t FROM unnest(ARRAY['reservas','reserva_extras','pagos','usuarios']) AS t
--   WHERE has_table_privilege('anon', 'public.' || t, 'SELECT');

-- ============================================================================
-- REVERTIR (solo si hiciera falta volver al estado anterior)
-- ============================================================================
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
-- GRANT SELECT ON reservas, reserva_extras, pagos TO anon, authenticated;
-- CREATE POLICY "anon_select_reservas" ON reservas FOR SELECT TO anon, authenticated USING (true);
-- CREATE POLICY "anon_select_reserva_extras" ON reserva_extras FOR SELECT TO anon, authenticated USING (true);
-- CREATE POLICY "anon_select_pagos" ON pagos FOR SELECT TO anon, authenticated USING (true);
