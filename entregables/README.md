# Entregables — Taller 3 (SI806 · UNI)

**Proyecto:** Luxxito Sports, app móvil Flutter y API REST propia para reservar canchas deportivas.
**Equipo:** Juan Medina, Elvis y Steven.
**API pública:** https://luxxito-sports-api.onrender.com/api ([`/health`](https://luxxito-sports-api.onrender.com/api/health))
**APK de producción:** [luxxito-sports.apk](https://github.com/Arbolito-ctrl/LuxxitoSports/releases/download/latest-apk/luxxito-sports.apk)

| # | Entregable pedido | Dónde está |
|---|---|---|
| 1 | Código fuente del cliente y de la API | [`mobile/`](../mobile) (Flutter) y [`backend/`](../backend) (Node + Express + TypeScript). Cómo ejecutarlo: [`README.md`](../README.md) |
| 2 | Configuración de ejemplo, sin secretos | [`backend/.env.example`](../backend/.env.example). Las credenciales reales están solo en Render y en GitHub Secrets |
| 3 | Script de base de datos | [`backend/sql/schema.sql`](../backend/sql/schema.sql): 7 tablas, restricciones, índices, RLS y datos iniciales |
| 4 | Documentación de la API | [`docs/API_DOCUMENTATION.md`](../docs/API_DOCUMENTATION.md) (rutas, ejemplos JSON y códigos HTTP) y el contrato OpenAPI [`contracts/openapi.yaml`](../contracts/openapi.yaml) (v1.6.0) |
| 5 | Colección de pruebas | [`docs/LuxxitoSports.postman_collection.json`](../docs/LuxxitoSports.postman_collection.json): 38 solicitudes, 63 aserciones (Newman) |
| 6 | Pruebas automatizadas | [`backend/src/tests/api.test.ts`](../backend/src/tests/api.test.ts): 28 casos de éxito, fallo, seguridad y concurrencia (`cd backend && npm test`) |
| 7 | Documento técnico (carátula + 5 páginas) | [`DOCUMENTO_TECNICO_TALLER3.pdf`](DOCUMENTO_TECNICO_TALLER3.pdf). Versión Markdown: [`docs/DOCUMENTO_TECNICO_TALLER3.md`](../docs/DOCUMENTO_TECNICO_TALLER3.md) |
| 8 | Evidencia de la demostración | [`docs/validaciones/DEMOSTRACION_TALLER3.md`](../docs/validaciones/DEMOSTRACION_TALLER3.md) con 13 capturas en [`docs/validaciones/capturas/`](../docs/validaciones/capturas) |
| 9 | Historial de cambios | [`contracts/CHANGELOG.md`](../contracts/CHANGELOG.md) y el historial de Git (ramas `steven/*`, `juan/*` y `elvis/*` integradas por PR a `develop` y luego a `main`) |

## Cuentas de demostración

| Rol | Correo | Contraseña |
|---|---|---|
| Jugador | `elvis.arboleda@uni.pe` | `luxxito2026` |
| Administrador | `admin@luxxitosports.pe` | `admin2026` |

## Regenerar el documento técnico

```bash
cd backend
npx ts-node src/scripts/generatePdf.ts   # escribe entregables/DOCUMENTO_TECNICO_TALLER3.pdf
```
