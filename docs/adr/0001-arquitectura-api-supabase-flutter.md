# ADR-0001: API REST Propia en Capas con Persistencia en Supabase PostgreSQL y Cliente Flutter

- **Fecha:** 2026-11-02
- **Estado:** Aceptado

## Contexto
El Taller 3 del curso SI806 (UNI) exige desarrollar una **API REST propia** con arquitectura de **Controladores, Servicios y Acceso a Datos**, persistencia en base de datos relacional (`>= 2 entidades relacionadas`), lógica de negocio más allá de CRUD y consumo real desde una aplicación cliente móvil, prohibiendo usar únicamente un BaaS directo sin capa de negocio propia.

## Decisión
1. Implementar la API REST propia en **Node.js + Express + TypeScript** (`backend/`) dividida en:
   - `src/controllers/`: Recepción HTTP y códigos de estado (`200`, `201`, `400`, `404`, `409`, `422`, `500`).
   - `src/services/`: Reglas de negocio (tarifa diurna/nocturna, exclusión de solapamiento de turnos, stock de extras por intervalo, pago idempotente con QR y política de cancelación de 24h).
   - `src/repositories/`: Capa de acceso a datos conectada a **PostgreSQL de Supabase** (`DATABASE_URL` o `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`).
2. Desarrollar la aplicación cliente móvil en **Flutter + Dart** (`mobile/`) consumiendo los endpoints propios de la API.

## Alternativas Consideradas
1. **Conectar Flutter directamente al SDK de Supabase (BaaS directo)**: Descartado porque incumple el requisito obligatorio de programar una API REST propia con capa de Controladores y Servicios en el servidor.
2. **Almacenar precios o calcular totales en el cliente móvil**: Descartado por seguridad; el servidor es la única autoridad sobre precios, disponibilidad y devoluciones.

## Consecuencias y Evidencia
- Cumplimiento al 100% de la rúbrica técnica del Taller 3.
- Verificado mediante 8 pruebas de integración automatizadas (`backend/src/tests/api.test.ts`).

