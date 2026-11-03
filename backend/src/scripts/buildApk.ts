import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config({ path: path.join(__dirname, '../../.env') });

const supaUrl = (process.env.SUPABASE_URL || '').trim();
const supaAnonKey = (process.env.SUPABASE_ANON_KEY || '').trim();

const mobileDir = path.join(__dirname, '../../../mobile');
const releaseDir = path.join(__dirname, '../../../release');
const releaseDest = path.join(releaseDir, 'luxxito-sports.apk');
const builtReleaseApk = path.join(
  mobileDir,
  'build/app/outputs/flutter-apk/app-release.apk'
);

console.log('[APK Builder] Compilando APK Release optimizado con Supabase Cloud...');
const defines: string[] = [];
if (supaUrl) defines.push(`--dart-define=SUPABASE_URL=${supaUrl}`);
if (supaAnonKey) defines.push(`--dart-define=SUPABASE_ANON_KEY=${supaAnonKey}`);

execSync(`flutter build apk --release ${defines.join(' ')}`, {
  cwd: mobileDir,
  stdio: 'inherit',
});

if (!fs.existsSync(releaseDir)) {
  fs.mkdirSync(releaseDir, { recursive: true });
}

if (fs.existsSync(builtReleaseApk)) {
  fs.copyFileSync(builtReleaseApk, releaseDest);
  const sizeMb = (fs.statSync(releaseDest).size / (1024 * 1024)).toFixed(2);
  console.log(`[APK Builder] ¡Listo! APK Release (${sizeMb} MB) en: ${releaseDest}`);
}
