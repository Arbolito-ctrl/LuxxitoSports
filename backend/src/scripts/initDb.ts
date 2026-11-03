import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { getDbMode, getPgPool } from '../config/database';

dotenv.config();

async function initDatabase() {
  const mode = getDbMode();
  if (mode !== 'POSTGRES_POOL') {
    console.log(
      '[db:init] Para ejecutar la migración SQL directa desde consola, configura DATABASE_URL en backend/.env.'
    );
    console.log(
      '[db:init] También puedes copiar y ejecutar backend/sql/schema.sql y backend/sql/seed.sql directamente en el SQL Editor de tu panel de Supabase.'
    );
    return;
  }

  const pool = getPgPool();
  const schemaSql = fs.readFileSync(
    path.join(__dirname, '../../sql/schema.sql'),
    'utf-8'
  );
  const seedSql = fs.readFileSync(
    path.join(__dirname, '../../sql/seed.sql'),
    'utf-8'
  );

  try {
    console.log('[db:init] Creando tablas, índices, RLS, bucket comprobantes y funciones RPC en Supabase PostgreSQL...');
    await pool.query(schemaSql);
    console.log('[db:init] Insertando datos semilla en Supabase PostgreSQL...');
    await pool.query(seedSql);

    const rlsCheck = await pool.query(
      "SELECT relname, relrowsecurity FROM pg_class WHERE relname IN ('usuarios','complejos','canchas','extras','reservas','reserva_extras','pagos') ORDER BY relname"
    );
    console.log('[db:init] Estado RLS en tablas:', rlsCheck.rows);

    const bucketCheck = await pool.query(
      "SELECT id, name, public FROM storage.buckets WHERE id = 'comprobantes'"
    );
    console.log('[db:init] Bucket Storage comprobantes:', bucketCheck.rows);

    console.log('[db:init] ¡Base de datos Supabase inicializada exitosamente!');
  } catch (error) {
    console.error('[db:init] Error al inicializar la base de datos:', error);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

initDatabase();
