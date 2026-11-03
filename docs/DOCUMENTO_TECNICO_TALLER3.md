# Documento Técnico — Taller 3: Desarrollo e Integración de una API REST
**Curso:** SI806 · Desarrollo Adaptativo e Integrado del Software — Universidad Nacional de Ingeniería (UNI)  
**Proyecto:** Luxxito Sports (Gestión Móvil de Reservas de Canchas Deportivas, Equipamiento y Pagos)  
**Fecha:** 2 de noviembre de 2026

---

## 1. Fundamentación del Problema y Análisis (Las 8 Preguntas Clave)

### 1.1. Problema y Usuario
1. **¿Qué problema concreto resolverán?**  
   La gestión manual e informal de alquiler de canchas deportivas en Lima ocasiona dobles reservas sobre un mismo horario, errores en el cobro de tarifas diferenciadas (horario diurno frente a horario nocturno con iluminación), sobreventa de equipamiento adicional (chalecos, balones, árbitros) en horas punta, pérdida de turnos mientras el administrador verifica comprobantes de Yape/Plin y disputas en el cálculo de devoluciones por cancelación.
2. **¿Quién lo necesita y por qué?**  
   Los **jugadores y organizadores de partidos** necesitan consultar disponibilidad real desde su teléfono, asegurar su turno mediante un bloqueo temporal de 20 minutos, cotizar extras disponibles y obtener un Ticket QR verificable tras su pago. Los **administradores de complejos deportivos** necesitan centralizar reservas, evitar cruces horarios y aplicar políticas objetivas de pago y cancelación.

### 1.2. Relación Cliente–API
3. **¿Qué hará la API que no deba hacer el cliente?**  
   El servidor es la **única autoridad de negocio**: calcula precios oficiales (tarifa diurna `< 18:00` y tarifa nocturna `>= 18:00`), calcula el adelanto del 50% (`SENA_50`), verifica la exclusión mutua de horarios en la cancha, contabiliza el stock disponible de extras cruzando todas las reservas activas del complejo en ese intervalo, aprueba pagos de forma idempotente generando el hash criptográfico del Ticket QR y calcula la penalidad/reembolso según el umbral de 24 horas. El cliente móvil Flutter únicamente presenta la interfaz y envía solicitudes HTTP; nunca decide precios ni aprueba estados por su cuenta.
4. **¿Qué datos y relaciones se almacenarán?**  
   Se persisten **6 entidades relacionadas** en PostgreSQL (Supabase):
   - `complejos` (`1:N` con `canchas` y `1:N` con `extras`).
   - `canchas` (`N:1` con `complejos`, `1:N` con `reservas`).
   - `extras` (`N:1` con `complejos`, `N:M` con `reservas` a través de `reserva_extras`).
   - `reservas` (`N:1` con `canchas`, `1:N` con `reserva_extras` y `1:N` con `pagos`).
   - `reserva_extras` (detalle de cantidad, precio unitario e importe por extra reservado).
   - `pagos` (registro de comprobantes `YAPE`, `PLIN` o `TRANSFERENCIA` y su estado de conciliación).

### 1.3. Negocio y Consistencia
5. **¿Qué reglas ejecutará el servidor?**  
   - **Regla 1 (Tarifa horaria dinámica):** Cada hora entre `hora_apertura` y `17:59` cobra `precio_hora_diurno`; desde las `18:00` cobra `precio_hora_nocturno`.
   - **Regla 2 (Exclusión mutua y bloqueo de 20 min):** Ninguna reserva puede crearse si existe otra reserva en estado `PENDIENTE_PAGO`, `EN_REVISION` o `CONFIRMADA` donde `r.hora_inicio < nueva.hora_fin` y `r.hora_fin > nueva.hora_inicio`.
   - **Regla 3 (Capacidad de extras por intervalo):** Para cada extra solicitado se suma la cantidad reservada en todas las reservas activas solapadas del mismo complejo; si excede `stock_total`, se rechaza con `409 Conflict`.
   - **Regla 4 (Protección en revisión e idempotencia de pago):** Al registrar un comprobante, la reserva pasa a `EN_REVISION`. Su aprobación (`PATCH /api/pagos/:id/aprobar`) es idempotente: llamadas repetidas no duplican `monto_pagado` ni alteran el Ticket QR (`LUXXITO-QR-...`).
   - **Regla 5 (Política de cancelación de 24 horas):** Si se cancela con `>= 24 horas` de anticipación, se reembolsa el `100%` de `monto_pagado`; si faltan `< 24 horas`, se retiene el `50%` de penalidad y se devuelve el `50%`, revocando `codigo_qr = null`.
6. **¿Cómo evitar datos inconsistentes?**  
   Mediante transacciones SQL (`BEGIN` / `COMMIT` / `ROLLBACK`) al insertar reservas con sus extras, restricciones `CHECK` y llaves foráneas en PostgreSQL (`precio_hora_nocturno >= precio_hora_diurno`, `hora_fin > hora_inicio`, `UNIQUE(reserva_id, extra_id)`) y validación previa en la capa de Servicios.

### 1.4. Validación y Prueba
7. **¿Qué entradas deben rechazarse?**  
   - DNI que no tenga 8 dígitos numéricos, correos mal formados o nombres vacíos (`400 Bad Request`).
   - Creación de cancha con tarifa nocturna menor a la diurna o deporte no permitido (`400 Bad Request`).
   - Fechas u horas ya transcurridas o fuera del horario de apertura/cierre del complejo (`422 Unprocessable Entity`).
   - Turnos ya ocupados/bloqueados o extras sin stock suficiente en ese intervalo (`409 Conflict`).
   - Montos de comprobante que no coincidan con el 50% (`SENA_50`) ni el 100% (`TOTAL`) calculado por el servidor (`422 Unprocessable Entity`).
8. **¿Cómo comprobarán cada resultado?**  
   Mediante una suite automatizada de 8 pruebas de integración con **Vitest y Supertest** (`npm test`), la colección **Postman** (`docs/LuxxitoSports.postman_collection.json`) y la demostración en vivo desde la app móvil **Flutter**.

---

## 2. Arquitectura de la Solución

La solución aplica una arquitectura cliente-servidor de tres niveles con separación estricta de responsabilidades en el backend:

```text
┌──────────────────────────────────────────────────────────────────────┐
│                  CLIENTE MÓVIL (Flutter 3 + Dart)                    │
│  • Pantallas: Explorar/Filtros, Disponibilidad/Reserva, Mis Reservas │
│  • Servicio HTTP: ApiService (Manejo de estados, timeouts y errores) │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ Solicitudes HTTP / JSON (REST)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│           API REST PROPIA (Node.js + Express + TypeScript)           │
│  1. Capa de Controladores (src/controllers/):                        │
│     Recibe Request, delega al servicio y emite códigos HTTP exactos. │
│  2. Capa de Servicios (src/services/):                               │
│     Ejecuta validaciones y las 5 reglas de negocio del dominio.      │
│  3. Capa de Acceso a Datos (src/repositories/):                      │
│     Ejecuta consultas parametrizadas y transacciones hacia BD.       │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ Conexión PostgreSQL (SSL / Pool)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│               BASE DE DATOS RELACIONAL (Supabase PostgreSQL)         │
│  Tablas: complejos (1:N) canchas (1:N) reservas (1:N) pagos          │
│          complejos (1:N) extras (N:M) reserva_extras                 │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Modelo de Datos Relacional (Esquema PostgreSQL en Supabase)

| Tabla | Clave Primaria | Claves Foráneas | Atributos Principales y Restricciones (`CHECK`) |
|---|---|---|---|
| `complejos` | `id` (`SERIAL`) | — | `nombre`, `distrito`, `direccion`, `hora_apertura` (7), `hora_cierre` (23), `activo` |
| `canchas` | `id` (`SERIAL`) | `complejo_id` → `complejos(id)` | `nombre`, `deporte`, `superficie`, `techada`, `precio_hora_diurno > 0`, `precio_hora_nocturno >= precio_hora_diurno`, `estado` |
| `extras` | `id` (`SERIAL`) | `complejo_id` → `complejos(id)` | `nombre`, `precio_unitario >= 0`, `stock_total >= 0`, `activo` |
| `reservas` | `id` (`SERIAL`) | `cancha_id` → `canchas(id)` | `cliente_nombre`, `cliente_dni` (8 díg.), `fecha`, `hora_inicio`, `hora_fin > hora_inicio`, `subtotal_cancha`, `subtotal_extras`, `total`, `monto_pagado`, `monto_devolucion`, `estado`, `codigo_qr`, `expires_at` |
| `reserva_extras` | `id` (`SERIAL`) | `reserva_id` → `reservas(id)`, `extra_id` → `extras(id)` | `cantidad > 0`, `precio_unitario`, `subtotal`, `UNIQUE(reserva_id, extra_id)` |
| `pagos` | `id` (`SERIAL`) | `reserva_id` → `reservas(id)` | `metodo` (`YAPE`/`PLIN`/`TRANSFERENCIA`), `modalidad` (`SENA_50`/`TOTAL`), `monto > 0`, `numero_operacion`, `estado` |

---

## 4. Catálogo de Endpoints de la API REST Propia

| Método | Ruta | Operación | Códigos HTTP |
|---|---|---|---|
| `GET` | `/api/health` | Diagnóstico de conexión y modo de persistencia | `200` |
| `GET` | `/api/complejos` | Listar complejos deportivos (filtro por `distrito`) | `200` |
| `GET` | `/api/canchas` | **CRUD (Read):** Listar canchas con filtros (`distrito`, `deporte`) | `200` |
| `POST` | `/api/canchas` | **CRUD (Create):** Crear nueva cancha validando tarifas | `201`, `400`, `404` |
| `PUT` | `/api/canchas/:id` | **CRUD (Update):** Actualizar tarifas o estado de cancha | `200`, `400`, `404` |
| `GET` | `/api/canchas/:id/disponibilidad` | **Negocio 1:** Grilla de horarios disponibles, tarifa día/noche y stock de extras | `200`, `400`, `404` |
| `POST` | `/api/reservas/cotizar` | **Negocio 2:** Cotización autoritativa en servidor y validación de stock | `200`, `400`, `409`, `422` |
| `GET` | `/api/reservas` | **CRUD (Read):** Listar reservas con extras y pagos asociados | `200` |
| `POST` | `/api/reservas` | **CRUD (Create) + Negocio 3:** Crear reserva con bloqueo de 20 min y sin solapamientos | `201`, `400`, `409`, `422` |
| `PUT` | `/api/reservas/:id` | **CRUD (Update):** Actualizar teléfono o notas de una reserva activa | `200`, `400`, `404`, `409` |
| `DELETE` | `/api/reservas/:id` | **CRUD (Delete):** Eliminar reserva no confirmada | `200`, `404`, `409` |
| `POST` | `/api/reservas/:id/pagos` | **Negocio 4:** Registrar comprobante Yape/Plin y proteger reserva en revisión | `201`, `400`, `409`, `422` |
| `PATCH` | `/api/pagos/:id/aprobar` | **Negocio 5:** Aprobación idempotente de pago y generación de Ticket QR | `200`, `404`, `409` |
| `POST` | `/api/reservas/:id/cancelar` | **Negocio 6:** Cancelación con cálculo de devolución (regla 24h) y revocación de QR | `200`, `404`, `409` |

---

## 5. Evidencia de Pruebas Automatizadas (Éxitos y Fallos)

Ejecución verificada mediante `cd backend && npm test` (Vitest + Supertest):

1. **Caso 1 (Éxito - `200 OK`):** Consulta de complejos y filtrado de canchas relacionadas por deporte (`Futbol 7`).
2. **Caso 2 (Éxito CRUD - `201` y `200`):** Creación y actualización de tarifas de una cancha deportiva.
3. **Caso 3 (Fallo Validación - `400 Bad Request`):** Rechaza creación de cancha cuando `precio_hora_nocturno < precio_hora_diurno`.
4. **Caso 4 (Éxito Negocio - `201 Created`):** Reserva de 17:00 a 19:00 combina 1h diurna (S/ 90) + 1h nocturna (S/ 120) + 2 packs de chalecos (S/ 30) = `S/ 240.00` calculado en el servidor.
5. **Caso 5 (Fallo Negocio - `409 Conflict`):** Rechaza segundo intento de reserva solapada en la misma cancha y fecha.
6. **Caso 6 (Fallo Negocio - `409 Conflict`):** Rechaza reserva cuando la suma de unidades de un extra en el mismo intervalo supera su `stock_total`.
7. **Caso 7 (Éxito Negocio e Idempotencia - `200 OK`):** Registra pago Yape, emite código `LUXXITO-QR-...` y comprueba que aprobar dos veces el mismo pago no duplica el monto abonado.
8. **Caso 8 (Éxito Negocio Cancelación 24h - `200 OK`):** Cancela reserva con más de 24h de anticipación, calcula devolución del `100%` (`S/ 90.00`) y revoca `codigo_qr = null`.

