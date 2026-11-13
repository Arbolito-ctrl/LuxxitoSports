import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';
import dotenv from 'dotenv';

dotenv.config({ path: path.join(__dirname, '../../.env') });

const apiBaseUrl = (process.env.API_BASE_URL || '').trim();

const mobileDir = path.join(__dirname, '../../../mobile');
const releaseDir = path.join(__dirname, '../../../release');
const releaseDest = path.join(releaseDir, 'luxxito-sports.apk');
const builtReleaseApk = path.join(
  mobileDir,
  'build/app/outputs/flutter-apk/app-release.apk'
);

if (!apiBaseUrl || !/^https:\/\/[^\s()]+\/api$/.test(apiBaseUrl)) {
  throw new Error('Configura API_BASE_URL con la URL HTTPS pública terminada en /api.');
}

console.log('[APK Builder] Compilando APK Release conectado a la API propia...');
// Las variables no se interpolan en comandos: Flutter las lee de un JSON temporal.
// El APK solo recibe la URL de la API: ninguna clave de Supabase viaja dentro de la app.
const configDir = fs.mkdtempSync(path.join(os.tmpdir(), 'luxxito-apk-'));
const configPath = path.join(configDir, 'defines.json');
fs.writeFileSync(configPath, JSON.stringify({
  API_BASE_URL: apiBaseUrl,
}), { mode: 0o600 });
try {
  const defineArg = `--dart-define-from-file=${configPath}`;
  const result = process.platform === 'win32'
    ? spawnSync(`flutter build apk --release "${defineArg}"`, { cwd: mobileDir, stdio: 'inherit', shell: true })
    : spawnSync('flutter', ['build', 'apk', '--release', defineArg], { cwd: mobileDir, stdio: 'inherit' });
  if (result.error || result.status !== 0) {
    throw new Error('Falló la compilación Flutter. Revisa la salida anterior.');
  }
} finally {
  fs.rmSync(configPath, { force: true });
  fs.rmdirSync(configDir);
}

if (!fs.existsSync(releaseDir)) {
  fs.mkdirSync(releaseDir, { recursive: true });
}

if (fs.existsSync(builtReleaseApk)) {
  fs.copyFileSync(builtReleaseApk, releaseDest);
  const sizeMb = (fs.statSync(releaseDest).size / (1024 * 1024)).toFixed(2);
  console.log(`[APK Builder] ¡Listo! APK Release (${sizeMb} MB) en: ${releaseDest}`);
}
