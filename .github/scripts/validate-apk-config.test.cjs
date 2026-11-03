const test = require('node:test');
const assert = require('node:assert/strict');
const { validateApiUrl } = require('./validate-apk-config.cjs');

test('acepta una API HTTPS pública terminada en /api', () => {
  assert.equal(validateApiUrl('https://luxxito-sports-api.onrender.com/api'), 'https://luxxito-sports-api.onrender.com/api');
});

test('rechaza el valor descriptivo con paréntesis que rompía el shell', () => {
  assert.throws(() => validateApiUrl('SUPABASE_CLOUD (https://example.supabase.co)'));
});

test('rechaza configuración incompleta o local antes de compilar', () => {
  for (const value of [undefined, '', 'http://10.0.2.2:3000/api', 'http://localhost:3000/api', 'https://192.168.1.14/api', 'https://api.example.com/api/', 'https://api.example.com/api?key=secret', 'https://user:secret@api.example.com/api']) {
    assert.throws(() => validateApiUrl(value));
  }
});
