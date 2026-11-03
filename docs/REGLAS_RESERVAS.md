# Reglas de Negocio y Estados de Reserva — Luxxito Sports

## 1. Máquina de Estados de la Reserva

```text
[PENDIENTE_PAGO] (Bloqueo 20 min)
       │
       ├── Envío de comprobante Yape/Plin/Transferencia ──► [EN_REVISION] (Protegida de vencimiento)
       │                                                           │
       │                                                           ├── Aprobación Idempotente ──► [CONFIRMADA + QR]
       │                                                           │
       └── Cancelación / Expiración ───────────────────────────────┴────────────────────────────► [CANCELADA] (QR revocado)
```

## 2. Reglas de Cotización y Tarifas (Autoridad del Servidor)
1. **Tarifa Diurna vs. Nocturna**:
   - Turnos antes de las `18:00` aplican `precio_hora_diurno`.
   - Turnos desde las `18:00` en adelante aplican `precio_hora_nocturno` (incluye iluminación LED).
2. **Capacidad de Extras por Intervalo**:
   - Cada extra pertenece a un complejo (`stock_total`).
   - Al cotizar o reservar, el servidor suma las unidades asignadas en todas las reservas activas (`PENDIENTE_PAGO`, `EN_REVISION`, `CONFIRMADA`) que se solapan en la misma fecha e intervalo horario. Si `cantidad_solicitada > (stock_total - usado_en_intervalo)`, responde `409 Conflict`.
3. **Modalidades de Pago**:
   - `SENA_50`: Adelanto exacto del 50% del total.
   - `TOTAL`: Pago del 100% (o saldo pendiente).
4. **Política de Cancelación de 24 Horas**:
   - Si faltan **>= 24 horas** para el inicio del turno: Reembolso del **100%** del monto pagado (`penalidad = 0`).
   - Si faltan **< 24 horas** para el inicio del turno: Retención del **50%** por penalidad y reembolso del **50%** restante.
   - En toda cancelación se revoca inmediatamente `codigo_qr = null` y se libera el horario de la cancha.

