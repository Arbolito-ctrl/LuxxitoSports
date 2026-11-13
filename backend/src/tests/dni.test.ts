import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import app from '../app';
import { dniService } from '../services/dniService';

// Las pruebas simulan a Decolecta: no gastan consultas reales ni necesitan el token real.
const respuestaDecolecta = {
  first_name: 'JUAN CARLOS',
  first_last_name: 'PEREZ',
  second_last_name: 'GARCIA',
  full_name: 'PEREZ GARCIA, JUAN CARLOS',
  document_number: '46027897',
  // Un campo extra que la API NO debe reenviar a la app
  direccion: 'AV. SECRETA 123',
};

function simularDecolecta(status: number, cuerpo: unknown = respuestaDecolecta) {
  const fetchFalso = vi.fn().mockResolvedValue(
    new Response(JSON.stringify(cuerpo), { status, headers: { 'Content-Type': 'application/json' } })
  );
  vi.stubGlobal('fetch', fetchFalso);
  return fetchFalso;
}

// Cada prueba usa una IP distinta para no chocar con el límite de consultas
let ipPrueba = 0;
const consultar = (dni: string) =>
  request(app).get(`/api/dni/${dni}`).set('X-Forwarded-For', `10.0.0.${++ipPrueba}`);

describe('GET /api/dni/:numero — sugerencia de nombre para el registro', () => {
  beforeEach(() => {
    process.env.DECOLECTA_TOKEN = 'token-de-prueba';
    dniService.limpiarCache();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    delete process.env.DECOLECTA_TOKEN;
  });

  it('devuelve solo nombres y apellidos, y envía el token como Bearer', async () => {
    const fetchFalso = simularDecolecta(200);

    const res = await consultar('46027897');

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      dni: '46027897',
      nombres: 'JUAN CARLOS',
      apellido_paterno: 'PEREZ',
      apellido_materno: 'GARCIA',
      nombre_completo: 'JUAN CARLOS PEREZ GARCIA',
    });
    expect(JSON.stringify(res.body)).not.toContain('SECRETA');

    const [url, opciones] = fetchFalso.mock.calls[0];
    expect(url).toBe('https://api.decolecta.com/v1/reniec/dni?numero=46027897');
    expect(opciones.headers.Authorization).toBe('Bearer token-de-prueba');
  });

  it('guarda la respuesta en caché para no gastar otra consulta', async () => {
    const fetchFalso = simularDecolecta(200);

    await consultar('46027897');
    const segunda = await consultar('46027897');

    expect(segunda.status).toBe(200);
    expect(fetchFalso).toHaveBeenCalledTimes(1);
  });

  it('rechaza un DNI mal escrito sin llamar al proveedor (400)', async () => {
    const fetchFalso = simularDecolecta(200);

    const res = await consultar('1234');

    expect(res.status).toBe(400);
    expect(fetchFalso).not.toHaveBeenCalled();
  });

  it('responde 404 si el proveedor no encuentra el DNI', async () => {
    simularDecolecta(400, { error: 'Invalid request' });

    const res = await consultar('00000001');

    expect(res.status).toBe(404);
    expect(res.body.code).toBe('NOT_FOUND');
  });

  it('responde 503 si no hay token configurado (el registro sigue funcionando sin sugerencia)', async () => {
    delete process.env.DECOLECTA_TOKEN;
    const fetchFalso = simularDecolecta(200);

    const res = await consultar('46027897');

    expect(res.status).toBe(503);
    expect(res.body.code).toBe('DNI_LOOKUP_UNAVAILABLE');
    expect(fetchFalso).not.toHaveBeenCalled();
  });

  it('responde 503 si el token es inválido o se acabó la cuota', async () => {
    simularDecolecta(401, { error: 'Unauthorized' });
    vi.spyOn(console, 'error').mockImplementation(() => {});

    const res = await consultar('46027897');

    expect(res.status).toBe(503);
  });

  it('responde 503 si el proveedor no contesta', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('timeout')));

    const res = await consultar('46027897');

    expect(res.status).toBe(503);
  });

  it('limita a 10 consultas por minuto por IP (429)', async () => {
    simularDecolecta(200);
    const ip = '10.9.9.9';

    for (let i = 0; i < 10; i++) {
      const ok = await request(app).get('/api/dni/46027897').set('X-Forwarded-For', ip);
      expect(ok.status).toBe(200);
    }
    const bloqueada = await request(app).get('/api/dni/46027897').set('X-Forwarded-For', ip);

    expect(bloqueada.status).toBe(429);
    expect(bloqueada.body.code).toBe('TOO_MANY_REQUESTS');
    expect(bloqueada.headers['retry-after']).toBeDefined();
  });
});
