-- ============================================================================
-- LUXXITO SPORTS - ESQUEMA DE BASE DE DATOS POSTGRESQL (SUPABASE)
-- Curso: SI806 Desarrollo Adaptativo e Integrado del Software - Taller 3 (UNI)
-- Incluye: 7 Tablas Relacionadas, Bucket Privado 'comprobantes', RLS y RPCs
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
    qr_usado_at TIMESTAMPTZ,
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

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS qr_usado_at TIMESTAMPTZ;

-- Índices para optimizar consultas de disponibilidad y cruce de horarios
CREATE INDEX IF NOT EXISTS idx_canchas_complejo ON canchas(complejo_id);
CREATE INDEX IF NOT EXISTS idx_canchas_deporte ON canchas(deporte);
CREATE INDEX IF NOT EXISTS idx_reservas_cancha_fecha ON reservas(cancha_id, fecha);
CREATE INDEX IF NOT EXISTS idx_reservas_estado ON reservas(estado);
CREATE INDEX IF NOT EXISTS idx_pagos_reserva ON pagos(reserva_id);

-- ============================================================================
-- 7. BUCKET PRIVADO DE SUPABASE STORAGE PARA COMPROBANTES (Issue #5 - LX-301)
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'buckets') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'comprobantes',
            'comprobantes',
            false,
            5242880,
            ARRAY['image/jpeg', 'image/png', 'image/webp']
        )
        ON CONFLICT (id) DO UPDATE SET
            public = false,
            file_size_limit = 5242880,
            allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];
    END IF;
END $$;

-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS) Y POLÍTICAS DE ACCESO (Issue #5)
-- La anon key queda limitada a lectura en tablas de consulta; las escrituras
-- y validaciones de negocio se ejecutan a través del servidor / funciones RPC.
-- ============================================================================
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE complejos ENABLE ROW LEVEL SECURITY;
ALTER TABLE canchas ENABLE ROW LEVEL SECURITY;
ALTER TABLE extras ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservas ENABLE ROW LEVEL SECURITY;
ALTER TABLE reserva_extras ENABLE ROW LEVEL SECURITY;
ALTER TABLE pagos ENABLE ROW LEVEL SECURITY;

-- Políticas para service_role (acceso total para el backend)
DROP POLICY IF EXISTS "service_role_all_usuarios" ON usuarios;
CREATE POLICY "service_role_all_usuarios" ON usuarios FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_all_complejos" ON complejos;
CREATE POLICY "service_role_all_complejos" ON complejos FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_all_canchas" ON canchas;
CREATE POLICY "service_role_all_canchas" ON canchas FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_all_extras" ON extras;
CREATE POLICY "service_role_all_extras" ON extras FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_all_reservas" ON reservas;
CREATE POLICY "service_role_all_reservas" ON reservas FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_all_reserva_extras" ON reserva_extras;
CREATE POLICY "service_role_all_reserva_extras" ON reserva_extras FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_all_pagos" ON pagos;
CREATE POLICY "service_role_all_pagos" ON pagos FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Políticas de solo lectura (SELECT) para anon y authenticated en catálogo y consultas
DROP POLICY IF EXISTS "anon_select_complejos" ON complejos;
CREATE POLICY "anon_select_complejos" ON complejos FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_select_canchas" ON canchas;
CREATE POLICY "anon_select_canchas" ON canchas FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_select_extras" ON extras;
CREATE POLICY "anon_select_extras" ON extras FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_select_reservas" ON reservas;
CREATE POLICY "anon_select_reservas" ON reservas FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_select_reserva_extras" ON reserva_extras;
CREATE POLICY "anon_select_reserva_extras" ON reserva_extras FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_select_pagos" ON pagos;
CREATE POLICY "anon_select_pagos" ON pagos FOR SELECT TO anon, authenticated USING (true);

-- ============================================================================
-- 9. FUNCIONES RPC EN SERVIDOR (SECURITY DEFINER)
-- Garantizan que toda regla de negocio y control de rol ADMIN se ejecute en el
-- servidor incluso cuando el cliente móvil opera en modo nube contra Supabase.
-- ============================================================================

-- 9.1 Autenticación segura en servidor (no expone password_hash)
CREATE OR REPLACE FUNCTION rpc_login_usuario(p_email TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user usuarios%ROWTYPE;
BEGIN
    SELECT * INTO v_user
    FROM usuarios
    WHERE LOWER(email) = LOWER(TRIM(p_email))
    LIMIT 1;

    IF NOT FOUND OR v_user.password_hash <> TRIM(p_password) THEN
        RAISE EXCEPTION 'INVALID_CREDENTIALS: Correo o contraseña incorrectos.';
    END IF;

    RETURN jsonb_build_object(
        'id', v_user.id,
        'nombre', v_user.nombre,
        'dni', v_user.dni,
        'telefono', v_user.telefono,
        'email', v_user.email,
        'rol', v_user.rol
    );
END;
$$;

-- 9.2 Registro de usuario en servidor (siempre con rol JUGADOR)
CREATE OR REPLACE FUNCTION rpc_registrar_usuario(
    p_nombre TEXT,
    p_dni TEXT,
    p_telefono TEXT,
    p_email TEXT,
    p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user usuarios%ROWTYPE;
BEGIN
    IF EXISTS (
        SELECT 1 FROM usuarios
        WHERE LOWER(email) = LOWER(TRIM(p_email)) OR dni = TRIM(p_dni)
    ) THEN
        RAISE EXCEPTION 'CONFLICT: Ya existe una cuenta registrada con ese correo o DNI.';
    END IF;

    INSERT INTO usuarios (nombre, dni, telefono, email, password_hash, rol)
    VALUES (TRIM(p_nombre), TRIM(p_dni), TRIM(p_telefono), LOWER(TRIM(p_email)), TRIM(p_password), 'JUGADOR')
    RETURNING * INTO v_user;

    RETURN jsonb_build_object(
        'id', v_user.id,
        'nombre', v_user.nombre,
        'dni', v_user.dni,
        'telefono', v_user.telefono,
        'email', v_user.email,
        'rol', v_user.rol
    );
END;
$$;

-- 9.3 Creación de cancha en servidor
CREATE OR REPLACE FUNCTION rpc_crear_cancha(
    p_complejo_id INT,
    p_nombre TEXT,
    p_deporte TEXT,
    p_superficie TEXT,
    p_techada BOOLEAN,
    p_precio_diurno NUMERIC,
    p_precio_nocturno NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cancha canchas%ROWTYPE;
BEGIN
    IF p_precio_diurno <= 0 OR p_precio_nocturno < p_precio_diurno THEN
        RAISE EXCEPTION 'BAD_REQUEST: El precio nocturno debe ser mayor o igual al precio diurno.';
    END IF;

    INSERT INTO canchas (complejo_id, nombre, deporte, superficie, techada, iluminacion, precio_hora_diurno, precio_hora_nocturno, estado)
    VALUES (p_complejo_id, TRIM(p_nombre), p_deporte, TRIM(p_superficie), p_techada, TRUE, p_precio_diurno, p_precio_nocturno, 'ACTIVA')
    RETURNING * INTO v_cancha;

    RETURN to_jsonb(v_cancha);
END;
$$;

-- 9.4 Creación de reserva con cotización en servidor, exclusión mutua y bloqueo de 20 min
CREATE OR REPLACE FUNCTION rpc_crear_reserva(
    p_cancha_id INT,
    p_cliente_nombre TEXT,
    p_cliente_dni TEXT,
    p_cliente_telefono TEXT,
    p_cliente_email TEXT,
    p_fecha DATE,
    p_hora_inicio INT,
    p_hora_fin INT,
    p_notas TEXT,
    p_extras JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cancha canchas%ROWTYPE;
    v_complejo complejos%ROWTYPE;
    v_conflicto_id INT;
    v_h INT;
    v_sub_cancha NUMERIC(10, 2) := 0;
    v_sub_extras NUMERIC(10, 2) := 0;
    v_total NUMERIC(10, 2) := 0;
    v_item JSONB;
    v_extra extras%ROWTYPE;
    v_usado INT;
    v_cant INT;
    v_reserva reservas%ROWTYPE;
BEGIN
    UPDATE reservas SET estado = 'VENCIDA', updated_at = NOW() WHERE estado = 'PENDIENTE_PAGO' AND expires_at < NOW();
    SELECT * INTO v_cancha FROM canchas WHERE id = p_cancha_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Cancha no encontrada.';
    END IF;
    SELECT * INTO v_complejo FROM complejos WHERE id = v_cancha.complejo_id;

    IF p_hora_inicio < v_complejo.hora_apertura OR p_hora_fin > v_complejo.hora_cierre OR p_hora_fin <= p_hora_inicio THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Horario fuera de atención del complejo.';
    END IF;
    IF (p_hora_fin - p_hora_inicio) > 4 THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: La duración máxima es de 4 horas.';
    END IF;

    SELECT id INTO v_conflicto_id
    FROM reservas
    WHERE cancha_id = p_cancha_id
      AND fecha = p_fecha
      AND estado IN ('PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA')
      AND hora_inicio < p_hora_fin
      AND hora_fin > p_hora_inicio
    LIMIT 1;

    IF v_conflicto_id IS NOT NULL THEN
        RAISE EXCEPTION 'CONFLICT: El turno ya se encuentra reservado o bloqueado (Reserva #%).', v_conflicto_id;
    END IF;

    FOR v_h IN p_hora_inicio..(p_hora_fin - 1) LOOP
        IF v_h >= 18 THEN
            v_sub_cancha := v_sub_cancha + v_cancha.precio_hora_nocturno;
        ELSE
            v_sub_cancha := v_sub_cancha + v_cancha.precio_hora_diurno;
        END IF;
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_extras, '[]'::JSONB)) LOOP
        v_cant := (v_item->>'cantidad')::INT;
        IF v_cant > 0 THEN
            SELECT * INTO v_extra FROM extras WHERE id = (v_item->>'extra_id')::INT AND complejo_id = v_complejo.id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'BAD_REQUEST: Extra no válido para este complejo.';
            END IF;
            SELECT COALESCE(SUM(re.cantidad), 0) INTO v_usado
            FROM reserva_extras re
            JOIN reservas r ON r.id = re.reserva_id
            WHERE re.extra_id = v_extra.id
              AND r.fecha = p_fecha
              AND r.estado IN ('PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA')
              AND r.hora_inicio < p_hora_fin
              AND r.hora_fin > p_hora_inicio;

            IF v_cant > (v_extra.stock_total - v_usado) THEN
                RAISE EXCEPTION 'CONFLICT: Stock insuficiente para %.', v_extra.nombre;
            END IF;
            v_sub_extras := v_sub_extras + (v_extra.precio_unitario * v_cant);
        END IF;
    END LOOP;

    v_total := v_sub_cancha + v_sub_extras;

    INSERT INTO reservas (
        cancha_id, cliente_nombre, cliente_dni, cliente_telefono, cliente_email,
        fecha, hora_inicio, hora_fin, subtotal_cancha, subtotal_extras, total,
        monto_pagado, monto_devolucion, estado, notas, expires_at
    ) VALUES (
        p_cancha_id, TRIM(p_cliente_nombre), TRIM(p_cliente_dni), TRIM(p_cliente_telefono), TRIM(p_cliente_email),
        p_fecha, p_hora_inicio, p_hora_fin, v_sub_cancha, v_sub_extras, v_total,
        0, 0, 'PENDIENTE_PAGO', p_notas, NOW() + INTERVAL '20 minutes'
    ) RETURNING * INTO v_reserva;

    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_extras, '[]'::JSONB)) LOOP
        v_cant := (v_item->>'cantidad')::INT;
        IF v_cant > 0 THEN
            SELECT * INTO v_extra FROM extras WHERE id = (v_item->>'extra_id')::INT;
            INSERT INTO reserva_extras (reserva_id, extra_id, cantidad, precio_unitario, subtotal)
            VALUES (v_reserva.id, v_extra.id, v_cant, v_extra.precio_unitario, v_extra.precio_unitario * v_cant);
        END IF;
    END LOOP;

    RETURN to_jsonb(v_reserva);
END;
$$;

-- 9.5 Actualización y eliminación controlada de reserva en servidor
CREATE OR REPLACE FUNCTION rpc_actualizar_reserva(
    p_reserva_id INT,
    p_cliente_telefono TEXT,
    p_notas TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reserva reservas%ROWTYPE;
BEGIN
    UPDATE reservas
    SET cliente_telefono = TRIM(p_cliente_telefono),
        notas = p_notas,
        updated_at = NOW()
    WHERE id = p_reserva_id AND estado NOT IN ('CANCELADA', 'VENCIDA')
    RETURNING * INTO v_reserva;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CONFLICT: No se puede actualizar la reserva.';
    END IF;
    RETURN to_jsonb(v_reserva);
END;
$$;

CREATE OR REPLACE FUNCTION rpc_eliminar_reserva(p_reserva_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reserva reservas%ROWTYPE;
BEGIN
    SELECT * INTO v_reserva FROM reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Reserva no encontrada.';
    END IF;
    IF v_reserva.estado = 'CONFIRMADA' THEN
        RAISE EXCEPTION 'CONFLICT: No se puede eliminar físicamente una reserva CONFIRMADA.';
    END IF;
    DELETE FROM reservas WHERE id = p_reserva_id;
    RETURN jsonb_build_object('deleted_id', p_reserva_id);
END;
$$;

-- 9.6 Registro de pago validado por el servidor
CREATE OR REPLACE FUNCTION rpc_registrar_pago(
    p_reserva_id INT,
    p_metodo TEXT,
    p_modalidad TEXT,
    p_monto NUMERIC,
    p_numero_operacion TEXT,
    p_auto_aprobar BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reserva reservas%ROWTYPE;
    v_pago pagos%ROWTYPE;
    v_esperado NUMERIC(10, 2);
BEGIN
    SELECT * INTO v_reserva FROM reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Reserva no encontrada.';
    END IF;
    IF v_reserva.estado IN ('CANCELADA', 'VENCIDA') THEN
        RAISE EXCEPTION 'CONFLICT: No se permiten pagos en estado %.', v_reserva.estado;
    END IF;

    IF p_modalidad = 'SENA_50' AND v_reserva.monto_pagado = 0 THEN
        v_esperado := ROUND(v_reserva.total * 0.5, 2);
    ELSE
        v_esperado := ROUND(v_reserva.total - v_reserva.monto_pagado, 2);
    END IF;

    IF ABS(p_monto - v_esperado) > 0.05 AND ABS(p_monto - v_reserva.total) > 0.05 THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: El monto enviado no coincide con la modalidad seleccionada.';
    END IF;

    INSERT INTO pagos (reserva_id, metodo, modalidad, monto, numero_operacion, estado)
    VALUES (
        p_reserva_id,
        UPPER(TRIM(p_metodo)),
        UPPER(TRIM(p_modalidad)),
        p_monto,
        TRIM(p_numero_operacion),
        CASE WHEN p_auto_aprobar THEN 'APROBADO' ELSE 'PENDIENTE_REVISION' END
    ) RETURNING * INTO v_pago;

    UPDATE reservas
    SET estado = CASE WHEN p_auto_aprobar THEN 'CONFIRMADA' ELSE 'EN_REVISION' END,
        monto_pagado = CASE WHEN p_auto_aprobar THEN LEAST(total, monto_pagado + p_monto) ELSE monto_pagado END,
        codigo_qr = CASE WHEN p_auto_aprobar THEN COALESCE(codigo_qr, 'LUXXITO-QR-' || p_reserva_id || '-' || UPPER(TRIM(p_numero_operacion))) ELSE codigo_qr END,
        updated_at = NOW()
    WHERE id = p_reserva_id
    RETURNING * INTO v_reserva;

    RETURN to_jsonb(v_reserva);
END;
$$;

-- 9.7 Aprobación y rechazo de pagos en servidor restringidos a rol ADMIN (LX-201)
CREATE OR REPLACE FUNCTION rpc_aprobar_pago(p_pago_id INT, p_rol TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pago pagos%ROWTYPE;
    v_reserva reservas%ROWTYPE;
BEGIN
    IF UPPER(COALESCE(p_rol, '')) <> 'ADMIN' THEN
        RAISE EXCEPTION 'FORBIDDEN: Acceso restringido al rol ADMIN.';
    END IF;

    SELECT * INTO v_pago FROM pagos WHERE id = p_pago_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Pago no encontrado.';
    END IF;
    SELECT * INTO v_reserva FROM reservas WHERE id = v_pago.reserva_id;

    IF v_pago.estado = 'APROBADO' THEN
        RETURN to_jsonb(v_reserva);
    END IF;
    IF v_pago.estado <> 'PENDIENTE_REVISION' THEN
        RAISE EXCEPTION 'CONFLICT: No se puede aprobar un pago en estado %.', v_pago.estado;
    END IF;

    UPDATE pagos
    SET estado = 'APROBADO',
        observacion = 'Comprobante verificado y conciliado.',
        reviewed_at = NOW()
    WHERE id = p_pago_id;

    UPDATE reservas
    SET estado = 'CONFIRMADA',
        monto_pagado = LEAST(total, monto_pagado + v_pago.monto),
        codigo_qr = COALESCE(codigo_qr, 'LUXXITO-QR-' || id || '-' || UPPER(TRIM(v_pago.numero_operacion))),
        updated_at = NOW()
    WHERE id = v_pago.reserva_id
    RETURNING * INTO v_reserva;

    RETURN to_jsonb(v_reserva);
END;
$$;

CREATE OR REPLACE FUNCTION rpc_rechazar_pago(p_pago_id INT, p_observacion TEXT, p_rol TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pago pagos%ROWTYPE;
    v_reserva reservas%ROWTYPE;
BEGIN
    IF UPPER(COALESCE(p_rol, '')) <> 'ADMIN' THEN
        RAISE EXCEPTION 'FORBIDDEN: Acceso restringido al rol ADMIN.';
    END IF;
    IF LENGTH(TRIM(COALESCE(p_observacion, ''))) < 5 THEN
        RAISE EXCEPTION 'BAD_REQUEST: La observación del rechazo es obligatoria (mínimo 5 caracteres).';
    END IF;

    SELECT * INTO v_pago FROM pagos WHERE id = p_pago_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Pago no encontrado.';
    END IF;
    SELECT * INTO v_reserva FROM reservas WHERE id = v_pago.reserva_id;

    IF v_pago.estado = 'RECHAZADO' THEN
        RETURN to_jsonb(v_reserva);
    END IF;
    IF v_pago.estado <> 'PENDIENTE_REVISION' THEN
        RAISE EXCEPTION 'CONFLICT: No se puede rechazar un pago en estado %.', v_pago.estado;
    END IF;

    UPDATE pagos
    SET estado = 'RECHAZADO',
        observacion = TRIM(p_observacion),
        reviewed_at = NOW()
    WHERE id = p_pago_id;

    UPDATE reservas
    SET estado = 'PENDIENTE_PAGO',
        expires_at = NOW() + INTERVAL '20 minutes',
        updated_at = NOW()
    WHERE id = v_pago.reserva_id AND estado = 'EN_REVISION'
    RETURNING * INTO v_reserva;

    SELECT * INTO v_reserva FROM reservas WHERE id = v_pago.reserva_id;
    RETURN to_jsonb(v_reserva);
END;
$$;

-- 9.8 Cancelación con regla de 24 horas ejecutada en el servidor
CREATE OR REPLACE FUNCTION rpc_cancelar_reserva(p_reserva_id INT, p_motivo TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reserva reservas%ROWTYPE;
    v_inicio_turno TIMESTAMPTZ;
    v_horas NUMERIC(10, 2);
    v_devolucion NUMERIC(10, 2) := 0;
    v_politica TEXT := 'SIN_PAGOS_PREVIOS';
BEGIN
    SELECT * INTO v_reserva FROM reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Reserva no encontrada.';
    END IF;
    IF v_reserva.estado = 'CANCELADA' THEN
        RAISE EXCEPTION 'CONFLICT: La reserva ya se encuentra cancelada.';
    END IF;

    v_inicio_turno := ((v_reserva.fecha::TEXT || ' ' || LPAD(v_reserva.hora_inicio::TEXT, 2, '0') || ':00:00-05:00')::TIMESTAMPTZ);
    v_horas := ROUND((EXTRACT(EPOCH FROM (v_inicio_turno - NOW())) / 3600.0)::NUMERIC, 2);

    IF v_reserva.monto_pagado > 0 THEN
        IF v_horas >= 24 THEN
            v_devolucion := v_reserva.monto_pagado;
            v_politica := 'REEMBOLSO_100_MAYOR_24H';
        ELSE
            v_devolucion := ROUND(v_reserva.monto_pagado * 0.5, 2);
            v_politica := 'RETENCION_50_MENOR_24H';
        END IF;
    END IF;

    UPDATE reservas
    SET estado = 'CANCELADA',
        monto_devolucion = v_devolucion,
        codigo_qr = NULL,
        motivo_cancelacion = COALESCE(NULLIF(TRIM(p_motivo), ''), 'Cancelada (' || v_politica || ')'),
        updated_at = NOW()
    WHERE id = p_reserva_id
    RETURNING * INTO v_reserva;

    RETURN jsonb_build_object(
        'politica_aplicada', v_politica,
        'horas_anticipacion', v_horas,
        'monto_devolucion', v_devolucion,
        'reserva', to_jsonb(v_reserva)
    );
END;
$$;


-- 9.9 Verificación única de Ticket QR en puerta (LX-202)
CREATE OR REPLACE FUNCTION rpc_verificar_qr(p_codigo_qr TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean TEXT;
    v_reserva reservas%ROWTYPE;
BEGIN
    v_clean := TRIM(COALESCE(p_codigo_qr, ''));
    IF v_clean = '' OR UPPER(v_clean) NOT LIKE 'LUXXITO-QR-%' THEN
        RAISE EXCEPTION 'BAD_REQUEST: Formato de código QR inválido.';
    END IF;

    SELECT * INTO v_reserva
    FROM reservas
    WHERE UPPER(codigo_qr) = UPPER(v_clean)
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: El código QR no corresponde a ninguna reserva activa.';
    END IF;
    IF v_reserva.estado <> 'CONFIRMADA' THEN
        RAISE EXCEPTION 'CONFLICT: La reserva no está confirmada (estado: %).', v_reserva.estado;
    END IF;
    IF v_reserva.qr_usado_at IS NOT NULL THEN
        RAISE EXCEPTION 'CONFLICT: Este Ticket QR ya fue utilizado previamente para registrar el ingreso.';
    END IF;

    UPDATE reservas
    SET qr_usado_at = NOW(),
        updated_at = NOW()
    WHERE id = v_reserva.id
    RETURNING * INTO v_reserva;

    RETURN jsonb_build_object(
        'verificado', TRUE,
        'estado_ingreso', 'INGRESO_REGISTRADO',
        'verificado_en', v_reserva.qr_usado_at,
        'reserva', to_jsonb(v_reserva)
    );
END;
$$;

-- Permisos de esquema: anon solo tiene SELECT en tablas con política RLS y EXECUTE en funciones RPC del servidor
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
GRANT SELECT ON complejos, canchas, extras, reservas, reserva_extras, pagos TO anon, authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;
