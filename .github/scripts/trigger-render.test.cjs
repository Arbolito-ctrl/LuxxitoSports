const { test } = require('node:test');
const assert = require('node:assert/strict');
const triggerRender = require('./trigger-render.cjs');
const hook = 'https://api.render.com/deploy/srv-dbkt1bgu01pc73e8amu0?key=fake-test-only';
function setup(overrides = {}) {
  return { hook, github: { rest: { repos: { getBranch: async () => ({ data: { commit: { sha: 'abc123' } } }) } } },
    context: { eventName: 'push', ref: 'refs/heads/main', sha: 'abc123', repo: { owner: 'Arbolito-ctrl', repo: 'LuxxitoSports' } },
    core: { notice() {} }, fetchImpl: async () => { throw new Error('Unexpected network call'); }, ...overrides };
}
test('solo despliega el SHA probado de main y conserva el secreto en la petición', async () => {
  let calls = 0;
  await triggerRender(setup({ fetchImpl: async (url, options) => {
    calls++; assert.equal(url.searchParams.get('ref'), 'abc123');
    assert.equal(url.searchParams.get('key'), 'fake-test-only'); assert.equal(options.method, 'POST');
    assert.equal(options.redirect, 'error'); return { status: 200 };
  } }));
  assert.equal(calls, 1);
});
test('no despliega PR, develop ni un commit que dejó de ser el último', async () => {
  const base = setup();
  await triggerRender(setup({ context: { ...base.context, eventName: 'pull_request' } }));
  await triggerRender(setup({ context: { ...base.context, ref: 'refs/heads/develop' } }));
  await triggerRender(setup({ context: { ...base.context, sha: 'old' } }));
});
test('rechaza configuración ausente o un servicio distinto sin enviar secretos', async () => {
  await assert.rejects(triggerRender(setup({ hook: '' })), /Falta configurar/);
  await assert.rejects(triggerRender(setup({ hook: 'https://example.com/deploy?key=fake-test-only' })), /no corresponde/);
});
test('errores de red y HTTP no divulgan la dirección privada', async () => {
  await assert.rejects(triggerRender(setup({ fetchImpl: async () => { throw new Error(hook); } })), error => !error.message.includes('fake-test-only'));
  await assert.rejects(triggerRender(setup({ fetchImpl: async () => ({ status: 401 }) })), /HTTP 401/);
});
