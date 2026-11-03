# Plan del Proyecto Móvil — Luxxito Sports (SI806 · Taller 3)

Actualizado el 3 de noviembre de 2026 (Perú).  
**Plan operativo y asignación de tareas del equipo (Elvis · Juan · Steven):** Ver [PLAN_EQUIPO_STEVEN_JUAN_ELVIS.md](PLAN_EQUIPO_STEVEN_JUAN_ELVIS.md).

## 1. Objetivo y Alcance
Desarrollar e integrar una **API REST propia** (Node.js + Express + TypeScript) con persistencia relacional en **Supabase (PostgreSQL)**, Row Level Security (RLS), bucket privado `comprobantes` y reglas de negocio del dominio deportivo, consumida por una **aplicación cliente móvil en Flutter + Dart**.

## 2. Arquitectura Implementada

```text
App Móvil Flutter + Dart (mobile/)
        │
        │ Solicitudes HTTP/JSON + JWT Bearer Auth (22 endpoints)
        ▼
API REST Propia Node.js + Express + TypeScript (backend/)
  ├── Middlewares (Validación JWT HMAC-SHA256 y control de rol ADMIN)
  ├── Controllers (Validación de formato y códigos HTTP)
  ├── Services (AuthService, CatalogService, ReservationService: tarifas día/noche,
  │             exclusión de turnos, expiración de 20 min, stock de extras, pagos QR,
  │             verificación única de QR y reembolso 24h)
  └── Repositories (Acceso a datos relacional)
        │
        ▼
Base de Datos PostgreSQL en Supabase (backend/sql/schema.sql)
  ├── 7 Tablas con RLS activo: usuarios, complejos, canchas, extras, reservas, reserva_extras, pagos
  ├── Storage: bucket privado 'comprobantes'
  └── Funciones RPC SECURITY DEFINER (autoridad del servidor en modo nube)
```

## 3. Entregables Cumplidos del Taller 3

| Requisito del Taller 3 | Implementación | Estado |
|---|---|---|
| `>= 5 endpoints propios` | 22 endpoints REST bajo `/api/` | Completado |
| Operaciones CRUD | CRUD completo sobre `canchas` y `reservas` (`GET`, `POST`, `PUT`, `DELETE`) | Completado |
| `>= 2 entidades relacionadas` | 7 tablas relacionadas (`usuarios`, `complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) | Completado |
| `>= 1 operación más allá de CRUD` | 7 operaciones de negocio: disponibilidad horaria, cotización en servidor, bloqueo de 20 min con expiración automática y control de stock de extras, pago idempotente con QR, bandeja de revisión/rechazo con rol `ADMIN`, verificación única de QR y cancelación con regla de 24h | Completado |
| Cliente consume `>= 5 endpoints` | App Flutter consume los endpoints desde Login + 3 pestañas + pantalla de disponibilidad + bandeja de revisión | Completado |
| Validaciones y códigos HTTP | Códigos `200`, `201`, `400`, `401`, `403`, `404`, `409 Conflict`, `422`, `500` | Completado |
| Arquitectura en capas | `middlewares/`, `controllers/`, `services/`, `repositories/` | Completado |
| Pruebas (`>= 5 casos: éxitos y fallos`) | 20 casos automatizados en Vitest/Supertest + colección Postman con 52 aserciones + Widget Test en Flutter | Completado |
| Documentación API + Postman | `docs/API_DOCUMENTATION.md`, `contracts/openapi.yaml` y `docs/LuxxitoSports.postman_collection.json` | Completado |
| Documento Técnico (máx. 5 págs. PDF) | `docs/DOCUMENTO_TECNICO_TALLER3.pdf` y `docs/DOCUMENTO_TECNICO_TALLER3.md` | Completado |
