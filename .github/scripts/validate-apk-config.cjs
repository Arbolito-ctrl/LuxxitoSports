const { URL } = require('node:url');

function validateApiUrl(value) {
  if (!value || /[\s()]/.test(value)) {
    throw new Error('API_BASE_URL debe ser una URL HTTPS sin espacios ni paréntesis.');
  }
  let url;
  try { url = new URL(value); } catch {
    throw new Error('API_BASE_URL no tiene un formato de URL válido.');
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new Error('API_BASE_URL debe usar HTTPS, sin credenciales, query ni fragmento.');
  }
  const host = url.hostname.toLowerCase();
  if (host === 'localhost' || !host.includes('.') || /^\d+\.\d+\.\d+\.\d+$/.test(host)) {
    throw new Error('API_BASE_URL debe apuntar a un dominio público, no una IP local/emulador.');
  }
  if (url.pathname !== '/api') {
    throw new Error('API_BASE_URL debe terminar exactamente en /api, sin barra final.');
  }
  return url.href;
}

if (require.main === module) {
  try {
    validateApiUrl(process.env.API_BASE_URL);
    console.log('Configuración del APK válida: API HTTPS pública. No se imprimen secretos.');
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = { validateApiUrl };
