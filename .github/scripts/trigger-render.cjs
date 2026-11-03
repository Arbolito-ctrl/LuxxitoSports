'use strict';

module.exports = async function triggerRender({ github, context, core, hook, fetchImpl = fetch }) {
  if (context.eventName !== 'push' || context.ref !== 'refs/heads/main') return;
  const branch = await github.rest.repos.getBranch({ ...context.repo, branch: 'main' });
  if (branch.data.commit.sha !== context.sha) {
    core.notice('Se omite el despliegue: main ya contiene un commit posterior.');
    return;
  }
  let url;
  try { url = new URL(hook); } catch { throw new Error('Falta configurar RENDER_DEPLOY_HOOK_URL.'); }
  if (url.origin !== 'https://api.render.com' || url.pathname !== '/deploy/srv-dbkt1bgu01pc73e8amu0') {
    throw new Error('El hook no corresponde al servicio Render de Luxxito Sports.');
  }
  url.searchParams.set('ref', context.sha);
  let response;
  try {
    response = await fetchImpl(url, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(20000) });
  } catch {
    // No propagar errores de red que puedan incluir la URL privada.
    throw new Error('No se pudo contactar al servicio de despliegue de Render.');
  }
  if (![200, 202].includes(response.status)) throw new Error(`Render rechazó el despliegue (HTTP ${response.status}).`);
  core.notice(`Render aceptó el despliegue del commit ${context.sha} (HTTP ${response.status}).`);
};
