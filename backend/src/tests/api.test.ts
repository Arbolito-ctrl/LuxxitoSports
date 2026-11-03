import { describe, it, expect, beforeEach, vi } from 'vitest';
import request from 'supertest';
import app from '../app';
import { signJwtToken } from '../middlewares/authMiddleware';
import { dataRepository } from '../repositories/dataRepository';

// Generar una fecha futura (dentro de 5 días) para pruebas de reservas válidas
function getFutureDate(daysAhead: number = 5): string {
  const d = new Date(Date.now() + daysAhead * 24 * 60 * 60 * 1000);
  return d.toISOString().split('T')[0];
}

const titular = (dni: string) => ({
  cliente_nombre: `Jugador ${dni}`,
  cliente_dni: dni,
  cliente_telefono: '987000111',
  cliente_email: `jugador${dni}@uni.pe`,
});

const adminToken = signJwtToken({
  id: 2,
  email: 'admin@luxxitosports.pe',
  dni: '70001111',
  rol: 'ADMIN',
});

const jugadorToken = signJwtToken({
  id: 1,
  email: 'elvis.arboleda@uni.pe',
  dni: '74125896',
  rol: 'JUGADOR',
});

describe('Luxxito Sports API REST - Suite de Pruebas (Taller 3 - SI806)', () => {
  beforeEach(() => {
    process.env.NODE_ENV = 'test';
    dataRepository.resetTestState();
  });

  it('Caso 1 (Éxito): Consulta de complejos y filtrado de canchas relacionadas (200 OK)', async () => {
    const resComplejos = await request(app).get('/api/complejos');
    expect(resComplejos.status).toBe(200);
    expect(resComplejos.body.ok).toBe(true);
    expect(resComplejos.body.data.length).toBeGreaterThanOrEqual(3);

    const resCanchas = await request(app).get('/api/canchas?deporte=Futbol%207');
    expect(resCanchas.status).toBe(200);
    expect(resCanchas.body.data.every((c: any) => c.deporte === 'Futbol 7')).toBe(true);
  });

  it('Caso 2 (Éxito - CRUD): Creación y actualización de una cancha deportiva (201 y 200)', async () => {
    const createRes = await request(app).post('/api/canchas').send({
      complejo_id: 1,
      nombre: 'Cancha Sintética VIP 4',
      deporte: 'Futbol 5',
      superficie: 'Grass Sintético FIFA Pro',
      techada: true,
      iluminacion: true,
      precio_hora_diurno: 80,
      precio_hora_nocturno: 110,
    });
    expect(createRes.status).toBe(201);
    expect(createRes.body.data.nombre).toBe('Cancha Sintética VIP 4');

    const canchaId = createRes.body.data.id;
    const updateRes = await request(app)
      .put(`/api/canchas/${canchaId}`)
      .send({ precio_hora_diurno: 85, precio_hora_nocturno: 115 });
    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.precio_hora_diurno).toBe(85);
  });

  it('Caso 3 (Fallo - Validación 400): Rechaza creación de cancha con precio nocturno menor al diurno', async () => {
    const res = await request(app).post('/api/canchas').send({
      complejo_id: 1,
      nombre: 'Cancha Inválida',
      deporte: 'Futbol 7',
      precio_hora_diurno: 120,
      precio_hora_nocturno: 90,
    });
    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
    expect(res.body.code).toBe('BAD_REQUEST');
  });

  it('Caso 4 (Éxito - Lógica de Negocio): Cotización del servidor y creación de reserva con extras y tarifa nocturna (201)', async () => {
    const fecha = getFutureDate(5);
    // Cancha 1: diurno S/ 90, nocturno S/ 120 (17:00 a 19:00 = 1h diurna + 1h nocturna = S/ 210)
    // Extra 1: Juego de Chalecos S/ 15 x 2 = S/ 30 -> Total esperado = S/ 240.00
    const res = await request(app)
      .post('/api/reservas')
      .send({
        cancha_id: 1,
        cliente_nombre: 'Carlos Mendoza',
        cliente_dni: '74125896',
        cliente_telefono: '999888777',
        cliente_email: 'carlos.mendoza@uni.pe',
        fecha,
        hora_inicio: 17,
        hora_fin: 19,
        extras: [{ extra_id: 1, cantidad: 2 }],
      });

    expect(res.status).toBe(201);
    expect(res.body.data.subtotal_cancha).toBe(210);
    expect(res.body.data.subtotal_extras).toBe(30);
    expect(res.body.data.total).toBe(240);
    expect(res.body.data.estado).toBe('PENDIENTE_PAGO');
  });

  it('Caso 5 (Fallo - Regla de Negocio 409): Rechaza reserva solapada en la misma cancha y horario', async () => {
    const fecha = getFutureDate(6);
    const payload = {
      cancha_id: 1,
      cliente_nombre: 'Usuario Uno',
      cliente_dni: '71234567',
      cliente_telefono: '987654321',
      cliente_email: 'uno@uni.pe',
      fecha,
      hora_inicio: 19,
      hora_fin: 21,
    };

    const first = await request(app).post('/api/reservas').send(payload);
    expect(first.status).toBe(201);

    // Segundo intento solapado de 20:00 a 21:00 en la misma cancha
    const second = await request(app)
      .post('/api/reservas')
      .send({
        ...payload,
        cliente_nombre: 'Usuario Dos',
        cliente_dni: '76543210',
        hora_inicio: 20,
        hora_fin: 21,
      });

    expect(second.status).toBe(409);
    expect(second.body.code).toBe('CONFLICT');
  });

  it('Caso 6 (Fallo - Regla de Negocio 409): Rechaza reserva cuando el stock de extras por intervalo es insuficiente', async () => {
    const fecha = getFutureDate(7);
    // Extra 3 (Árbitro Oficial) en Complejo 1 tiene stock_total = 2
    // Reserva en Cancha 1 pide 2 árbitros de 18:00 a 19:00
    const r1 = await request(app)
      .post('/api/reservas')
      .send({
        cancha_id: 1,
        cliente_nombre: 'Equipo A',
        cliente_dni: '70000001',
        cliente_telefono: '911222333',
        cliente_email: 'equipoA@uni.pe',
        fecha,
        hora_inicio: 18,
        hora_fin: 19,
        extras: [{ extra_id: 3, cantidad: 2 }],
      });
    expect(r1.status).toBe(201);

    // Otra reserva en Cancha 2 (mismo Complejo 1 y mismo horario 18:00-19:00) pide 1 árbitro adicional
    const r2 = await request(app)
      .post('/api/reservas')
      .send({
        cancha_id: 2,
        cliente_nombre: 'Equipo B',
        cliente_dni: '70000002',
        cliente_telefono: '911222334',
        cliente_email: 'equipoB@uni.pe',
        fecha,
        hora_inicio: 18,
        hora_fin: 19,
        extras: [{ extra_id: 3, cantidad: 1 }],
      });
    expect(r2.status).toBe(409);
    expect(r2.body.message).toContain('Stock insuficiente');
  });

  it('Caso 7 (Éxito - Pago, Aprobación Idempotente y Ticket QR): Registra comprobante Yape y aprueba sin duplicar saldo', async () => {
    const fecha = getFutureDate(4);
    const createRes = await request(app).post('/api/reservas').send({
      cancha_id: 2,
      cliente_nombre: 'Lucía Fernández',
      cliente_dni: '75554443',
      cliente_telefono: '955666777',
      cliente_email: 'lucia@uni.pe',
      fecha,
      hora_inicio: 20,
      hora_fin: 21,
    });
    const reservaId = createRes.body.data.id;
    const total = createRes.body.data.total; // S/ 95.00

    const pagoRes = await request(app)
      .post(`/api/reservas/${reservaId}/pagos`)
      .send({
        metodo: 'YAPE',
        modalidad: 'TOTAL',
        monto: total,
        numero_operacion: 'YAPE-8849201',
      });
    expect(pagoRes.status).toBe(201);
    expect(pagoRes.body.data.reserva.estado).toBe('EN_REVISION');

    const pagoId = pagoRes.body.data.pago.id;

    // Primera aprobación (con rol ADMIN)
    const approve1 = await request(app)
      .patch(`/api/pagos/${pagoId}/aprobar`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(approve1.status).toBe(200);
    expect(approve1.body.data.reserva.estado).toBe('CONFIRMADA');
    expect(approve1.body.data.reserva.monto_pagado).toBe(total);
    expect(approve1.body.data.reserva.codigo_qr).toContain('LUXXITO-QR-');

    // Segunda aprobación repetida (prueba de idempotencia)
    const approve2 = await request(app)
      .patch(`/api/pagos/${pagoId}/aprobar`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(approve2.status).toBe(200);
    expect(approve2.body.data.idempotent).toBe(true);
    expect(approve2.body.data.reserva.monto_pagado).toBe(total);
  });

  it('Caso 8 (Éxito - Cancelación 24h y revocación de QR): Aplica reembolso del 100% con >24h de anticipación', async () => {
    const fecha = getFutureDate(5);
    const createRes = await request(app).post('/api/reservas').send({
      cancha_id: 1,
      cliente_nombre: 'Jorge Chávez',
      cliente_dni: '73332221',
      cliente_telefono: '944555666',
      cliente_email: 'jorge@uni.pe',
      fecha,
      hora_inicio: 10,
      hora_fin: 11,
    });
    const reservaId = createRes.body.data.id;

    // Pagar y auto-aprobar
    await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'PLIN',
      modalidad: 'TOTAL',
      monto: 90,
      numero_operacion: 'PLIN-991122',
      auto_aprobar: true,
    });

    // Cancelar con más de 24 horas de anticipación
    const cancelRes = await request(app)
      .post(`/api/reservas/${reservaId}/cancelar`)
      .send({ motivo: 'Cambio de fecha del torneo' });

    expect(cancelRes.status).toBe(200);
    expect(cancelRes.body.data.politica_aplicada).toBe('REEMBOLSO_100_MAYOR_24H');
    expect(cancelRes.body.data.monto_devolucion).toBe(90);
    expect(cancelRes.body.data.reserva.estado).toBe('CANCELADA');
    expect(cancelRes.body.data.reserva.codigo_qr).toBeNull();
  });

  it('Caso 9 (Éxito - Bandeja de revisión): Lista pagos PENDIENTE_REVISION con resumen de la reserva', async () => {
    const createRes = await request(app).post('/api/reservas').send({
      cancha_id: 1,
      cliente_nombre: 'Rosa Quispe',
      cliente_dni: '71112223',
      cliente_telefono: '911222333',
      cliente_email: 'rosa@uni.pe',
      fecha: getFutureDate(6),
      hora_inicio: 9,
      hora_fin: 10,
    });
    const reservaId = createRes.body.data.id;
    await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'YAPE',
      modalidad: 'TOTAL',
      monto: createRes.body.data.total,
      numero_operacion: 'YAPE-554433',
    });

    const res = await request(app)
      .get('/api/pagos?estado=PENDIENTE_REVISION')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.count).toBe(res.body.data.length);
    expect(res.body.data.every((p: any) => p.estado === 'PENDIENTE_REVISION')).toBe(true);
    const pago = res.body.data.find((p: any) => p.reserva_id === reservaId);
    expect(pago.reserva.cliente_nombre).toBe('Rosa Quispe');
    expect(pago.reserva.estado).toBe('EN_REVISION');

    const invalido = await request(app)
      .get('/api/pagos?estado=INEXISTENTE')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(invalido.status).toBe(400);
    expect(invalido.body.ok).toBe(false);
  });

  it('Caso 10 (Éxito - Rechazo con motivo e idempotencia): Devuelve la reserva a PENDIENTE_PAGO y permite reintentar', async () => {
    const createRes = await request(app).post('/api/reservas').send({
      cancha_id: 2,
      cliente_nombre: 'Pedro Huamán',
      cliente_dni: '72223334',
      cliente_telefono: '922333444',
      cliente_email: 'pedro@uni.pe',
      fecha: getFutureDate(7),
      hora_inicio: 18,
      hora_fin: 19,
    });
    const reservaId = createRes.body.data.id;
    const total = createRes.body.data.total;
    const pagoRes = await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'PLIN',
      modalidad: 'TOTAL',
      monto: total,
      numero_operacion: 'PLIN-000111',
    });
    const pagoId = pagoRes.body.data.pago.id;

    const rechazo = await request(app)
      .patch(`/api/pagos/${pagoId}/rechazar`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ observacion: 'Número de operación no coincide con el voucher' });
    expect(rechazo.status).toBe(200);
    expect(rechazo.body.data.idempotent).toBe(false);
    expect(rechazo.body.data.pago.estado).toBe('RECHAZADO');
    expect(rechazo.body.data.pago.observacion).toBe('Número de operación no coincide con el voucher');
    expect(rechazo.body.data.reserva.estado).toBe('PENDIENTE_PAGO');
    expect(Date.parse(rechazo.body.data.reserva.expires_at)).toBeGreaterThan(Date.now());

    const rechazo2 = await request(app)
      .patch(`/api/pagos/${pagoId}/rechazar`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ observacion: 'Segundo intento de rechazo' });
    expect(rechazo2.status).toBe(200);
    expect(rechazo2.body.data.idempotent).toBe(true);

    // Un pago rechazado no puede aprobarse después
    const aprobarRechazado = await request(app)
      .patch(`/api/pagos/${pagoId}/aprobar`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(aprobarRechazado.status).toBe(409);

    // El jugador reenvía un comprobante válido
    const reintento = await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'PLIN',
      modalidad: 'TOTAL',
      monto: total,
      numero_operacion: 'PLIN-000222',
    });
    expect(reintento.status).toBe(201);
    expect(reintento.body.data.reserva.estado).toBe('EN_REVISION');
  });

  it('Caso 11 (Fallo - Validación 400/404/409): Rechazo sin motivo, pago inexistente o ya aprobado', async () => {
    const createRes = await request(app).post('/api/reservas').send({
      cancha_id: 1,
      cliente_nombre: 'Ana Torres',
      cliente_dni: '73334445',
      cliente_telefono: '933444555',
      cliente_email: 'ana@uni.pe',
      fecha: getFutureDate(8),
      hora_inicio: 11,
      hora_fin: 12,
    });
    const reservaId = createRes.body.data.id;
    const pagoRes = await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'YAPE',
      modalidad: 'TOTAL',
      monto: createRes.body.data.total,
      numero_operacion: 'YAPE-777888',
    });
    const pagoId = pagoRes.body.data.pago.id;

    const sinMotivo = await request(app)
      .patch(`/api/pagos/${pagoId}/rechazar`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(sinMotivo.status).toBe(400);

    const inexistente = await request(app)
      .patch('/api/pagos/999999/rechazar')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ observacion: 'Comprobante ilegible' });
    expect(inexistente.status).toBe(404);

    await request(app)
      .patch(`/api/pagos/${pagoId}/aprobar`)
      .set('Authorization', `Bearer ${adminToken}`);
    const yaAprobado = await request(app)
      .patch(`/api/pagos/${pagoId}/rechazar`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ observacion: 'Comprobante ilegible' });
    expect(yaAprobado.status).toBe(409);
    expect(yaAprobado.body.ok).toBe(false);
  });

  it('Caso 12 (Fallo - Regla de Negocio 422): Rechaza reservas en fechas u horas que ya pasaron', async () => {
    const res = await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('71110001'), fecha: getFutureDate(-1), hora_inicio: 10, hora_fin: 11 });

    expect(res.status).toBe(422);
    expect(res.body.ok).toBe(false);
    expect(res.body.code).toBe('BUSINESS_RULE_VIOLATION');
    expect(res.body.message).toContain('ya han transcurrido');
  });

  it('Caso 13 (Fallo - Regla de Negocio 422): Rechaza horarios fuera de atención y reservas de más de 4 horas', async () => {
    const fecha = getFutureDate(5);
    const fueraDeHorario = await request(app)
      .post('/api/reservas/cotizar')
      .send({ cancha_id: 1, fecha, hora_inicio: 5, hora_fin: 6 });
    expect(fueraDeHorario.status).toBe(422);
    expect(fueraDeHorario.body.message).toContain('fuera del horario de atención');

    const muyLarga = await request(app)
      .post('/api/reservas/cotizar')
      .send({ cancha_id: 1, fecha, hora_inicio: 8, hora_fin: 13 });
    expect(muyLarga.status).toBe(422);
    expect(muyLarga.body.message).toContain('4 horas');
  });

  it('Caso 14 (Éxito - Cotización): Tarifa diurna pura y seña del 50% calculadas por el servidor', async () => {
    // Cancha 1: S/ 90 por hora diurna -> 10:00 a 12:00 = S/ 180, seña S/ 90
    const res = await request(app)
      .post('/api/reservas/cotizar')
      .send({ cancha_id: 1, fecha: getFutureDate(5), hora_inicio: 10, hora_fin: 12 });

    expect(res.status).toBe(200);
    expect(res.body.data.duracion_horas).toBe(2);
    expect(res.body.data.subtotal_cancha).toBe(180);
    expect(res.body.data.total).toBe(180);
    expect(res.body.data.monto_sena_50).toBe(90);
  });

  it('Caso 15 (Éxito - Cancelación < 24h): Retiene el 50% de lo pagado y revoca el QR', async () => {
    const fecha = getFutureDate(3);
    const createRes = await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('71110002'), fecha, hora_inicio: 10, hora_fin: 11 });
    const reservaId = createRes.body.data.id;
    await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'YAPE',
      modalidad: 'TOTAL',
      monto: 90,
      numero_operacion: 'YAPE-240001',
      auto_aprobar: true,
    });

    // Simular que faltan 2 horas para el turno (08:00 hora de Lima del mismo día)
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date(`${fecha}T08:00:00-05:00`));
    try {
      const cancelRes = await request(app)
        .post(`/api/reservas/${reservaId}/cancelar`)
        .send({ motivo: 'Lesión de un jugador' });

      expect(cancelRes.status).toBe(200);
      expect(cancelRes.body.data.politica_aplicada).toBe('RETENCION_50_MENOR_24H');
      expect(cancelRes.body.data.horas_anticipacion).toBe(2);
      expect(cancelRes.body.data.penalidad).toBe(45);
      expect(cancelRes.body.data.monto_devolucion).toBe(45);
      expect(cancelRes.body.data.reserva.codigo_qr).toBeNull();
    } finally {
      vi.useRealTimers();
    }

    const otraVez = await request(app).post(`/api/reservas/${reservaId}/cancelar`).send({});
    expect(otraVez.status).toBe(409);
  });

  it('Caso 16 (Éxito - Filtros y Fallo 400/404): Lista reservas por DNI y valida IDs de reserva', async () => {
    const fecha = getFutureDate(6);
    await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('71110003'), fecha, hora_inicio: 8, hora_fin: 9 });
    await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('71110004'), fecha, hora_inicio: 9, hora_fin: 10 });

    const propias = await request(app).get('/api/reservas?cliente_dni=71110003');
    expect(propias.status).toBe(200);
    expect(propias.body.count).toBe(1);
    expect(propias.body.data[0].cliente_dni).toBe('71110003');

    const inexistente = await request(app).get('/api/reservas/999999');
    expect(inexistente.status).toBe(404);
    expect(inexistente.body.code).toBe('NOT_FOUND');

    const invalido = await request(app).get('/api/reservas/abc');
    expect(invalido.status).toBe(400);
  });

  it('Caso 17 (Éxito y Fallo - Autenticación): Login válido con JWT, credenciales inválidas 401 y registro duplicado 409', async () => {
    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@luxxitosports.pe', password: 'admin2026' });
    expect(login.status).toBe(200);
    expect(typeof login.body.data.token).toBe('string');
    expect(login.body.data.user.rol).toBe('ADMIN');
    expect(login.body.data.user.password_hash).toBeUndefined();

    const meRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${login.body.data.token}`);
    expect(meRes.status).toBe(200);
    expect(meRes.body.data.user.email).toBe('admin@luxxitosports.pe');

    const malaClave = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@luxxitosports.pe', password: 'incorrecta' });
    expect(malaClave.status).toBe(401);

    const duplicado = await request(app).post('/api/auth/registro').send({
      nombre: 'Elvis Duplicado',
      dni: '74125896',
      telefono: '987654321',
      email: 'otro.correo@uni.pe',
      password: 'secreta123',
    });
    expect(duplicado.status).toBe(409);
    expect(duplicado.body.code).toBe('CONFLICT');
  });

  it('Caso 18 (Seguridad JWT y Autorización por Rol 401/403 - LX-201): Restringe bandeja y acciones de pagos al rol ADMIN', async () => {
    // 1. Sin token -> 401 Unauthorized
    const sinTokenGet = await request(app).get('/api/pagos');
    expect(sinTokenGet.status).toBe(401);
    expect(sinTokenGet.body.code).toBe('UNAUTHORIZED');

    const sinTokenAprobar = await request(app).patch('/api/pagos/1/aprobar');
    expect(sinTokenAprobar.status).toBe(401);

    const sinTokenRechazar = await request(app)
      .patch('/api/pagos/1/rechazar')
      .send({ observacion: 'Motivo de prueba' });
    expect(sinTokenRechazar.status).toBe(401);

    // 2. Token inválido/manipulado -> 401 Unauthorized
    const tokenInvalido = await request(app)
      .get('/api/pagos')
      .set('Authorization', 'Bearer token.manipulado.invalido');
    expect(tokenInvalido.status).toBe(401);
    expect(tokenInvalido.body.code).toBe('UNAUTHORIZED');

    // 3. Token válido pero con rol JUGADOR -> 403 Forbidden
    const jugadorGet = await request(app)
      .get('/api/pagos')
      .set('Authorization', `Bearer ${jugadorToken}`);
    expect(jugadorGet.status).toBe(403);
    expect(jugadorGet.body.code).toBe('FORBIDDEN');

    const jugadorAprobar = await request(app)
      .patch('/api/pagos/1/aprobar')
      .set('Authorization', `Bearer ${jugadorToken}`);
    expect(jugadorAprobar.status).toBe(403);

    const jugadorRechazar = await request(app)
      .patch('/api/pagos/1/rechazar')
      .set('Authorization', `Bearer ${jugadorToken}`)
      .send({ observacion: 'Intento sin permisos' });
    expect(jugadorRechazar.status).toBe(403);
  });

  it('Caso 19 (Éxito y Fallo - Verificación de Ticket QR - LX-202): Valida ingreso único con QR y rechaza duplicado o cancelado (200/404/409)', async () => {
    const fecha = getFutureDate(4);
    const createRes = await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('75551111'), fecha, hora_inicio: 15, hora_fin: 16 });
    const reservaId = createRes.body.data.id;

    const pagoRes = await request(app).post(`/api/reservas/${reservaId}/pagos`).send({
      metodo: 'YAPE',
      modalidad: 'TOTAL',
      monto: createRes.body.data.total,
      numero_operacion: 'YAPE-QR-001',
      auto_aprobar: true,
    });
    const codigoQr = pagoRes.body.data.reserva.codigo_qr;
    expect(codigoQr).toContain('LUXXITO-QR-');

    // 1. Primer escaneo válido -> 200 OK
    const check1 = await request(app)
      .post('/api/reservas/verificar-qr')
      .send({ codigo_qr: codigoQr });
    expect(check1.status).toBe(200);
    expect(check1.body.data.verificado).toBe(true);
    expect(check1.body.data.estado_ingreso).toBe('INGRESO_REGISTRADO');

    // 2. Segundo escaneo del mismo QR -> 409 Conflict (ya utilizado)
    const check2 = await request(app)
      .post('/api/reservas/verificar-qr')
      .send({ codigo_qr: codigoQr });
    expect(check2.status).toBe(409);
    expect(check2.body.code).toBe('CONFLICT');

    // 3. Cancelar la reserva y verificar que el QR revocado responde 409 Conflict
    await request(app)
      .post(`/api/reservas/${reservaId}/cancelar`)
      .send({ motivo: 'Cancelación posterior' });
    const checkCancelado = await request(app)
      .post('/api/reservas/verificar-qr')
      .send({ codigo_qr: codigoQr });
    expect(checkCancelado.status).toBe(409);

    // 4. QR inexistente -> 404 Not Found
    const checkInexistente = await request(app)
      .post('/api/reservas/verificar-qr')
      .send({ codigo_qr: 'LUXXITO-QR-999999-NOEXISTE' });
    expect(checkInexistente.status).toBe(404);
  });

  it('Caso 20 (Éxito - Expiración Automática de Bloqueos de 20 Minutos - LX-203): Vence PENDIENTE_PAGO tras 20 min y libera el turno, pero protege EN_REVISION', async () => {
    const fecha = getFutureDate(9);
    const t0 = Date.now();

    // 1. Reserva A queda en PENDIENTE_PAGO (sin comprobante) en turno 14:00-15:00
    const resA = await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('76661111'), fecha, hora_inicio: 14, hora_fin: 15 });
    expect(resA.status).toBe(201);
    const idA = resA.body.data.id;

    // 2. Reserva B envía comprobante y pasa a EN_REVISION en turno 16:00-17:00
    const resB = await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('76662222'), fecha, hora_inicio: 16, hora_fin: 17 });
    const idB = resB.body.data.id;
    await request(app).post(`/api/reservas/${idB}/pagos`).send({
      metodo: 'PLIN',
      modalidad: 'TOTAL',
      monto: resB.body.data.total,
      numero_operacion: 'PLIN-HOLD-20',
    });

    // Avanzar el reloj 21 minutos después de la creación
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date(t0 + 21 * 60 * 1000));
    try {
      const checkA = await request(app).get(`/api/reservas/${idA}`);
      expect(checkA.status).toBe(200);
      expect(checkA.body.data.estado).toBe('VENCIDA');

      const checkB = await request(app).get(`/api/reservas/${idB}`);
      expect(checkB.status).toBe(200);
      expect(checkB.body.data.estado).toBe('EN_REVISION');

      // El turno 14:00-15:00 quedó liberado y otro jugador puede reservarlo
      const nuevaEnTurnoLiberado = await request(app)
        .post('/api/reservas')
        .send({ cancha_id: 1, ...titular('76663333'), fecha, hora_inicio: 14, hora_fin: 15 });
      expect(nuevaEnTurnoLiberado.status).toBe(201);
    } finally {
      vi.useRealTimers();
    }
  });

  it('Caso 21 (Éxito y Fallo - Subida de Comprobante a Bucket Privado - LX-301/Infra): Valida MIME y almacena voucher asociado a la reserva', async () => {
    const fecha = getFutureDate(5);
    const createRes = await request(app)
      .post('/api/reservas')
      .send({ cancha_id: 1, ...titular('78889999'), fecha, hora_inicio: 12, hora_fin: 13 });
    const reservaId = createRes.body.data.id;

    // 1. Subida válida en PNG base64 -> 201 Created
    const pngBase64 = Buffer.from('fake-voucher-image-binary-content').toString('base64');
    const upOk = await request(app).post('/api/pagos/comprobante').send({
      reserva_id: reservaId,
      mime_type: 'image/png',
      contenido_base64: pngBase64,
    });
    expect(upOk.status).toBe(201);
    expect(upOk.body.data.bucket).toBe('comprobantes');
    expect(upOk.body.data.comprobante_url).toContain(`supabase://comprobantes/reserva-${reservaId}/`);

    // 2. MIME no permitido (application/pdf) -> 400 Bad Request
    const upBadMime = await request(app).post('/api/pagos/comprobante').send({
      reserva_id: reservaId,
      mime_type: 'application/pdf',
      contenido_base64: pngBase64,
    });
    expect(upBadMime.status).toBe(400);
  });
  it('Caso 22 (Éxito y Fallo - Comprobante adjunto al pago - LX-301): Enlaza el voucher de la reserva y rechaza vouchers ajenos o reservas canceladas', async () => {
    const fecha = getFutureDate(9);
    const crear = (dni: string, hora: number) =>
      request(app)
        .post('/api/reservas')
        .send({ cancha_id: 2, ...titular(dni), fecha, hora_inicio: hora, hora_fin: hora + 1 });
    const reservaA = (await crear('71230001', 9)).body.data;
    const reservaB = (await crear('71230002', 10)).body.data;

    const voucher = Buffer.from('voucher-reserva-a').toString('base64');
    const subida = await request(app)
      .post('/api/pagos/comprobante')
      .send({ reserva_id: reservaA.id, mime_type: 'image/jpeg', contenido_base64: voucher });
    expect(subida.status).toBe(201);
    expect(subida.body.data.almacenado).toBe(false); // sin Supabase Storage en pruebas
    const comprobanteUrl = subida.body.data.comprobante_url;

    // El voucher de la reserva A no puede usarse para pagar la reserva B
    const ajeno = await request(app).post(`/api/reservas/${reservaB.id}/pagos`).send({
      metodo: 'YAPE',
      modalidad: 'TOTAL',
      numero_operacion: 'YAPE-300001',
      comprobante_url: comprobanteUrl,
    });
    expect(ajeno.status).toBe(400);

    const propio = await request(app).post(`/api/reservas/${reservaA.id}/pagos`).send({
      metodo: 'YAPE',
      modalidad: 'TOTAL',
      numero_operacion: 'YAPE-300002',
      comprobante_url: comprobanteUrl,
    });
    expect(propio.status).toBe(201);
    expect(propio.body.data.pago.comprobante_url).toBe(comprobanteUrl);

    // Sin imagen adjunta el pago queda sin comprobante (no se inventa una URL)
    const sinImagen = await request(app).post(`/api/reservas/${reservaB.id}/pagos`).send({
      metodo: 'PLIN',
      modalidad: 'TOTAL',
      numero_operacion: 'PLIN-300003',
    });
    expect(sinImagen.body.data.pago.comprobante_url).toBeNull();

    const bandeja = await request(app)
      .get('/api/pagos?estado=PENDIENTE_REVISION')
      .set('Authorization', `Bearer ${adminToken}`);
    const pagoA = bandeja.body.data.find((p: any) => p.reserva_id === reservaA.id);
    expect(pagoA.comprobante_url).toBe(comprobanteUrl);
    expect(pagoA).toHaveProperty('comprobante_url_firmada', null);

    // No se aceptan comprobantes para reservas canceladas
    await request(app).post(`/api/reservas/${reservaB.id}/cancelar`).send({ motivo: 'Prueba' });
    const cancelada = await request(app)
      .post('/api/pagos/comprobante')
      .send({ reserva_id: reservaB.id, mime_type: 'image/jpeg', contenido_base64: voucher });
    expect(cancelada.status).toBe(409);
  });
});
