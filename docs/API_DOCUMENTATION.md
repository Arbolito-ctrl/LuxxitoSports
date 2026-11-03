# Documentación de la API REST — Luxxito Sports (Taller 3 · SI806)

**URL Base (Desarrollo Local):** `http://localhost:3000/api`  
**URL Base (Emulador Android):** `http://10.0.2.2:3000/api`  
**Formato de Intercambio:** `application/json; charset=utf-8`  
**Persistencia:** PostgreSQL en Supabase (`complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`).

---

## 1. Resumen de Endpoints Propios (13 Endpoints)

| # | Método | Ruta | Operación / Regla de Negocio | Códigos HTTP |
|---|---|---|---|---|
| 1 | `GET` | `/api/health` | Estado de la API y modo de conexión a Supabase | `200` |
| 2 | `GET` | `/api/complejos` | Listar complejos deportivos (filtro por `distrito`) | `200` |
| 3 | `GET` | `/api/complejos/:id` | Detalle de complejo con sus canchas y extras | `200`, `400`, `404` |
| 4 | `GET` | `/api/canchas` | Listar canchas con filtros (`complejo_id`, `distrito`, `deporte`, `estado`) | `200` |
| 5 | `GET` | `/api/canchas/:id` | Obtener detalle de una cancha específica | `200`, `400`, `404` |
| 6 | `POST` | `/api/canchas` | **CRUD (Create):** Registrar nueva cancha con validación de tarifas | `201`, `400`, `404` |
| 7 | `PUT` | `/api/canchas/:id` | **CRUD (Update):** Actualizar tarifas, estado o características de cancha | `200`, `400`, `404` |
| 8 | `GET` | `/api/canchas/:id/disponibilidad` | **Lógica de Negocio 1:** Grilla horaria por fecha, tarifas diurna/nocturna y stock de extras | `200`, `400`, `404` |
| 9 | `POST` | `/api/reservas/cotizar` | **Lógica de Negocio 2:** Cotización en servidor (cancha + extras + seña 50%) y verificación de stock | `200`, `400`, `404`, `409`, `422` |
| 10 | `GET` | `/api/reservas` | **CRUD (Read):** Listar reservas con extras y pagos (`estado`, `cliente_dni`, `fecha`) | `200` |
| 11 | `GET` | `/api/reservas/:id` | Obtener detalle completo de una reserva por ID | `200`, `400`, `404` |
| 12 | `POST` | `/api/reservas` | **CRUD (Create) + Lógica de Negocio 3:** Crear reserva con bloqueo de 20 min, exclusión mutua de horario y reserva de extras | `201`, `400`, `404`, `409`, `422` |
| 13 | `PUT` | `/api/reservas/:id` | **CRUD (Update):** Actualizar datos de contacto o notas de una reserva activa | `200`, `400`, `404`, `409` |
| 14 | `DELETE` | `/api/reservas/:id` | **CRUD (Delete):** Eliminar físicamente una reserva no confirmada | `200`, `400`, `404`, `409` |
| 15 | `POST` | `/api/reservas/:id/pagos` | **Lógica de Negocio 4:** Registrar comprobante Yape/Plin/Transferencia y proteger reserva en revisión | `201`, `400`, `404`, `409`, `422` |
| 16 | `PATCH` | `/api/pagos/:id/aprobar` | **Lógica de Negocio 5:** Aprobación idempotente de pago y emisión de Ticket QR (`LUXXITO-QR-...`) | `200`, `400`, `404`, `409` |
| 17 | `POST` | `/api/reservas/:id/cancelar` | **Lógica de Negocio 6:** Cancelación con política de 24 horas (100% reembolso >= 24h; 50% retención < 24h) y revocación de QR | `200`, `400`, `404`, `409` |

---

## 2. Detalle de Endpoints y Ejemplos JSON

### 2.1. `GET /api/canchas/:id/disponibilidad?fecha=2026-11-10&hora=18`
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

### 2.2. `POST /api/reservas`
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

**Respuesta de Error por Cruce de Horario (`409 Conflict`):**
```json
{
  "ok": false,
  "code": "CONFLICT",
  "message": "El turno de 19:00 a 21:00 ya se encuentra ocupado o bloqueado (Reserva #1 en estado PENDIENTE_PAGO)."
}
```

---

### 2.3. `POST /api/reservas/:id/pagos` y `PATCH /api/pagos/:id/aprobar`
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

**Respuesta `201 Created`:**
```json
{
  "ok": true,
  "message": "Comprobante registrado y aprobado. Ticket QR generado.",
  "data": {
    "pago": {
      "id": 1,
      "reserva_id": 1,
      "metodo": "YAPE",
      "modalidad": "TOTAL",
      "monto": 280,
      "numero_operacion": "YAPE-9948102",
      "estado": "APROBADO"
    },
    "reserva": {
      "id": 1,
      "estado": "CONFIRMADA",
      "monto_pagado": 280,
      "codigo_qr": "LUXXITO-QR-1-8F3A19C0D2"
    },
    "idempotent": false
  }
}
```

---

### 2.4. `POST /api/reservas/:id/cancelar`
Cancela una reserva aplicando la regla de las 24 horas y revocando el QR.

**Cuerpo de Solicitud:**
```json
{
  "motivo": "Reprogramación de fecha por lluvia"
}
```

**Respuesta `200 OK`:**
```json
{
  "ok": true,
  "message": "Reserva cancelada aplicando la política de reembolso de 24 horas.",
  "data": {
    "politica_aplicada": "REEMBOLSO_100_MAYOR_24H",
    "horas_anticipacion": 142.5,
    "monto_pagado": 280,
    "penalidad": 0,
    "monto_devolucion": 280,
    "reserva": {
      "id": 1,
      "estado": "CANCELADA",
      "monto_devolucion": 280,
      "codigo_qr": null
    }
  }
}
```
