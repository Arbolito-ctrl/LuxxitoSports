import dotenv from 'dotenv';
import { Pool } from 'pg';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

dotenv.config();

export type DbMode = 'POSTGRES_POOL' | 'SUPABASE_REST' | 'LOCAL_STORE';

let pgPool: Pool | null = null;
let supabaseClient: SupabaseClient | null = null;

function isPlaceholder(val?: string): boolean {
  if (!val || val.trim() === '') return true;
  if (val.includes('tu_proyecto') || val.includes('tu_password') || val.includes('tu_supabase')) {
    return true;
  }
  return false;
}

export function getDbMode(): DbMode {
  if (process.env.NODE_ENV === 'test') {
    return 'LOCAL_STORE';
  }
  const dbUrl = process.env.DATABASE_URL;
  if (!isPlaceholder(dbUrl)) {
    return 'POSTGRES_POOL';
  }
  const supaUrl = process.env.SUPABASE_URL;
  const supaKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
  if (!isPlaceholder(supaUrl) && !isPlaceholder(supaKey)) {
    return 'SUPABASE_REST';
  }
  return 'LOCAL_STORE';
}

export function getPgPool(): Pool {
  if (!pgPool) {
    pgPool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 10000,
      statement_timeout: 10000,
    });
  }
  return pgPool;
}

export function getSupabaseClient(): SupabaseClient {
  if (!supabaseClient) {
    const url = process.env.SUPABASE_URL!;
    const key = (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY)!;
    supabaseClient = createClient(url, key, {
      auth: { persistSession: false },
    });
  }
  return supabaseClient;
}
