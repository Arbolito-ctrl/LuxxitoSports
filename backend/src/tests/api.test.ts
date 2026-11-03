import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../app';
import { dataRepository } from '../repositories/dataRepository';

// Generar una fecha futura (dentro de 5 días) para pruebas de reservas válidas
function getFutureDate(daysAhead: number = 5): string {
  const d = new Date(Date.now() + daysAhead * 24 * 60 * 60 * 1000);
  return d.toISOString().split('T')[0];
}

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

    // Primera aprobación
    const approve1 = await request(app).patch(`/api/pagos/${pagoId}/aprobar`);
    expect(approve1.status).toBe(200);
    expect(approve1.body.data.reserva.estado).toBe('CONFIRMADA');
    expect(approve1.body.data.reserva.monto_pagado).toBe(total);
    expect(approve1.body.data.reserva.codigo_qr).toContain('LUXXITO-QR-');

    // Segunda aprobación repetida (prueba de idempotencia)
    const approve2 = await request(app).patch(`/api/pagos/${pagoId}/aprobar`);
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
});
