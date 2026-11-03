# Guía de Operación, Pagos Manuales y Respaldos — Luxxito Sports

## 1. Conciliación de Pagos Manuales (Yape / Plin / Transferencia)
1. El jugador crea la reserva (`POST /api/reservas`), adquiriendo un bloqueo temporal de 20 minutos (`expires_at`).
2. El jugador envía el número de operación e importe (`POST /api/reservas/:id/pagos`). La reserva pasa a estado `EN_REVISION`, quedando protegida contra vencimiento automático mientras se valida la operación.
3. Al aprobarse el comprobante (`PATCH /api/pagos/:id/aprobar`), la operación es **idempotente**: si se invoca más de una vez, no duplica el saldo abonado (`monto_pagado`) ni regenera un ticket distinto.
4. La reserva pasa a `CONFIRMADA` y emite el token de ingreso verificable (`LUXXITO-QR-<ID>-<HASH>`).

## 2. Manejo de Incidentes y Devoluciones
- Cuando un jugador cancela (`POST /api/reservas/:id/cancelar`), el sistema registra `monto_devolucion` según el umbral de 24 horas y limpia `codigo_qr = null` para impedir el ingreso con capturas antiguas.

## 3. Respaldo e Inicialización de Base de Datos en Supabase
- Esquema estructural: `backend/sql/schema.sql`.
- Datos iniciales de operación: `backend/sql/seed.sql`.
- Comando de restauración/migración automatizada: `cd backend && npm run db:init`.

