# Metodología de Trabajo — Luxxito Sports (Taller 3 · SI806)

Versión 1.1 · 2 de noviembre de 2026 (Perú).  
Adaptación de la metodología incremental basada en contratos, responsabilidades por módulo, ADR y verificación automatizada para la entrega del **Taller 3 (Desarrollo e Integración de una API REST)** con **Node.js + Express + TypeScript**, **Supabase PostgreSQL** y **Flutter + Dart**.

---

## 1. Principios Metodológicos Aplicados

| Práctica | Implementación en Luxxito Sports | Evidencia en el Repositorio |
|---|---|---|
| **El servidor es la autoridad** | Disponibilidad, precios (diurno/nocturno), stock de extras por intervalo, bloqueo de 20 min y reembolsos se calculan en el backend. | `backend/src/services/catalogService.ts` y `reservationService.ts` |
| **Contratos primero** | Especificación OpenAPI 3.0.3, colección Postman y ejemplos de éxito (`201`) y conflicto (`409`). | `contracts/openapi.yaml`, `docs/LuxxitoSports.postman_collection.json` |
| **Arquitectura en capas** | Separación estricta de Controladores (`controllers/`), Servicios (`services/`) y Acceso a Datos (`repositories/`). | `backend/src/controllers/`, `services/`, `repositories/` |
| **Separación de secretos y ambientes** | Las credenciales de Supabase viven en `.env` (ignorado en Git); el repositorio provee `.env.example` y modo aislado para pruebas. | `.gitignore`, `backend/.env.example`, `backend/src/config/database.ts` |
| **Decisiones trazables (ADR)** | Registro formal de decisiones de arquitectura, reglas de pago manual, bloqueo y cancelación. | `docs/adr/0001-arquitectura-api-supabase-flutter.md` |
| **Verificación reproducible** | Suite automatizada con 8 casos de prueba (éxitos y fallos) en el backend y widget test + análisis estático en Flutter. | `backend/src/tests/api.test.ts`, `mobile/test/widget_test.dart`, `.github/workflows/ci.yml` |

---

## 2. Flujo de Ramas y Promoción de Versiones

| Rama | Propósito | Regla de Integración |
|---|---|---|
| `feat/<tema>` / `fix/<tema>` | Tarea acotada por funcionalidad o corrección. | Nace de `develop`; PR hacia `develop` con pruebas en verde. |
| `develop` | Rama de integración y pruebas internas. | Nunca expone credenciales ni aprueba pagos sin validación. |
| `main` | Versión estable verificada para entrega/demostración. | Promoción desde `develop` con evidencia documentada en `docs/validaciones/`. |

---

## 3. Ciclo de una Tarea y Definición de Terminado (DoD)

1. **Definir**: Necesidad concreta, regla de negocio y códigos HTTP esperados.
2. **Acordar contrato**: Documentar ruta, parámetros y respuesta en `contracts/openapi.yaml` y `docs/API_DOCUMENTATION.md`.
3. **Implementar en capas**: Repositorio (SQL/Supabase) → Servicio (validación y regla de negocio) → Controlador (HTTP) → Pantalla Flutter.
4. **Verificar**: Ejecutar `npm test` (8 pruebas backend), `npm run build` y `flutter analyze` / `flutter test`.
5. **Registrar evidencia**: Documentar resultados en `docs/ESTADO.md` y `docs/validaciones/2026-11-02-taller3.md`.

