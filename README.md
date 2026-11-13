# Luxxito Sports — Desarrollo Móvil e Integración de API REST (SI806 · Taller 3)

Proyecto desarrollado para el **Taller 3: Desarrollo e Integración de una API REST** del curso **SI806 Desarrollo Adaptativo e Integrado del Software** de la **Universidad Nacional de Ingeniería (UNI)**.

Implementa una **API REST propia en capas** (`Node.js + Express + TypeScript`) conectada a **PostgreSQL en Supabase** y consumida en tiempo real por una **aplicación cliente móvil en Flutter + Dart**.


![Arquitectura de Luxxito Sports](docs/arquitectura/arquitectura.png)

## API pública y estado de la entrega (issue #14)

El backend se despliega automáticamente desde GitHub Actions: push/merge a `main` → pruebas backend y Flutter correctas → hook privado de Render con el SHA probado. Los PR y `develop` no publican el servicio. El secreto `RENDER_DEPLOY_HOOK_URL` se configura en GitHub Actions y nunca se guarda en el código. Si main avanzó durante una ejecución antigua, esa ejecución no despliega. El job confirma que Render aceptó la petición; el estado final se consulta en el panel Render y `/api/health`. La automatización no instala APK en los teléfonos ni ejecuta migraciones de base de datos.

En el panel Render, Auto-Deploy nativo queda en `Off`: el disparador automático es el job `Publicar backend en Render tras pruebas` de `.github/workflows/ci.yml`. Esto permite usar el repositorio público sin instalar la integración GitHub de Render y evita tener dos mecanismos publicando a la vez.

- API: `https://luxxito-sports-api.onrender.com/api` (31 endpoints, contrato OpenAPI 1.8.0).
- **Swagger UI público (probar la API desde el navegador): [https://luxxito-sports-api.onrender.com/api/docs](https://luxxito-sports-api.onrender.com/api/docs).**
- Diagnóstico: [GET /api/health](https://luxxito-sports-api.onrender.com/api/health), comprobado con HTTP 200 y `POSTGRES_POOL` el 03/11/2026.
- Publicación del APK: [release latest-apk](https://github.com/Arbolito-ctrl/LuxxitoSports/releases/tag/latest-apk). Verificar el commit del release, no usar como referencia el APK antiguo guardado en `release/`.
- El APK solo consume la API propia: no lleva claves de Supabase ni se conecta a la base. La instancia gratuita puede tardar al despertar; el timeout móvil es de 60 segundos.
- APK de producción **1.0.22** (build 22, commit `ac5a75c`) instalado en **TECNO KJ5, Android 13**: registro/login, catálogo de 6 canchas, Perfil y reserva con chalecos por S/105 comprobados. Los fallos conocidos de pagos/comprobantes/QR se atenderán después, por indicación de Juan.
- Seguimiento actual: [validación de infraestructura #14](docs/validaciones/2026-11-03-infra-issue14.md).

Para crear un servicio Render equivalente al configurado: repositorio público, rama `main`, Node 22, raíz `backend`, build `npm ci --include=dev && npm run build`, inicio `node dist/server.js`, plan Free y health `/api/health`. Cargar las variables privadas en Render; no se ejecuta `db:init` automáticamente contra una base existente.

Prueba local Android por USB: `adb reverse tcp:3000 tcp:3000` y, desde `mobile/`, `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api`. La base configurada en `backend/.env` determina si el backend usa PostgreSQL, REST o LOCAL_STORE. No presentar LOCAL_STORE como prueba de base real.

---

## 1. Estructura del Repositorio (Alineada con la Metodología Luxxito Sports)

```text
LuxxitoSports/
├── backend/                          # API REST propia (Node.js + Express + TypeScript)
│   ├── sql/
│   │   ├── schema.sql                # Esquema de 7 tablas relacionadas para Supabase PostgreSQL
│   │   ├── seed.sql                  # Datos iniciales (Complejos, Canchas y Extras en Lima)
│   │   └── migraciones/              # Cambios aplicados a la base existente (p. ej. cierre del acceso público)
│   ├── src/
│   │   ├── config/database.ts        # Conector a Supabase (Pool PostgreSQL / REST / Local)
│   │   ├── controllers/              # Controladores HTTP (reserva, pago, ticketQr, catalog, auth, dni, docs)
│   │   ├── services/                 # Reglas de negocio: auth, catalog, dni y reservas/
│   │   │   └── reservas/             # cotizacion, reserva, pago, comprobante, ticketQr y reglas compartidas
│   │   ├── middlewares/              # JWT, roles, titularidad y límite de consultas por IP
│   │   ├── repositories/             # Capa de Acceso a Datos y Transacciones
│   │   ├── routes/apiRoutes.ts       # Definición de los 31 endpoints bajo /api
│   │   └── tests/                    # 37 pruebas: api.test.ts (29) y dni.test.ts (8)
│   ├── .env.example                  # Plantilla pública de variables de entorno
│   └── package.json
├── mobile/                           # Aplicación Cliente Móvil (Flutter + Dart)
│   ├── lib/
│   │   ├── models/luxxito_models.dart
│   │   ├── services/api_service.dart # Fachada única hacia la API
│   │   ├── services/api/             # cliente_api (token, timeout, errores), auth, catalogo, reservas, pagos
│   │   ├── widgets/                  # Piezas visuales: reservas/, disponibilidad/, pagos/, catalogo/
│   │   ├── screens/
│   │   │   ├── auth_screen.dart
│   │   │   ├── explorar_screen.dart
│   │   │   ├── disponibilidad_reserva_screen.dart
│   │   │   ├── mis_reservas_screen.dart
│   │   │   └── perfil_config_screen.dart
│   │   └── main.dart
│   └── test/                        # widget_test.dart y api_config_test.dart
├── contracts/                        # Contratos OpenAPI y ejemplos de solicitudes/respuestas
│   ├── openapi.yaml
│   ├── ejemplos/
│   │   ├── validos/reserva_exitosa.json
│   │   └── invalidos/conflicto_horario.json
│   └── CHANGELOG.md
├── entregables/                      # Índice de entregables del Taller 3
│   ├── README.md                     # Dónde está cada entregable
│   ├── DOCUMENTO_TECNICO_TALLER3.pdf # Documento Técnico (carátula + 5 páginas)
│   ├── DOCUMENTACION_API_TALLER3.pdf # Documentación de los 31 endpoints con ejemplos reales
│   └── DEMOSTRACION_TALLER3.pdf      # Informe de la demostración con capturas
├── docs/                             # Documentación técnica y metodológica
│   ├── DOCUMENTO_TECNICO_TALLER3.md  # Versión Markdown del Documento Técnico
│   ├── GUIA_DE_ESTUDIO.md / .pdf     # Guía para entender el proyecto y preparar la sustentación
│   ├── API_DOCUMENTATION.md          # Documentación detallada de rutas, JSON y códigos HTTP
│   ├── LuxxitoSports.postman_collection.json # Colección Postman lista para importar
│   ├── PLAN.md                       # Plan y alcance del proyecto
│   ├── METODOLOGIA.md                # Acuerdo de trabajo, ramas y definición de terminado
│   ├── ESTADO.md                     # Estado vigente y evidencia de pruebas
│   ├── REGLAS_RESERVAS.md            # Máquina de estados y políticas de negocio
│   ├── OPERACION.md                  # Conciliación de pagos manuales y respaldos
│   ├── adr/                          # Architecture Decision Records
│   └── validaciones/                 # Informes fechados de validación
└── .github/                          # Automatización CI, CODEOWNERS y plantilla de PR
```

---

## 2. Configuración de Supabase y Variables de Entorno (`.env`)

Las credenciales nunca se suben al repositorio (`.gitignore` protege `backend/.env`).

1. Abre el archivo `backend/.env` (creado a partir de `backend/.env.example`) y pega tus credenciales de Supabase:
   ```env
   PORT=3000
   NODE_ENV=development

   # Opción A (Recomendada): Connection String de PostgreSQL desde Supabase Dashboard -> Connect
   DATABASE_URL=postgresql://postgres.[TU_REF]:[TU_PASSWORD]@aws-0-sa-east-1.pooler.supabase.com:6543/postgres

   # Storage (fotos de vouchers y canchas): URL y service role key desde Project Settings -> API
   SUPABASE_URL=https://[TU_REF].supabase.co
   SUPABASE_SERVICE_ROLE_KEY=[TU_SERVICE_ROLE_KEY]

   # Sugerencia de nombre por DNI en el registro (opcional; sin él el registro funciona igual)
   DECOLECTA_TOKEN=[TU_TOKEN_DE_DECOLECTA]
   ```
   Estas variables viven solo en el servidor (este `.env` y Render): ninguna se incluye en el APK.
2. **Inicializar las tablas y datos en Supabase**:
   - **Desde terminal** (si configuraste `DATABASE_URL`):
     ```bash
     cd backend
     npm run db:init
     ```
   - **Desde el Panel Web de Supabase**: Copia y ejecuta el contenido de `backend/sql/schema.sql` y luego `backend/sql/seed.sql` en el **SQL Editor** de tu proyecto en Supabase.

---

## 3. Instrucciones de Ejecución Paso a Paso

### 3.1. Iniciar la API REST Propia (`backend/`)
```bash
cd backend
npm install
npm run dev
```
- El servidor escuchará en `http://localhost:3000/api`.
- Verifica el estado en `http://localhost:3000/api/health`.

### 3.2. Ejecutar las Pruebas Automatizadas del Backend (37 casos: éxitos y fallos)
```bash
cd backend
npm test
```
Ejecuta **37 casos en almacenamiento local** con Vitest y Supertest: CRUD, cotización día/noche, conflictos `409`, validación `422`, pagos, QR, cancelación, seguridad, concurrencia, Swagger y la sugerencia de nombre por DNI (con el proveedor simulado). Estos tests no acreditan carga real a Storage ni el SQL de producción; eso se validó en la demostración contra Supabase.

La colección Postman también se puede ejecutar completa desde la terminal (con el backend levantado):

```bash
npx newman run docs/LuxxitoSports.postman_collection.json
```

### 3.3. Ejecutar la Aplicación Cliente Móvil (`mobile/`)
```bash
cd mobile
flutter pub get
flutter run
```
- La aplicación se desarrolla y distribuye **únicamente para Android** (APK). No se incluyen las plataformas iOS, macOS, Web, Windows ni Linux.
- La URL predeterminada es la **API pública de Render**, tanto en teléfono como en emulador. Para probar contra un backend local desde el emulador: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api`. Para teléfono por USB, usar el ejemplo de `adb reverse` anterior.

---

## 4. Historial de Cambios (Changelog)

- **v1.8.0 (2026-11-13):**
  - Sugerencia del nombre completo a partir del DNI en el registro (`GET /api/dni/:numero`, proveedor Decolecta, solo nombre y apellidos, límite de 10 consultas por minuto por IP).
  - Seguridad: la app ya no lleva claves de Supabase ni se conecta a la base; se cerró a la clave pública el acceso a las funciones `rpc_*` y a reservas, pagos y usuarios.
  - Código reorganizado por responsabilidad: `services/reservas/` en el backend, `services/api/` y `widgets/` en la app.
  - Documentación de la API completa (31 endpoints con ejemplos reales) y enlace público a Swagger UI.

- **v1.0.0 (2026-11-02):**
  - Implementación de esquema relacional PostgreSQL de 6 tablas (`complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) en `backend/sql/schema.sql`.
  - Desarrollo de API REST propia en capas (`controllers/`, `services/`, `repositories/`) con 14 endpoints, CRUD completo y 5 reglas de negocio verificables.
  - Desarrollo de aplicación móvil en Flutter (`mobile/`) con 3 pestañas (**Explorar · Mis reservas · Perfil**) y flujo completo de reserva, extras, pago manual Yape/Plin, Ticket QR y cancelación.
  - Creación de suite de 8 pruebas automatizadas, colección Postman, contrato OpenAPI 3.0.3 y Documento Técnico en PDF.

