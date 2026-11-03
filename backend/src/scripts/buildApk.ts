import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config({ path: path.join(__dirname, '../../.env') });

const supaUrl = (process.env.SUPABASE_URL || '').trim();
const supaAnonKey = (process.env.SUPABASE_ANON_KEY || '').trim();

const mobileDir = path.join(__dirname, '../../../mobile');
const rootApk = path.join(__dirname, '../../../luxxito-sports.apk');
const builtApk = path.join(
  mobileDir,
  'build/app/outputs/flutter-apk/app-debug.apk'
);

console.log('[APK Builder] Compilando APK con configuración Cloud de Supabase...');
const defines: string[] = [];
if (supaUrl) defines.push(`--dart-define=SUPABASE_URL=${supaUrl}`);
if (supaAnonKey) defines.push(`--dart-define=SUPABASE_ANON_KEY=${supaAnonKey}`);

execSync(`flutter build apk --debug ${defines.join(' ')}`, {
  cwd: mobileDir,
  stdio: 'inherit',
});

if (fs.existsSync(builtApk)) {
  fs.copyFileSync(builtApk, rootApk);
  console.log(`[APK Builder] ¡Listo! APK copiado en: ${rootApk}`);
}
