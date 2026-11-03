import fs from 'fs';
import path from 'path';
import { API_PUBLICA, DocumentoAcademico, RAIZ } from './pdf/estiloAcademico';

/**
 * Informe de la demostración del Taller 3 con las capturas en el orden del recorrido.
 * Fuente: docs/validaciones/DEMOSTRACION_TALLER3.md y capturas/evidencia-supabase-demo.json.
 * Uso: npx ts-node src/scripts/generateDemoPdf.ts (desde backend/).
 */
const CAPTURAS = path.join(RAIZ, 'docs/validaciones/capturas');
const captura = (archivo: string, pie: string) => {
  const ruta = path.join(CAPTURAS, archivo);
  if (!fs.existsSync(ruta)) throw new Error(`Falta la captura ${archivo}`);
  return { ruta, pie };
};

async function generateDemoPdf() {
  const evidencia = JSON.parse(fs.readFileSync(path.join(CAPTURAS, 'evidencia-supabase-demo.json'), 'utf-8'));
  const r = evidencia.reservas;
  const pg = evidencia.pagos;

  const d = new DocumentoAcademico({
    titulo: 'Informe de Demostración',
    subtitulo: 'Cliente móvil consumiendo la API REST y cambios persistidos en la base de datos',
    tituloCorto: 'Informe de demostración',
    archivo: 'DEMOSTRACION_TALLER3.pdf',
    indice: true,
  });
  d.portada(
    'Evidencia ordenada del recorrido completo de Luxxito Sports ejecutado el 3 de noviembre de 2026 con el APK de producción en un celular Android físico, la API pública en Render y la base de datos PostgreSQL de Supabase.'
  );

  // ------------------------------------------------------------------ 1. Introducción
  d.nuevaPagina();
  d.h1('1. Introducción');
  d.parrafo(
    'El Taller 3 exige demostrar a un **cliente consumiendo la API propia**, con una **operación completa** y su **cambio persistido en la base de datos**. Este informe registra esa demostración paso a paso: para cada etapa se indica qué se hizo en la aplicación, qué endpoint respondió y qué quedó guardado en Supabase, acompañado de las capturas tomadas en el celular.'
  );
  d.parrafo(
    'El recorrido cubre las seis reglas de negocio del servidor: catálogo y disponibilidad, cotización con tarifa diurna y nocturna, reserva con bloqueo de 20 minutos y exclusión mutua, pago con comprobante en revisión, aprobación del administrador con emisión del Ticket QR de un solo uso y cancelación con la política de 24 horas.'
  );

  d.h1('2. Entorno y datos de la prueba');
  d.tabla(
    [
      { titulo: 'Componente', ancho: 0.24 },
      { titulo: 'Detalle', ancho: 0.76 },
    ],
    [
      ['Fecha y hora', '3 de noviembre de 2026, de 15:38 a 15:54 (hora de Lima)'],
      ['Cliente', 'APK de producción 1.0.36 (Flutter) instalado en un Motorola Edge 50 con Android 16'],
      ['API', `Backend propio Node.js + Express + TypeScript en Render: ${API_PUBLICA}`],
      ['Base de datos', `Supabase PostgreSQL mediante el pooler de transacciones (db_mode = ${evidencia.db_mode}) y Storage con el bucket privado "comprobantes"`],
      ['Usuarios', 'Una cuenta de rol JUGADOR y una cuenta de rol ADMIN (operador del complejo)'],
    ],
    { titulo: 'Entorno de ejecución de la demostración.' }
  );
  d.tabla(
    [
      { titulo: 'Dato', ancho: 0.24 },
      { titulo: 'Valor', ancho: 0.76 },
    ],
    [
      ['Cancha', 'Cancha Monumental 1 · Futbol 7 · Luxxito Arena San Miguel'],
      ['Turno', `${r['19_tras_crear'].fecha}, de 17:00 a 19:00 (1 hora diurna + 1 hora nocturna)`],
      ['Extras', '2 juegos de chalecos (S/ 15 cada uno)'],
      ['Total esperado', 'S/ 90 (día) + S/ 120 (noche) + S/ 30 (chalecos) = S/ 240.00; seña del 50% = S/ 120.00'],
      ['Registros creados', 'Reserva #19, pago #5, reserva del competidor #20 y cancelación de la reserva #4'],
    ],
    { titulo: 'Datos utilizados en la demostración.' }
  );

  // ------------------------------------------------------------------ 3. Desarrollo
  d.nuevaPagina();
  d.h1('3. Desarrollo secuencial de la demostración');

  d.h2('3.1. Catálogo y filtros');
  d.parrafo(
    'El jugador inicia sesión y en **Explorar** filtra por distrito (San Miguel) y deporte (Futbol 7). La aplicación no guarda datos locales: la lista proviene de `GET /api/complejos` y `GET /api/canchas?distrito=…&deporte=…`, que consultan PostgreSQL. **Resultado:** `200 OK`, solo aparecen canchas de Futbol 7 en San Miguel, con foto y precio.'
  );
  d.h2('3.2. Disponibilidad y cotización calculada por el servidor');
  d.parrafo(
    'Se elige la Cancha Monumental 1, la fecha y los turnos de 17:00 y 18:00, y se agregan 2 juegos de chalecos. Los horarios vienen de `GET /api/canchas/1/disponibilidad` y el precio lo calcula el servidor con `POST /api/reservas/cotizar`: desde las 18:00 rige la tarifa nocturna. **Resultado:** cancha S/ 210.00 + extras S/ 30.00 = **S/ 240.00**, adelanto del 50% S/ 120.00.'
  );
  d.figuras([
    captura('01-explorar-filtros.png', 'Catálogo filtrado por distrito y deporte.'),
    captura('02-cotizacion-servidor.png', 'Cotización calculada por el servidor.'),
  ], 165);

  d.h2('3.3. Creación de la reserva');
  d.parrafo(
    '`POST /api/reservas` responde **201 Created**. El servidor valida horario, solapamiento y stock de extras, y bloquea el turno 20 minutos. **Persistencia:** en `reservas`, la fila #19 con `estado = PENDIENTE_PAGO`, `total = 240` y `expires_at`; en `reserva_extras`, chalecos × 2 con subtotal S/ 30.'
  );
  d.h2('3.4. Exclusión mutua: el mismo turno no se vende dos veces');
  d.parrafo(
    'Al volver a la cancha, los turnos de 17:00 y 18:00 aparecen como *Reservándose*. Luego se simula a dos clientes compitiendo por las 20:00: un cliente externo reserva primero (reserva #20) y, cuando el jugador confirma el mismo turno, el servidor responde **409 Conflict** y la app explica que el horario ya no está libre. En la base existe **una sola** reserva activa por horario.'
  );
  d.figuras([
    captura('03a-reserva-creada-app.png', 'Reserva creada con bloqueo de 20 minutos.'),
    captura('04a-turnos-bloqueados.png', 'Turnos 17:00 y 18:00 bloqueados.'),
    captura('04b-conflicto-409-app.png', 'Respuesta 409 ante el turno ya tomado.'),
  ]);

  d.h2('3.5. Pago con foto del comprobante');
  d.parrafo(
    'En **Mis reservas** el jugador elige *Pago total* con Yape, escribe el número de operación y adjunta la foto del voucher. La foto se sube al bucket privado con `POST /api/pagos/comprobante` y el pago se registra con `POST /api/reservas/19/pagos` (**201 Created**). **Persistencia:** `pagos` #5 en `PENDIENTE_REVISION` con `numero_operacion = YAPE-8492014`, el archivo en Storage y la reserva en `EN_REVISION`, que ya no vence.'
  );
  d.h2('3.6. Revisión y aprobación del administrador');
  d.parrafo(
    'El ADMIN tiene su propio panel. **Inicio** indica un pago por revisar y la pestaña **Pagos** muestra el voucher mediante un enlace firmado de 1 hora. Al aprobar, `PATCH /api/pagos/5/aprobar` (solo rol ADMIN; un JUGADOR recibe 403) confirma la reserva y emite el Ticket QR. **Persistencia:** pago `APROBADO` con `reviewed_at`; reserva `CONFIRMADA`, `monto_pagado = 240` y `codigo_qr = LUXXITO-QR-19-EAFECA58D7`.'
  );
  d.figuras([
    captura('05a-pago-en-revision.png', 'Pago enviado: reserva en revisión.'),
    captura('05c-inicio-admin.png', 'Panel del ADMIN con el pago pendiente.'),
    captura('05d-bandeja-pagos-foto.png', 'Bandeja de pagos con el voucher (difuminado).'),
  ]);
  d.nota(
    'En la Figura 8 el voucher está difuminado porque la imagen de prueba contenía datos de otra persona. El archivo original permanece en el bucket privado y solo el ADMIN puede verlo.'
  );

  d.h2('3.7. Ingreso al complejo con el Ticket QR');
  d.parrafo(
    'El jugador muestra su Ticket y el ADMIN lo escanea en la pestaña **Ingreso**. `POST /api/reservas/verificar-qr` registra el ingreso una sola vez (**200 OK**, `qr_usado_at` = 15:50). Al escanear el mismo QR otra vez, la API responde **409**: "Este Ticket QR ya fue utilizado para ingresar". La marca se guarda con una operación atómica en PostgreSQL, por lo que ni dos lecturas simultáneas permiten entrar dos veces.'
  );
  d.figuras([
    captura('05e-ticket-qr.png', 'Ticket QR de la reserva confirmada.'),
    captura('05g-ingreso-registrado.png', 'Primer escaneo: ingreso registrado.'),
    captura('05h-qr-ya-usado.png', 'Segundo escaneo: QR ya utilizado (409).'),
  ]);

  d.h2('3.8. Cancelación con la política de 24 horas');
  d.parrafo(
    'Sobre otra reserva confirmada (#4), el jugador elige *Cancelar reserva*. `POST /api/reservas/4/cancelar` aplica la política: con más de 24 horas de anticipación se devuelve el 100% de lo pagado. **Persistencia:** `estado = CANCELADA`, `monto_devolucion = 120`, `codigo_qr = NULL` y el motivo. Su QR revocado responde **409** si se intenta usar.'
  );
  d.figuras([captura('05j-cancelacion-app.png', 'Reserva cancelada con reembolso del 100%.')], 165);

  // ------------------------------------------------------------------ 4. Persistencia
  d.h1('4. Verificación de la persistencia en Supabase');
  d.parrafo(
    'Después de cada paso se consultó la base con las sentencias SQL de respaldo del guion. El estado observado quedó guardado en `docs/validaciones/capturas/evidencia-supabase-demo.json`:'
  );
  d.tabla(
    [
      { titulo: 'Registro', ancho: 0.24 },
      { titulo: 'Momento', ancho: 0.22 },
      { titulo: 'Estado persistido', ancho: 0.54 },
    ],
    [
      ['reservas #19', 'Tras crear', `${r['19_tras_crear'].estado}, ${r['19_tras_crear'].fecha} ${r['19_tras_crear'].hora_inicio}:00-${r['19_tras_crear'].hora_fin}:00, total ${r['19_tras_crear'].total}`],
      ['reserva_extras', 'Tras crear', r['19_reserva_extras'].map((e: any) => `${e.extra} × ${e.cantidad} = ${e.subtotal}`).join('; ')],
      ['pagos #5', 'Tras enviar', `${pg['5_tras_enviar'].estado}, ${pg['5_tras_enviar'].numero_operacion}`],
      ['Storage', 'Tras enviar', `${evidencia.storage.bucket}: ${evidencia.storage.objeto} (${evidencia.storage.tamano_bytes} bytes, ${evidencia.storage.tipo})`],
      ['reservas #19', 'Tras enviar', r['19_tras_comprobante'].estado],
      ['pagos #5', 'Tras aprobar', `${pg['5_tras_aprobar'].estado}, revisado ${pg['5_tras_aprobar'].reviewed_at}`],
      ['reservas #20', 'Paso 3.4', `${r['20_competidor'].estado} (${r['20_competidor'].hora_inicio}:00-${r['20_competidor'].hora_fin}:00), reserva del competidor`],
      ['reservas #4', 'Tras cancelar', `${r['4_cancelada'].estado}, devolución ${r['4_cancelada'].monto_devolucion} de ${r['4_cancelada'].monto_pagado}, QR ${r['4_cancelada'].codigo_qr ?? 'NULL'}`],
      ['API', 'Segundo escaneo', evidencia.verificaciones_api.segundo_escaneo],
      ['API', 'QR cancelado', evidencia.verificaciones_api.qr_de_reserva_cancelada],
    ],
    { titulo: 'Estados registrados en la base de datos durante la demostración.' }
  );

  // ------------------------------------------------------------------ 5. Resumen y conclusiones
  d.h1('5. Resumen de resultados');
  d.tabla(
    [
      { titulo: 'Paso', ancho: 0.08 },
      { titulo: 'Endpoint', ancho: 0.4 },
      { titulo: 'Código', ancho: 0.12 },
      { titulo: 'Resultado', ancho: 0.4 },
    ],
    [
      ['3.1', 'GET /api/canchas?distrito=…&deporte=…', '200', 'Catálogo filtrado desde la base'],
      ['3.2', 'POST /api/reservas/cotizar', '200', 'Total S/ 240 calculado en el servidor'],
      ['3.3', 'POST /api/reservas', '201', 'Reserva #19 PENDIENTE_PAGO con bloqueo'],
      ['3.4', 'POST /api/reservas (mismo turno)', '409', 'Un solo dueño por horario'],
      ['3.5', 'POST /api/pagos/comprobante y /reservas/19/pagos', '201', 'Voucher en Storage, reserva EN_REVISION'],
      ['3.6', 'GET /api/pagos y PATCH /api/pagos/5/aprobar', '200', 'Reserva CONFIRMADA y Ticket QR'],
      ['3.7', 'POST /api/reservas/verificar-qr (dos veces)', '200 / 409', 'Ingreso único'],
      ['3.8', 'POST /api/reservas/4/cancelar', '200', 'Reembolso 100% y QR revocado'],
    ],
    { titulo: 'Resumen de los pasos, respuestas HTTP y resultados (todos cumplidos).' }
  );
  d.h1('6. Conclusiones');
  d.lista([
    'La aplicación móvil consumió la API propia en todo el recorrido; ningún precio, disponibilidad ni cambio de estado se decidió en el cliente.',
    'Cada operación dejó un cambio verificable en PostgreSQL (reservas, extras y pagos) y en Supabase Storage (comprobante).',
    'Las reglas críticas se comprobaron en producción: exclusión mutua (409), roles (solo ADMIN aprueba y registra ingresos), QR de un solo uso (409 en el segundo escaneo) y reembolso según la política de 24 horas.',
    'La evidencia completa está en el repositorio: `docs/validaciones/DEMOSTRACION_TALLER3.md`, las capturas y el estado de la base en `evidencia-supabase-demo.json`.',
  ]);

  await d.finalizar();
}

generateDemoPdf();
