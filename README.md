# Luxxito Sports — Desarrollo Móvil e Integración de API REST (SI806 · Taller 3)

Proyecto desarrollado para el **Taller 3: Desarrollo e Integración de una API REST** del curso **SI806 Desarrollo Adaptativo e Integrado del Software** de la **Universidad Nacional de Ingeniería (UNI)**.

Implementa una **API REST propia en capas** (`Node.js + Express + TypeScript`) conectada a **PostgreSQL en Supabase** y consumida en tiempo real por una **aplicación cliente móvil en Flutter + Dart**.

---

## 1. Estructura del Repositorio (Alineada con la Metodología Luxxito Sports)

```text
LuxxitoSports/
├── backend/                          # API REST propia (Node.js + Express + TypeScript)
│   ├── sql/
│   │   ├── schema.sql                # Esquema de 6 tablas relacionadas para Supabase PostgreSQL
│   │   └── seed.sql                  # Datos iniciales (Complejos, Canchas y Extras en Lima)
│   ├── src/
│   │   ├── config/database.ts        # Conector a Supabase (Pool PostgreSQL / REST / Local)
│   │   ├── controllers/              # Capa de Controladores HTTP y códigos de estado
│   │   ├── services/                 # Capa de Servicios y 5 Reglas de Negocio
│   │   ├── repositories/             # Capa de Acceso a Datos y Transacciones
│   │   ├── routes/apiRoutes.ts       # Definición de los 14 endpoints bajo /api
│   │   └── tests/api.test.ts         # 17 casos de prueba automatizados (éxitos y fallos)
│   ├── .env.example                  # Plantilla pública de variables de entorno
│   └── package.json
├── mobile/                           # Aplicación Cliente Móvil (Flutter + Dart)
│   ├── lib/
│   │   ├── models/luxxito_models.dart
│   │   ├── services/api_service.dart # Cliente HTTP que consume los endpoints de la API
│   │   ├── screens/
│   │   │   ├── explorar_screen.dart
│   │   │   ├── disponibilidad_reserva_screen.dart
│   │   │   ├── mis_reservas_screen.dart
│   │   │   └── perfil_config_screen.dart
│   │   └── main.dart
│   └── test/widget_test.dart
├── contracts/                        # Contratos OpenAPI y ejemplos de solicitudes/respuestas
│   ├── openapi.yaml
│   ├── ejemplos/
│   │   ├── validos/reserva_exitosa.json
│   │   └── invalidos/conflicto_horario.json
│   └── CHANGELOG.md
├── docs/                             # Entregables obligatorios y documentación metodológica
│   ├── DOCUMENTO_TECNICO_TALLER3.pdf # Documento Técnico en PDF (<= 5 páginas sin carátula)
│   ├── DOCUMENTO_TECNICO_TALLER3.md  # Versión Markdown del Documento Técnico
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

   # Opción B (Alternativa): URL y API Key desde Supabase Dashboard -> Project Settings -> API
   SUPABASE_URL=https://[TU_REF].supabase.co
   SUPABASE_ANON_KEY=[TU_ANON_KEY]
   SUPABASE_SERVICE_ROLE_KEY=[TU_SERVICE_ROLE_KEY]
   ```
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

### 3.2. Ejecutar las Pruebas Automatizadas del Backend (`>= 5 casos: éxitos y fallos`)
```bash
cd backend
npm test
```
Ejecuta los **17 casos de prueba** con Vitest y Supertest verificando operaciones CRUD, cotización de tarifa diurna/nocturna, conflicto `409` por cruce de horario y por stock de extras, `422` por horarios pasados o fuera de atención, aprobación y rechazo idempotentes de comprobantes con Ticket QR, cancelación con regla de 24 horas (100% y 50%) y autenticación.

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
- Si ejecutas en **Emulador Android**, la app se conecta automáticamente a `http://10.0.2.2:3000/api` (y puedes cambiar la URL desde la pestaña **Perfil** con un toque).

---

## 4. Historial de Cambios (Changelog)

- **v1.0.0 (2026-11-02):**
  - Implementación de esquema relacional PostgreSQL de 6 tablas (`complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) en `backend/sql/schema.sql`.
  - Desarrollo de API REST propia en capas (`controllers/`, `services/`, `repositories/`) con 14 endpoints, CRUD completo y 5 reglas de negocio verificables.
  - Desarrollo de aplicación móvil en Flutter (`mobile/`) con 3 pestañas (**Explorar · Mis reservas · Perfil**) y flujo completo de reserva, extras, pago manual Yape/Plin, Ticket QR y cancelación.
  - Creación de suite de 8 pruebas automatizadas, colección Postman, contrato OpenAPI 3.0.3 y Documento Técnico en PDF.

