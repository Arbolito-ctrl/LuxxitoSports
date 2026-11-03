-- ============================================================================
-- LUXXITO SPORTS - ESQUEMA DE BASE DE DATOS POSTGRESQL (SUPABASE)
-- Curso: SI806 Desarrollo Adaptativo e Integrado del Software - Taller 3 (UNI)
-- ============================================================================

-- 0. Tabla de Usuarios (Jugadores y Administradores)
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    dni VARCHAR(15) NOT NULL UNIQUE,
    telefono VARCHAR(30) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(200) NOT NULL,
    rol VARCHAR(20) NOT NULL DEFAULT 'JUGADOR' CHECK (rol IN ('JUGADOR', 'ADMIN')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1. Tabla de Complejos Deportivos
CREATE TABLE IF NOT EXISTS complejos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    distrito VARCHAR(80) NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    hora_apertura INTEGER NOT NULL DEFAULT 7 CHECK (hora_apertura >= 0 AND hora_apertura <= 23),
    hora_cierre INTEGER NOT NULL DEFAULT 23 CHECK (hora_cierre > hora_apertura AND hora_cierre <= 24),
    imagen_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla de Canchas (Relación N:1 con Complejos)
CREATE TABLE IF NOT EXISTS canchas (
    id SERIAL PRIMARY KEY,
    complejo_id INTEGER NOT NULL REFERENCES complejos(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    deporte VARCHAR(50) NOT NULL CHECK (deporte IN ('Futbol 5', 'Futbol 7', 'Futbol 11', 'Voley', 'Tenis', 'Padel', 'Basquet')),
    superficie VARCHAR(60) NOT NULL DEFAULT 'Grass Sintetico Pro',
    techada BOOLEAN NOT NULL DEFAULT FALSE,
    iluminacion BOOLEAN NOT NULL DEFAULT TRUE,
    precio_hora_diurno NUMERIC(10, 2) NOT NULL CHECK (precio_hora_diurno > 0),
    precio_hora_nocturno NUMERIC(10, 2) NOT NULL CHECK (precio_hora_nocturno >= precio_hora_diurno),
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'MANTENIMIENTO', 'INACTIVA')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Tabla de Extras / Equipamiento Adicional por Complejo (Relación N:1 con Complejos)
CREATE TABLE IF NOT EXISTS extras (
    id SERIAL PRIMARY KEY,
    complejo_id INTEGER NOT NULL REFERENCES complejos(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(200),
    precio_unitario NUMERIC(10, 2) NOT NULL CHECK (precio_unitario >= 0),
    stock_total INTEGER NOT NULL CHECK (stock_total >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- 4. Tabla de Reservas (Relación N:1 con Canchas)
CREATE TABLE IF NOT EXISTS reservas (
    id SERIAL PRIMARY KEY,
    cancha_id INTEGER NOT NULL REFERENCES canchas(id) ON DELETE RESTRICT,
    cliente_nombre VARCHAR(120) NOT NULL,
    cliente_dni VARCHAR(15) NOT NULL,
    cliente_telefono VARCHAR(30) NOT NULL,
    cliente_email VARCHAR(120) NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio INTEGER NOT NULL CHECK (hora_inicio >= 0 AND hora_inicio <= 23),
    hora_fin INTEGER NOT NULL CHECK (hora_fin > hora_inicio AND hora_fin <= 24),
    subtotal_cancha NUMERIC(10, 2) NOT NULL CHECK (subtotal_cancha >= 0),
    subtotal_extras NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (subtotal_extras >= 0),
    total NUMERIC(10, 2) NOT NULL CHECK (total >= 0),
    monto_pagado NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (monto_pagado >= 0),
    monto_devolucion NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (monto_devolucion >= 0),
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE_PAGO'
        CHECK (estado IN ('PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA', 'CANCELADA', 'VENCIDA')),
    codigo_qr VARCHAR(120),
    motivo_cancelacion TEXT,
    notas TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Tabla Intermedia de Extras por Reserva (Relación N:M entre Reservas y Extras)
CREATE TABLE IF NOT EXISTS reserva_extras (
    id SERIAL PRIMARY KEY,
    reserva_id INTEGER NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    extra_id INTEGER NOT NULL REFERENCES extras(id) ON DELETE RESTRICT,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10, 2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    UNIQUE (reserva_id, extra_id)
);

-- 6. Tabla de Pagos y Comprobantes (Relación N:1 con Reservas)
CREATE TABLE IF NOT EXISTS pagos (
    id SERIAL PRIMARY KEY,
    reserva_id INTEGER NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    metodo VARCHAR(30) NOT NULL CHECK (metodo IN ('YAPE', 'PLIN', 'TRANSFERENCIA')),
    modalidad VARCHAR(20) NOT NULL DEFAULT 'TOTAL' CHECK (modalidad IN ('SENA_50', 'TOTAL')),
    monto NUMERIC(10, 2) NOT NULL CHECK (monto > 0),
    numero_operacion VARCHAR(60) NOT NULL,
    comprobante_url TEXT,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE_REVISION'
        CHECK (estado IN ('PENDIENTE_REVISION', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO')),
    observacion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

-- Índices para optimizar consultas de disponibilidad y cruce de horarios
CREATE INDEX IF NOT EXISTS idx_canchas_complejo ON canchas(complejo_id);
CREATE INDEX IF NOT EXISTS idx_canchas_deporte ON canchas(deporte);
CREATE INDEX IF NOT EXISTS idx_reservas_cancha_fecha ON reservas(cancha_id, fecha);
CREATE INDEX IF NOT EXISTS idx_reservas_estado ON reservas(estado);
CREATE INDEX IF NOT EXISTS idx_pagos_reserva ON pagos(reserva_id);

-- Permisos para API de Supabase (PostgREST) si se usa SUPABASE_URL + SUPABASE_ANON_KEY
ALTER TABLE usuarios DISABLE ROW LEVEL SECURITY;
ALTER TABLE complejos DISABLE ROW LEVEL SECURITY;
ALTER TABLE canchas DISABLE ROW LEVEL SECURITY;
ALTER TABLE extras DISABLE ROW LEVEL SECURITY;
ALTER TABLE reservas DISABLE ROW LEVEL SECURITY;
ALTER TABLE reserva_extras DISABLE ROW LEVEL SECURITY;
ALTER TABLE pagos DISABLE ROW LEVEL SECURITY;
