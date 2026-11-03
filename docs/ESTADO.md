# Estado Vigente del Proyecto — Luxxito Sports

**Fecha de corte:** 3 de noviembre de 2026 (Perú)  
**Etapa:** Infraestructura publicada y acceso/catálogo/reserva validados en Android físico (issue #14, PR #17/#18). El recorrido completo pago/comprobante/QR permanece pendiente.

## Estado confirmado de infraestructura — Juan Medina

- Servicio Render gratuito publicado: `https://luxxito-sports-api.onrender.com/api`.
- Health verificado el 03/11/2026: HTTP 200 y `db_mode=POSTGRES_POOL`.
- Despliegue Render actualizado: commit `ac5a75c` de main (PR #18), activo el 03/11/2026 a las 07:38 de Perú; health 200 y `db_ready=true`.
- Se corrigió la interpolación de variables en el workflow, se validó API_BASE_URL y se actualizó el secreto con la URL pública. No se publican valores privados en los informes.
- PR #17 integrado a develop con squash; PR #18 integrado a main con merge commit. Autor: Juan Medina (`jc2709`). El resultado del APK y la prueba física se registra en [la evidencia](validaciones/2026-11-03-infra-issue14.md).
- APK de producción `1.0.22` (build 22), commit `ac5a75c`: workflow verde y publicado en [latest-apk](https://github.com/Arbolito-ctrl/LuxxitoSports/releases/tag/latest-apk).
- TECNO KJ5, Android 13: instalación, login demo, 6 canchas, Perfil y reserva #1 con chalecos por S/105 comprobados. La reserva se recupera al reiniciar y volver a iniciar sesión; capturas en el informe de evidencia.
- Registro de cuenta sintética y posterior login comprobados. Reserva #1 sin pago: VENCIDA tras 20 minutos reales, confirmada por API a las 08:05:58 y visible en el TECNO; el horario vuelve a estar libre.
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
