# Plan del Proyecto Móvil — Luxxito Sports (SI806 · Taller 3)

Actualizado el 3 de noviembre de 2026 (Perú).  
**Plan operativo y asignación de tareas del equipo (Elvis · Juan · Steven):** Ver [PLAN_EQUIPO_STEVEN_JUAN_ELVIS.md](PLAN_EQUIPO_STEVEN_JUAN_ELVIS.md).

## 1. Objetivo y Alcance
Desarrollar e integrar una **API REST propia** (Node.js + Express + TypeScript) con persistencia relacional en **Supabase (PostgreSQL)** y reglas de negocio del dominio deportivo, consumida por una **aplicación cliente móvil en Flutter + Dart**.

## 2. Arquitectura Implementada

```text
App Móvil Flutter + Dart (mobile/)
        │
        │ Solicitudes HTTP/JSON (12 endpoints)
        ▼
API REST Propia Node.js + Express + TypeScript (backend/)
  ├── Controllers (Validación de formato y códigos HTTP)
  ├── Services (Tarifas día/noche, exclusión de turnos, stock de extras, pagos QR, reembolso 24h)
  └── Repositories (Acceso a datos relacional)
        │
        ▼
Base de Datos PostgreSQL en Supabase (backend/sql/schema.sql)
  └── Tablas: complejos, canchas, extras, reservas, reserva_extras, pagos
```

## 3. Entregables Cumplidos del Taller 3

| Requisito del Taller 3 | Implementación | Estado |
|---|---|---|
| `>= 5 endpoints propios` | 12 endpoints REST bajo `/api/` | Completado |
| Operaciones CRUD | CRUD completo sobre `canchas` y `reservas` (`GET`, `POST`, `PUT`, `DELETE`) | Completado |
| `>= 2 entidades relacionadas` | 6 tablas relacionadas (`complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) | Completado |
| `>= 1 operación más allá de CRUD` | 5 operaciones de negocio: disponibilidad horaria, cotización en servidor, bloqueo y control de stock de extras por intervalo, pago idempotente con QR, y cancelación con regla de 24h | Completado |
| Cliente consume `>= 5 endpoints` | App Flutter consume los 12 endpoints desde 3 pestañas + pantalla de disponibilidad | Completado |
| Validaciones y códigos HTTP | Códigos `200`, `201`, `400`, `404`, `409 Conflict`, `422`, `500` | Completado |
| Arquitectura en capas | `controllers/`, `services/`, `repositories/` | Completado |
| Pruebas (`>= 5 casos: éxitos y fallos`) | 17 casos automatizados en Vitest/Supertest + colección Postman con 51 aserciones + Widget Test en Flutter | Completado |
| Documentación API + Postman | `docs/API_DOCUMENTATION.md`, `contracts/openapi.yaml` y `docs/LuxxitoSports.postman_collection.json` | Completado |
| Documento Técnico (máx. 5 págs. PDF) | `docs/DOCUMENTO_TECNICO_TALLER3.pdf` y `docs/DOCUMENTO_TECNICO_TALLER3.md` | Completado |

