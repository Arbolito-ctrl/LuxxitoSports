# Documento Técnico — Taller 3: Desarrollo e Integración de una API REST
**Curso:** SI806 · Desarrollo Adaptativo e Integrado del Software — Universidad Nacional de Ingeniería (UNI)  
**Proyecto:** Luxxito Sports (Gestión Móvil de Reservas de Canchas Deportivas, Equipamiento y Pagos)  
**Fecha:** 3 de noviembre de 2026

---

## 1. Fundamentación del Problema y Análisis (Las 8 Preguntas Clave)

### 1.1. Problema y Usuario
1. **¿Qué problema concreto resolverán?**  
   La gestión manual e informal de alquiler de canchas deportivas en Lima ocasiona dobles reservas sobre un mismo horario, errores en el cobro de tarifas diferenciadas (horario diurno frente a horario nocturno con iluminación), sobreventa de equipamiento adicional (chalecos, balones, árbitros) en horas punta, pérdida de turnos mientras el administrador verifica comprobantes de Yape/Plin y disputas en el cálculo de devoluciones por cancelación.
2. **¿Quién lo necesita y por qué?**  
   Los **jugadores y organizadores de partidos** necesitan consultar disponibilidad real desde su teléfono, asegurar su turno mediante un bloqueo temporal de 20 minutos, cotizar extras disponibles y obtener un Ticket QR verificable tras su pago. Los **administradores de complejos deportivos** necesitan centralizar reservas, revisar comprobantes en una bandeja protegida por rol `ADMIN`, verificar ingresos únicos por QR y aplicar políticas objetivas de cancelación.

### 1.2. Relación Cliente–API
3. **¿Qué hará la API que no deba hacer el cliente?**  
   El servidor es la **única autoridad de negocio**: autentica usuarios con JWT, calcula precios oficiales (tarifa diurna `< 18:00` y tarifa nocturna `>= 18:00`), calcula el adelanto del 50% (`SENA_50`), verifica la exclusión mutua de horarios en la cancha, vence automáticamente los bloqueos de 20 minutos no pagados (`LX-203`), contabiliza el stock disponible de extras cruzando todas las reservas activas del complejo en ese intervalo, aprueba/rechaza pagos de forma idempotente exigiendo rol `ADMIN` (`LX-201`), valida el ingreso único con Ticket QR (`LX-202`) y calcula la penalidad/reembolso según el umbral de 24 horas. El cliente móvil Flutter únicamente presenta la interfaz y envía solicitudes HTTP/RPC; nunca decide precios ni aprueba estados por su cuenta.
4. **¿Qué datos y relaciones se almacenarán?**  
   Se persisten **7 entidades relacionadas** en PostgreSQL (Supabase) con **Row Level Security (RLS)** y el bucket privado `comprobantes`:
   - `usuarios` (`id`, `nombre`, `dni`, `email`, `password_hash`, `rol` `'JUGADOR' | 'ADMIN'`).
   - `complejos` (`1:N` con `canchas` y `1:N` con `extras`).
   - `canchas` (`N:1` con `complejos`, `1:N` con `reservas`).
   - `extras` (`N:1` con `complejos`, `N:M` con `reservas` a través de `reserva_extras`).
   - `reservas` (`N:1` con `canchas`, `1:N` con `reserva_extras` y `1:N` con `pagos`).
   - `reserva_extras` (detalle de cantidad, precio unitario e importe por extra reservado).
   - `pagos` (registro de comprobantes `YAPE`, `PLIN` o `TRANSFERENCIA` y su estado de conciliación).

### 1.3. Negocio y Consistencia
5. **¿Qué reglas ejecutará el servidor?**  
   - **Regla 1 (Tarifa horaria dinámica):** Cada hora entre `hora_apertura` y `17:59` cobra `precio_hora_diurno`; desde las `18:00` cobra `precio_hora_nocturno`.
   - **Regla 2 (Exclusión mutua, bloqueo de 20 min y expiración automática `LX-203`):** Las reservas en `PENDIENTE_PAGO` cuyo `expires_at < NOW()` pasan automáticamente a `VENCIDA` liberando el turno; las reservas activas impiden solapamientos (`409 Conflict`).
   - **Regla 3 (Capacidad de extras por intervalo):** Para cada extra solicitado se suma la cantidad reservada en todas las reservas activas solapadas del mismo complejo; si excede `stock_total`, se rechaza con `409 Conflict`.
   - **Regla 4 (Protección en revisión, bandeja `ADMIN` e idempotencia de pago `LX-201` y `LX-301`):** Al registrar un comprobante, la reserva pasa a `EN_REVISION` (protegida de expiración). La aprobación (`PATCH /api/pagos/:id/aprobar`) y rechazo con motivo (`PATCH /api/pagos/:id/rechazar`) están restringidos al rol `ADMIN` mediante JWT y son idempotentes.
   - **Regla 5 (Verificación única de Ticket QR `LX-202`):** `POST /api/reservas/verificar-qr` valida que la reserva esté `CONFIRMADA` y registra `qr_usado_at`, rechazando con `409 Conflict` cualquier segundo escaneo o QR revocado por cancelación.
   - **Regla 6 (Política de cancelación de 24 horas):** Si se cancela con `>= 24 horas` de anticipación, se reembolsa el `100%` de `monto_pagado`; si faltan `< 24 horas`, se retiene el `50%` de penalidad y se devuelve el `50%`, revocando `codigo_qr = null`.
6. **¿Cómo evitar datos inconsistentes?**  
   Mediante transacciones SQL (`BEGIN` / `COMMIT` / `ROLLBACK`), restricciones `CHECK` y llaves foráneas en PostgreSQL, Row Level Security (`ENABLE ROW LEVEL SECURITY`) y validación previa en la capa de Servicios.

### 1.4. Validación y Prueba
7. **¿Qué entradas deben rechazarse?**  
   - DNI distinto de 8 dígitos, correos mal formados, nombres vacíos o rechazo de pago sin observación (`400 Bad Request`).
   - Acceso a bandeja/aprobación/rechazo de pagos sin token JWT (`401 Unauthorized`) o con rol `JUGADOR` (`403 Forbidden`).
   - Fechas u horas ya transcurridas, horarios fuera de atención o duración mayor a 4 horas (`422 Unprocessable Entity`).
   - Turnos ocupados/bloqueados, extras sin stock, doble escaneo de QR o QR de reserva cancelada (`409 Conflict`).
8. **¿Cómo comprobarán cada resultado?**  
   Mediante la suite automatizada de **20 pruebas de integración** con **Vitest y Supertest** (`npm test`), la colección **Postman** (`docs/LuxxitoSports.postman_collection.json` con 32 requests y 52 aserciones) y la demostración en vivo desde la app móvil **Flutter** contra **Supabase**.
