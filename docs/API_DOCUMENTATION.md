# Documentación de la API REST — Luxxito Sports (Taller 3 · SI806)

**URL Base (Desarrollo Local):** `http://localhost:3000/api`  
**URL Base (Emulador Android):** `http://10.0.2.2:3000/api`  
**Formato de Intercambio:** `application/json; charset=utf-8`  
**Autenticación y Autorización:** JWT (`Authorization: Bearer <token>`) firmado con `JWT_SECRET` para endpoints de administración (`rol: 'ADMIN'`).  
**Persistencia:** PostgreSQL en Supabase (`usuarios`, `complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) con Row Level Security (RLS) y bucket privado `comprobantes`.

---

## 1. Resumen de Endpoints Propios

| # | Método | Ruta | Operación / Regla de Negocio | Códigos HTTP |
|---|---|---|---|---|
| 1 | `POST` | `/api/auth/login` | Autenticación de usuario (`JUGADOR` o `ADMIN`) y emisión de JWT | `200`, `400`, `401` |
| 2 | `POST` | `/api/auth/registro` | Registro de cuenta nueva (`JUGADOR`) con validación de DNI/email y emisión de JWT | `201`, `400`, `409` |
| 3 | `GET` | `/api/health` | Estado de la API y modo de conexión a Supabase | `200` |
| 4 | `GET` | `/api/complejos` | Listar complejos deportivos (filtro por `distrito`) | `200` |
| 5 | `GET` | `/api/complejos/:id` | Detalle de complejo con sus canchas y extras | `200`, `400`, `404` |
| 6 | `GET` | `/api/canchas` | Listar canchas con filtros (`complejo_id`, `distrito`, `deporte`, `estado`) | `200` |
| 7 | `GET` | `/api/canchas/:id` | Obtener detalle de una cancha específica | `200`, `400`, `404` |
| 8 | `POST` | `/api/canchas` | **CRUD (Create):** Registrar nueva cancha con validación de tarifas | `201`, `400`, `404` |
| 9 | `PUT` | `/api/canchas/:id` | **CRUD (Update):** Actualizar tarifas, estado o características de cancha | `200`, `400`, `404` |
| 10 | `GET` | `/api/canchas/:id/disponibilidad` | **Lógica de Negocio 1:** Grilla horaria por fecha, tarifas diurna/nocturna y stock de extras | `200`, `400`, `404` |
| 11 | `POST` | `/api/reservas/cotizar` | **Lógica de Negocio 2:** Cotización en servidor (cancha + extras + seña 50%) y verificación de stock | `200`, `400`, `404`, `409`, `422` |
| 12 | `GET` | `/api/reservas` | **CRUD (Read):** Listar reservas con extras y pagos (`estado`, `cliente_dni`, `fecha`) | `200` |
| 13 | `GET` | `/api/reservas/:id` | Obtener detalle completo de una reserva por ID | `200`, `400`, `404` |
| 14 | `POST` | `/api/reservas` | **CRUD (Create) + Lógica de Negocio 3:** Crear reserva con bloqueo de 20 min, exclusión mutua de horario y reserva de extras | `201`, `400`, `404`, `409`, `422` |
| 15 | `PUT` | `/api/reservas/:id` | **CRUD (Update):** Actualizar datos de contacto o notas de una reserva activa | `200`, `400`, `404`, `409` |
| 16 | `DELETE` | `/api/reservas/:id` | **CRUD (Delete):** Eliminar físicamente una reserva no confirmada | `200`, `400`, `404`, `409` |
| 17 | `POST` | `/api/reservas/:id/pagos` | **Lógica de Negocio 4:** Registrar comprobante Yape/Plin/Transferencia y proteger reserva en revisión | `201`, `400`, `404`, `409`, `422` |
| 18 | `PATCH` | `/api/pagos/:id/aprobar` | **Lógica de Negocio 5 (Rol `ADMIN`):** Aprobación idempotente de pago y emisión de Ticket QR (`LUXXITO-QR-...`) | `200`, `400`, `401`, `403`, `404`, `409` |
| 19 | `GET` | `/api/pagos?estado=PENDIENTE_REVISION` | **Bandeja del operador (Rol `ADMIN`):** Listar pagos con el resumen de su reserva | `200`, `400`, `401`, `403` |
| 20 | `PATCH` | `/api/pagos/:id/rechazar` | **Rechazo de comprobante (Rol `ADMIN`):** `observacion` obligatoria; la reserva vuelve a `PENDIENTE_PAGO` con nuevo bloqueo de 20 min (idempotente) | `200`, `400`, `401`, `403`, `404`, `409` |
| 22 | `POST` | `/api/pagos/comprobante` | **Foto del voucher:** sube la imagen (JPEG/PNG/WEBP, máx. 5 MB, en base64) al bucket privado `comprobantes` y devuelve `comprobante_url` | `201`, `400`, `404`, `409`, `413`, `422`, `502` |
| 23 | `POST` | `/api/reservas/verificar-qr` | **Ingreso en puerta (Rol `ADMIN`):** valida el Ticket QR una sola vez | `200`, `400`, `401`, `403`, `404`, `409` |
| 21 | `POST` | `/api/reservas/:id/cancelar` | **Lógica de Negocio 6:** Cancelación con política de 24 horas (100% reembolso >= 24h; 50% retención < 24h) y revocación de QR | `200`, `400`, `404`, `409` |

---

## 2. Seguridad JWT y Control de Roles (`LX-201`)

Los endpoints del **Modo Operador** (`GET /api/pagos`, `PATCH /api/pagos/:id/aprobar`, `PATCH /api/pagos/:id/rechazar` y `POST /api/reservas/verificar-qr`) requieren el encabezado:

```http
Authorization: Bearer <token_jwt>
```

- **Sin token o con firma JWT inválida:** responde `401 Unauthorized` (`code: "UNAUTHORIZED"`).
- **Con token válido de rol `JUGADOR`:** responde `403 Forbidden` (`code: "FORBIDDEN"`).
- **Con token válido de rol `ADMIN`:** permite listar, aprobar y rechazar comprobantes, y registrar ingresos con el Ticket QR.

---

## 3. Detalle de Endpoints y Ejemplos JSON

### 3.1. `GET /api/canchas/:id/disponibilidad?fecha=2026-11-10&hora=18`
Calcula para cada turno de 1 hora si está `DISPONIBLE`, `BLOQUEADA`, `OCUPADA`, `MANTENIMIENTO` o `PASADA`, asigna tarifa `DIURNA` (< 18:00) o `NOCTURNA` (>= 18:00) y calcula el stock restante de cada extra en el intervalo.

**Respuesta `200 OK`:**
```json
{
  "ok": true,
  "data": {
    "cancha": {
      "id": 1,
      "complejo_id": 1,
      "complejo_nombre": "Luxxito Arena San Miguel",
      "distrito": "San Miguel",
      "nombre": "Cancha Monumental 1",
      "deporte": "Futbol 7",
      "precio_hora_diurno": 90,
      "precio_hora_nocturno": 120,
      "estado": "ACTIVA"
    },
    "fecha": "2026-11-10",
    "horario_operacion": { "apertura": 7, "cierre": 23 },
    "turnos": [
      {
        "hora_inicio": 17,
        "hora_fin": 18,
        "etiqueta": "17:00 - 18:00",
        "tarifa_tipo": "DIURNA",
        "precio": 90,
        "estado": "DISPONIBLE"
      },
      {
        "hora_inicio": 18,
        "hora_fin": 19,
        "etiqueta": "18:00 - 19:00",
        "tarifa_tipo": "NOCTURNA",
        "precio": 120,
        "estado": "OCUPADA",
        "reserva_id": 4
      }
    ],
    "extras_disponibles": [
      {
        "id": 1,
        "complejo_id": 1,
        "nombre": "Juego de Chalecos (x12)",
        "precio_unitario": 15,
        "stock_total": 4,
        "stock_disponible": 4
      }
    ]
  }
}
```

---

### 3.2. `POST /api/reservas`
Crea una reserva verificando horario de atención, no solapamiento con otra reserva activa, stock de extras en el intervalo y cotizando en el servidor.

**Cuerpo de Solicitud (`Request Body`):**
```json
{
  "cancha_id": 1,
  "cliente_nombre": "Carlos Mendoza",
  "cliente_dni": "74125896",
  "cliente_telefono": "999888777",
  "cliente_email": "carlos.mendoza@uni.pe",
  "fecha": "2026-11-10",
  "hora_inicio": 19,
  "hora_fin": 21,
  "notas": "Torneo interfacultades UNI",
  "extras": [
    { "extra_id": 1, "cantidad": 2 },
    { "extra_id": 2, "cantidad": 1 }
  ]
}
```

**Respuesta `201 Created`:**
```json
{
  "ok": true,
  "message": "Reserva creada con bloqueo temporal de 20 minutos.",
  "data": {
    "id": 1,
    "cancha_id": 1,
    "cancha_nombre": "Cancha Monumental 1",
    "complejo_nombre": "Luxxito Arena San Miguel",
    "cliente_nombre": "Carlos Mendoza",
    "cliente_dni": "74125896",
    "fecha": "2026-11-10",
    "hora_inicio": 19,
    "hora_fin": 21,
    "subtotal_cancha": 240,
    "subtotal_extras": 40,
    "total": 280,
    "monto_pagado": 0,
    "monto_devolucion": 0,
    "estado": "PENDIENTE_PAGO",
    "codigo_qr": null,
    "expires_at": "2026-11-03T05:05:00.000Z"
  }
}
```

---

### 3.3. `POST /api/reservas/:id/pagos` y `PATCH /api/pagos/:id/aprobar`
Registra el comprobante de pago (`YAPE`, `PLIN` o `TRANSFERENCIA`) bajo modalidad `SENA_50` (50%) o `TOTAL` (100%).

**Cuerpo de Solicitud (`POST /api/reservas/1/pagos`):**
```json
{
  "metodo": "YAPE",
  "modalidad": "TOTAL",
  "monto": 280,
  "numero_operacion": "YAPE-9948102",
  "auto_aprobar": true
}
```

---

### 3.4. `GET /api/pagos?estado=PENDIENTE_REVISION` y `PATCH /api/pagos/:id/rechazar` (Rol `ADMIN`)
Bandeja de revisión del operador. Requiere `Authorization: Bearer <token_admin>`. Cada pago incluye un resumen de su reserva (cancha, jugador, fecha y horario) para revisarlo sin consultas adicionales. Un `estado` fuera de `PENDIENTE_REVISION`, `APROBADO`, `RECHAZADO` o `REEMBOLSADO` responde `400`.

**Cuerpo de Solicitud (`PATCH /api/pagos/3/rechazar`):**
```json
{ "observacion": "Número de operación no coincide con el voucher" }
```

**Reglas:**
- Requiere token JWT válido con `rol: 'ADMIN'` (`401` sin token, `403` si es `JUGADOR`).
- `observacion` es obligatoria (mínimo 5 caracteres) → `400` si falta.
- Solo se rechazan pagos `PENDIENTE_REVISION`; un pago `APROBADO` o `REEMBOLSADO` responde `409`.
- Repetir el rechazo devuelve `200` con `idempotent: true` sin modificar nada.
- Si la reserva estaba `EN_REVISION`, vuelve a `PENDIENTE_PAGO` con un nuevo `expires_at` de 20 minutos para que el jugador reenvíe el comprobante.
- Un pago `RECHAZADO` ya no puede aprobarse (`409`).

---

### 3.5. `POST /api/pagos/comprobante` (foto del voucher)
Flujo de la app: el jugador elige la foto → `POST /api/pagos/comprobante` → recibe `comprobante_url` → la envía en `POST /api/reservas/:id/pagos`.

**Cuerpo de Solicitud:**
```json
{ "reserva_id": 12, "mime_type": "image/jpeg", "contenido_base64": "/9j/4AAQSkZJRg..." }
```

**Respuesta `201 Created`:**
```json
{
  "ok": true,
  "data": {
    "bucket": "comprobantes",
    "path": "reserva-12/voucher-1730650000000.jpg",
    "comprobante_url": "supabase://comprobantes/reserva-12/voucher-1730650000000.jpg",
    "mime_type": "image/jpeg",
    "size_bytes": 184233,
    "almacenado": true
  }
}
```

**Reglas:**
- El bucket es **privado**. El ADMIN ve la imagen en `GET /api/pagos` mediante `comprobante_url_firmada`, un enlace temporal de 1 hora.
- Solo se aceptan JPEG, PNG o WEBP de hasta 5 MB. El cuerpo JSON de esta ruta admite hasta 8 MB, y el resto de la API mantiene 100 KB (`413` si se supera).
- Una reserva `CANCELADA` o `VENCIDA` no acepta comprobantes (`409`).
- El `comprobante_url` enviado al registrar el pago debe pertenecer a la misma reserva (`400` en caso contrario).
- Con base de datos real y sin `SUPABASE_SERVICE_ROLE_KEY` responde `502 STORAGE_ERROR`. En pruebas y modo local se valida sin guardar (`almacenado: false`).

---

### 3.6. `POST /api/reservas/:id/cancelar`
Cancela una reserva aplicando la regla de las 24 horas y revocando el QR.
