# Guion y Evidencia de la Demostración — Taller 3 (LX-303)

**Responsable:** Steven (con apoyo de Elvis y Juan)
**Requisito (diapositiva 6 del Taller 3):** *"DEMOSTRACIÓN: Cliente consumiendo la API; operación completa y cambio persistido en base de datos."*
**Duración estimada:** 8–10 minutos

| Componente | Qué se muestra |
|---|---|
| Cliente | App móvil Flutter en un celular Android físico |
| API | Backend propio Node.js + Express + TypeScript (`/api`) |
| Base de datos | Supabase PostgreSQL (Table Editor o SQL Editor) |

---

## 0. Preparación (antes de presentar)

### 0.1 Checklist

- [ ] `backend/.env` con `DATABASE_URL` (o `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`). Las credenciales las entrega Elvis por privado y **nunca** se suben al repositorio.
- [ ] Backend levantado y conectado a Supabase:
  ```bash
  cd backend && npm run dev
  curl http://localhost:3000/api/health      # debe decir "db_mode": "POSTGRES_POOL"
  ```
- [ ] App instalada apuntando a la API:
  - **Con cable USB:**
    ```bash
    adb reverse tcp:3000 tcp:3000
    cd mobile && flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
    ```
  - **API desplegada (issue #5):** `flutter run --dart-define=API_BASE_URL=https://<api>/api`
- [ ] Supabase abierto en el navegador: **Table Editor** con las tablas `reservas`, `reserva_extras` y `pagos`, y una pestaña de **SQL Editor** con las consultas de la [sección 3](#3-consultas-sql-de-respaldo).
- [ ] Postman abierto con la colección `docs/LuxxitoSports.postman_collection.json` (sirve para el paso 4 y como respaldo).
- [ ] Brillo del celular al máximo y la pantalla duplicada en el proyector (por ejemplo con `scrcpy`).

### 0.2 Datos de la demo

| Dato | Valor |
|---|---|
| Cuenta jugador | `elvis.arboleda@uni.pe` / `luxxito2026` (DNI `74125896`) |
| Cuenta administrador | `admin@luxxitosports.pe` / `admin2026` |
| Cancha | **Cancha Monumental 1** · Futbol 7 · Luxxito Arena San Miguel |
| Fecha | Al menos **2 días después** de la presentación (así la cancelación es con más de 24 h) |
| Horario | **17:00 – 19:00** (1 hora diurna + 1 hora nocturna) |
| Extras | 2 × Juego de Chalecos (S/ 15 c/u) |
| Total esperado | S/ 90 (día) + S/ 120 (noche) + S/ 30 (chalecos) = **S/ 240.00** · seña 50% = S/ 120.00 |

---

## 1. Guion paso a paso

> En cada paso: **acción** en la app → **qué decir** → **qué verificar** → **captura**. Las capturas se guardan en `docs/validaciones/capturas/` con el nombre indicado.

### Paso 1 — El cliente consume la API: catálogo y filtros

| | |
|---|---|
| **Acción** | Iniciar sesión como jugador. En **Explorar**, tocar el filtro **San Miguel** y luego **Futbol 7**. |
| **Qué decir** | "La app no tiene datos locales: cada lista viene de `GET /api/complejos` y `GET /api/canchas?distrito=…&deporte=…`, que consultan PostgreSQL en Supabase." |
| **Verificar** | Solo aparecen canchas de Futbol 7 en San Miguel, con foto, insignias y precio. |
| **Captura** | `01-explorar-filtros.png` |

### Paso 2 — Disponibilidad y cotización calculada por el servidor

| | |
|---|---|
| **Acción** | Tocar **Reservar** en *Cancha Monumental 1*. Elegir la fecha de la demo, tocar **17:00** y luego **18:00** (2 horas seguidas). En **Extras**, sumar 2 juegos de chalecos. |
| **Qué decir** | "Los horarios vienen de `GET /api/canchas/1/disponibilidad`. El precio **no lo calcula la app**: cada cambio llama a `POST /api/reservas/cotizar`. Desde las 18:00 rige la tarifa nocturna, por eso la segunda hora cuesta más." |
| **Verificar** | Resumen: Cancha 2 h = **S/ 210.00**, Extras = **S/ 30.00**, Total = **S/ 240.00**, adelanto 50% = **S/ 120.00**. |
| **Captura** | `02-cotizacion-servidor.png` |

### Paso 3 — Crear la reserva y verla persistida en Supabase ⭐

| | |
|---|---|
| **Acción** | Tocar **Reservar** en la barra inferior. Aparece "¡Turno reservado!". Ir a **Mis reservas**. |
| **Qué decir** | "`POST /api/reservas` respondió **201 Created**. El servidor validó horario, solapamiento y stock de extras, y bloqueó el turno 20 minutos (`expires_at`)." |
| **Verificar en la app** | Tarjeta **Por pagar** con la cuenta regresiva "Turno guardado por 19:xx". |
| **Verificar en Supabase** | En `reservas`, la fila nueva con `estado = PENDIENTE_PAGO`, `total = 240`, `fecha`, `hora_inicio = 17`, `hora_fin = 19` y `expires_at`. En `reserva_extras`, la fila con `extra_id = 1`, `cantidad = 2`, `subtotal = 30`. |
| **Capturas** | `03a-reserva-creada-app.png`, `03b-supabase-reservas.png`, `03c-supabase-reserva-extras.png` |

### Paso 4 — Exclusión mutua: intento de reserva duplicada (409 Conflict)

Primero se muestra que el turno de la reserva del paso 3 ya no se ofrece. Después se simula a dos clientes compitiendo por un turno libre.

| | |
|---|---|
| **Acción 1 (bloqueo visible)** | Volver a **Explorar → Cancha Monumental 1 → fecha de la demo**. Los turnos **17:00** y **18:00** aparecen tachados como *Reservándose*. |
| **Acción 2 (dos clientes, mismo turno)** | En el celular, tocar **20:00** (sin confirmar). Desde **Postman**, enviar `POST {{baseUrl}}/reservas` con el cuerpo de abajo (mismo día, 20:00–21:00). Volver al celular y tocar **Reservar**. |
| **Acción alternativa (solo Postman)** | Enviar dos veces el mismo cuerpo: la primera responde `201` y la segunda `409`. |
| **Qué decir** | "Dos clientes intentan el mismo turno. El servidor es la autoridad: el segundo recibe **409 Conflict** y la app se lo explica al usuario sin romperse." |
| **Verificar** | En la app aparece "Ese horario ya no está libre" con el mensaje del servidor, y al tocar *Ver horarios actualizados* el turno de las 20:00 sale bloqueado. En Postman se ve `409` con `"code": "CONFLICT"`. En Supabase hay **una sola** fila activa para cada horario. |
| **Capturas** | `04a-turnos-bloqueados.png`, `04b-conflicto-409-app.png` (o `04b-conflicto-409-postman.png`) |

Cuerpo para Postman (reemplazar la fecha por la de la demo):

```json
{
  "cancha_id": 1,
  "cliente_nombre": "Cliente Competidor",
  "cliente_dni": "71234567",
  "cliente_telefono": "987654321",
  "cliente_email": "competidor@uni.pe",
  "fecha": "AAAA-MM-DD",
  "hora_inicio": 20,
  "hora_fin": 21
}
```

### Paso 5 — Pago, revisión del operador, Ticket QR y cancelación ⭐

**5.1 El jugador envía el comprobante**

| | |
|---|---|
| **Acción** | En **Mis reservas**, tocar **Pagar** → *Pago total* → *Yape* → N° de operación `YAPE-8492014` → **Enviar comprobante**. |
| **Qué decir** | "`POST /api/reservas/:id/pagos` registra el comprobante y protege el turno mientras se revisa." |
| **Verificar** | La reserva pasa a **En revisión**. En Supabase: `pagos.estado = PENDIENTE_REVISION` y `reservas.estado = EN_REVISION`. |
| **Captura** | `05a-pago-en-revision.png` |

**5.2 El operador aprueba y se genera el Ticket QR**

| | |
|---|---|
| **Acción** | Cerrar sesión y entrar como **administrador**. **Perfil → Administración → Revisión de pagos** → **Aprobar** → *Sí, aprobar*. Volver a entrar como jugador → **Mis reservas** → **Ticket**. |
| **Qué decir** | "`PATCH /api/pagos/:id/aprobar` confirma la reserva y emite un código QR único. Es idempotente: aprobar dos veces no duplica el pago." |
| **Verificar** | Reserva **Confirmada** con código QR visible. En Supabase: `pagos.estado = APROBADO` con `reviewed_at`; `reservas.estado = CONFIRMADA`, `monto_pagado = 240`, `codigo_qr = LUXXITO-QR-…`. |
| **Capturas** | `05b-bandeja-operador.png`, `05c-ticket-qr.png`, `05d-supabase-confirmada.png` |

**5.3 Cancelación con política de 24 horas**

| | |
|---|---|
| **Acción** | En la reserva confirmada, menú **⋮ → Cancelar reserva**. El diálogo muestra "Te devolveremos S/ 240.00". Confirmar con **Sí, cancelar**. |
| **Qué decir** | "`POST /api/reservas/:id/cancelar` aplica la política: con más de 24 h se devuelve el 100%; con menos, se retiene el 50%. El QR se revoca para que no pueda usarse." |
| **Verificar** | Reserva **Cancelada** con "Reembolso: S/ 240.00". En Supabase: `estado = CANCELADA`, `monto_devolucion = 240`, `codigo_qr = NULL` y `motivo_cancelacion`. |
| **Capturas** | `05e-cancelacion-app.png`, `05f-supabase-cancelada.png` |

### Paso extra (si sobra tiempo) — Rechazo de comprobante

Crear otra reserva, enviar un comprobante y, como administrador, **Rechazar** con el motivo *"Número de operación inválido"*. El jugador ve el aviso rojo con el motivo y la reserva vuelve a **Por pagar** con 20 minutos nuevos. En Supabase: `pagos.estado = RECHAZADO` con `observacion`. Captura: `06-rechazo-comprobante.png`.

---

## 2. Registro de evidencia

Completar al ejecutar la demo con Supabase:

| Paso | Endpoint | Código | Captura app | Captura Supabase | Estado |
|---|---|---|---|---|---|
| 1 | `GET /api/canchas` | 200 | `01-explorar-filtros.png` | — | ☐ |
| 2 | `POST /api/reservas/cotizar` | 200 | `02-cotizacion-servidor.png` | — | ☐ |
| 3 | `POST /api/reservas` | 201 | `03a-reserva-creada-app.png` | `03b`, `03c` | ☐ |
| 4 | `POST /api/reservas` (mismo turno) | 409 | `04a-turnos-bloqueados.png`, `04b-conflicto-409-*.png` | — | ☐ |
| 5.1 | `POST /api/reservas/:id/pagos` | 201 | `05a-pago-en-revision.png` | — | ☐ |
| 5.2 | `PATCH /api/pagos/:id/aprobar` | 200 | `05b`, `05c` | `05d-supabase-confirmada.png` | ☐ |
| 5.3 | `POST /api/reservas/:id/cancelar` | 200 | `05e-cancelacion-app.png` | `05f-supabase-cancelada.png` | ☐ |

**Datos de la ejecución:** fecha `____` · reserva `#____` · pago `#____` · `db_mode` = `POSTGRES_POOL`

---

## 3. Consultas SQL de respaldo

Para mostrar la persistencia en el **SQL Editor** de Supabase (reemplazar `:id` por el número de la reserva):

```sql
-- Últimas reservas creadas desde la app
SELECT id, cliente_nombre, fecha, hora_inicio, hora_fin, total, monto_pagado,
       monto_devolucion, estado, codigo_qr, expires_at, updated_at
FROM reservas
ORDER BY id DESC
LIMIT 5;

-- Extras de la reserva de la demo
SELECT re.reserva_id, e.nombre, re.cantidad, re.precio_unitario, re.subtotal
FROM reserva_extras re
JOIN extras e ON e.id = re.extra_id
WHERE re.reserva_id = :id;

-- Historial de pagos de la reserva (envío, rechazo, aprobación)
SELECT id, metodo, modalidad, monto, numero_operacion, estado, observacion, created_at, reviewed_at
FROM pagos
WHERE reserva_id = :id
ORDER BY id;
```

---

## 4. Si algo falla durante la demo

| Síntoma | Causa probable | Solución rápida |
|---|---|---|
| La app dice "Error de conexión con la API" | El backend no está levantado o falta `adb reverse` | `npm run dev` y `adb reverse tcp:3000 tcp:3000` |
| `/api/health` dice `LOCAL_STORE` | Falta `backend/.env` o tiene valores de ejemplo | Revisar `DATABASE_URL` y reiniciar el backend |
| "Ese horario ya no está libre" en el paso 3 | Ya existe una reserva activa en ese horario | Elegir otra fecha u horario (o cancelar la anterior) |
| "No se pueden registrar reservas en fechas u horas que ya han transcurrido" | Se eligió una hora pasada | Usar una fecha futura |
| No aparece "Revisión de pagos" en Perfil | La sesión es de jugador | Entrar con la cuenta de administrador |
| Supabase no muestra la fila nueva | La vista del Table Editor no se refrescó | Botón *Refresh* o usar las consultas de la sección 3 |
