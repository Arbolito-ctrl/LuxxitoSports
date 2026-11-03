# Entregables — Taller 3 (SI806 · UNI)

**Proyecto:** Luxxito Sports, app móvil Flutter y API REST propia para reservar canchas deportivas.
**Integrantes:** Steven Cadillo, Elvis Arboleda y Juan Medina.  
**Repositorio (rama main):** https://github.com/Arbolito-ctrl/LuxxitoSports/tree/main
**API pública:** https://luxxito-sports-api.onrender.com/api ([`/health`](https://luxxito-sports-api.onrender.com/api/health))
**APK de producción:** [luxxito-sports.apk](https://github.com/Arbolito-ctrl/LuxxitoSports/releases/download/latest-apk/luxxito-sports.apk)

| # | Entregable pedido | Dónde está |
|---|---|---|
| 1 | Código fuente del cliente y de la API | [`mobile/`](../mobile) (Flutter) y [`backend/`](../backend) (Node + Express + TypeScript). Cómo ejecutarlo: [`README.md`](../README.md) |
| 2 | Configuración de ejemplo, sin secretos | [`backend/.env.example`](../backend/.env.example). Las credenciales reales están solo en Render y en GitHub Secrets |
| 3 | Script de base de datos | [`backend/sql/schema.sql`](../backend/sql/schema.sql): 7 tablas, restricciones, índices, RLS y datos iniciales |
| 4 | Documentación de la API | PDF: [`DOCUMENTACION_API_TALLER3.pdf`](DOCUMENTACION_API_TALLER3.pdf). Fuente: [`docs/API_DOCUMENTATION.md`](../docs/API_DOCUMENTATION.md) (rutas, ejemplos JSON y códigos HTTP) y el contrato OpenAPI [`contracts/openapi.yaml`](../contracts/openapi.yaml) (v1.6.0) |
| 5 | Colección de pruebas | [`docs/LuxxitoSports.postman_collection.json`](../docs/LuxxitoSports.postman_collection.json): 38 solicitudes, 63 aserciones (Newman) |
| 6 | Pruebas automatizadas | [`backend/src/tests/api.test.ts`](../backend/src/tests/api.test.ts): 28 casos de éxito, fallo, seguridad y concurrencia (`cd backend && npm test`) |
| 7 | Documento técnico (carátula + 5 páginas) | [`DOCUMENTO_TECNICO_TALLER3.pdf`](DOCUMENTO_TECNICO_TALLER3.pdf). Versión Markdown: [`docs/DOCUMENTO_TECNICO_TALLER3.md`](../docs/DOCUMENTO_TECNICO_TALLER3.md) |
| 8 | Evidencia de la demostración | PDF con las capturas en orden: [`DEMOSTRACION_TALLER3.pdf`](DEMOSTRACION_TALLER3.pdf). Fuente: [`docs/validaciones/DEMOSTRACION_TALLER3.md`](../docs/validaciones/DEMOSTRACION_TALLER3.md) con 12 capturas en [`docs/validaciones/capturas/`](../docs/validaciones/capturas) |
| 9 | Historial de cambios | [`contracts/CHANGELOG.md`](../contracts/CHANGELOG.md) y el historial de Git (ramas `steven/*`, `juan/*` y `elvis/*` integradas por PR a `develop` y luego a `main`) |

## Cuentas de demostración

| Rol | Correo | Contraseña |
|---|---|---|
| Jugador | `elvis.arboleda@uni.pe` | `luxxito2026` |
| Administrador | `admin@luxxitosports.pe` | `admin2026` |

## Material de estudio

[`docs/GUIA_DE_ESTUDIO.md`](../docs/GUIA_DE_ESTUDIO.md) ([PDF](../docs/GUIA_DE_ESTUDIO.pdf)) explica el proyecto, las APIs, la seguridad y la concurrencia, con un glosario y preguntas de sustentación.

## Regenerar los PDF

Los cuatro PDF comparten el estilo de `backend/src/scripts/pdf/estiloAcademico.ts`:

```bash
cd backend
npx ts-node src/scripts/generatePdf.ts      # entregables/DOCUMENTO_TECNICO_TALLER3.pdf (carátula + 5 páginas)
npx ts-node src/scripts/generateApiPdf.ts   # entregables/DOCUMENTACION_API_TALLER3.pdf (desde docs/API_DOCUMENTATION.md)
npx ts-node src/scripts/generateDemoPdf.ts  # entregables/DEMOSTRACION_TALLER3.pdf (capturas de docs/validaciones/capturas/)
npx ts-node src/scripts/generateGuiaPdf.ts  # docs/GUIA_DE_ESTUDIO.pdf (desde docs/GUIA_DE_ESTUDIO.md)
```
