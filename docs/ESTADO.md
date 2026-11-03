# Estado Vigente del Proyecto — Luxxito Sports

**Fecha de corte:** 3 de noviembre de 2026 (Perú)  
**Etapa:** Infraestructura de entrega en validación (issue #14, PR #17). Los bloques están integrados, pero no se declara completada la prueba de punta a punta en Android físico.

## Estado confirmado de infraestructura — Juan Medina

- Servicio Render gratuito publicado: `https://luxxito-sports-api.onrender.com/api`.
- Health verificado el 03/11/2026: HTTP 200 y `db_mode=POSTGRES_POOL`.
- Primer despliegue Render: commit `f4a507a` de main (PR #16, enfoque solo Android).
- Se corrigió la interpolación de variables en el workflow, se validó API_BASE_URL y se actualizó el secreto con la URL pública. No se publican valores privados en los informes.
- PR #17: infraestructura, configuración de APK y documentación. El resultado final del workflow y la promoción se registra en [la evidencia](validaciones/2026-11-03-infra-issue14.md).
- Prueba en teléfono físico: pendiente; no confundir tests/compilación con instalación y flujo real.
- Pagos, upload de comprobantes y persistencia QR: fallos conocidos aplazados expresamente por Juan; fuera de este cambio.

La tabla siguiente conserva los resultados reportados previamente por el equipo. Las 21 pruebas API se repitieron en LOCAL_STORE; no prueban Storage ni PostgreSQL real.

## 1. Resumen de Verificación

| Componente | Comando Ejecutado | Resultado |
|---|---|---|
| Compilación TypeScript Backend | `cd backend && npm run build` | `0 errores` |
| Suite de Pruebas API REST | `cd backend && npm test` | `21 passed (21)` en Vitest + Supertest |
| Base de Datos Supabase + RLS + Storage | `cd backend && npm run db:init` | 7 tablas con `relrowsecurity: true`, bucket privado `comprobantes` y funciones RPC activas |
| Colección Postman | `npx newman run docs/LuxxitoSports.postman_collection.json` | 32 requests y 52 aserciones sin fallos |
| Análisis Estático Flutter | `cd mobile && flutter analyze` | `No issues found!` |
| Pruebas de Widgets Flutter | `cd mobile && flutter test` | `All tests passed!` |
| APK Release Android | `cd backend && npm run apk:build` | `release/luxxito-sports.apk` compilado y publicado |

## 2. Pull Requests Integrados (Squash and Merge)
- **PR #3 (`steven/comprobantes-y-revision`):** `LX-301` — Bandeja de revisión y rechazo de comprobantes.
- **PR #4 (`steven/frontend-ui-admin`):** `LX-300` — Diseño claro deportivo, fotos de complejos y mejoras de usabilidad en Flutter.
- **PR #6 (`steven/qa-pruebas-y-postman`):** `LX-302` — Suite de pruebas ampliada y colección Postman ejecutable.
- **PR #7 (`steven/evidencia-demostracion-taller3`):** `LX-303` — Guion de demostración del Taller 3 con registro de evidencia.
- **PR #8 (`juan/auth-jwt-endpoints`):** `LX-201` — `AuthService`, endpoint `GET /api/auth/me` y control de acceso JWT por rol `ADMIN`.
- **PR #9 (`juan/verificacion-qr`):** `LX-202` — Verificación y escaneo único de Ticket QR (`POST /api/reservas/verificar-qr`).
- **PR #10 (`juan/expiracion-bloqueos`):** `LX-203` — Vencimiento automático de bloqueos de 20 minutos (`PENDIENTE_PAGO` → `VENCIDA`) y actualización integral de documentación.
- **PR #11:** promoción develop → main de LX-201, LX-202 y LX-203.
- **PR #12:** endpoint de comprobantes y RPC QR (su integración no acredita una carga real al bucket).
- **PR #13:** promoción a main del bloque anterior.
- **PR #15 y #16:** proyecto móvil limitado a Android y promoción a main; incorporados en la rama de infraestructura.
