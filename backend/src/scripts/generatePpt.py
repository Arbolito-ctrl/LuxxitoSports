import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

def create_deck():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6] # Blank slide

    # Color Palette
    BG_DARK = RGBColor(15, 23, 42)       # Slate 900
    CARD_BG = RGBColor(30, 41, 59)       # Slate 800
    CARD_BORDER = RGBColor(51, 65, 85)   # Slate 700
    UNI_RED = RGBColor(220, 38, 38)      # Crimson Red
    UNI_RED_LIGHT = RGBColor(254, 226, 226)
    EMERALD = RGBColor(16, 185, 129)     # Sports Green
    EMERALD_LIGHT = RGBColor(209, 250, 229)
    TEXT_LIGHT = RGBColor(248, 250, 252) # Slate 50
    TEXT_MUTED = RGBColor(148, 163, 184) # Slate 400
    TEXT_DARK = RGBColor(15, 23, 42)
    ACCENT_BLUE = RGBColor(56, 189, 248) # Sky 400

    def add_header(slide, title, category="SI806 · TALLER 03 · API REST E INTEGRACIÓN"):
        # Top banner line
        top_bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(0.1))
        top_bar.fill.solid()
        top_bar.fill.fore_color.rgb = UNI_RED
        top_bar.line.fill.background()

        # Category / Header box
        tx_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.3), Inches(11.7), Inches(0.9))
        tf = tx_box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        p0 = tf.paragraphs[0]
        p0.text = category.upper()
        p0.font.size = Pt(11)
        p0.font.bold = True
        p0.font.color.rgb = UNI_RED

        p1 = tf.add_paragraph()
        p1.text = title
        p1.font.size = Pt(22)
        p1.font.bold = True
        p1.font.color.rgb = TEXT_LIGHT

    def set_slide_bg(slide, color=BG_DARK):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = color
        bg.line.fill.background()
        return bg

    # =========================================================================
    # SLIDE 1: PORTADA
    # =========================================================================
    s1 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s1, BG_DARK)

    # Accent Red Block on Top
    bar = s1.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(0.18))
    bar.fill.solid()
    bar.fill.fore_color.rgb = UNI_RED
    bar.line.fill.background()

    # Title container
    tb = s1.shapes.add_textbox(Inches(1.0), Inches(1.2), Inches(11.333), Inches(4.5))
    tf = tb.text_frame
    tf.word_wrap = True

    p = tf.paragraphs[0]
    p.text = "UNIVERSIDAD NACIONAL DE INGENIERÍA"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = UNI_RED

    p = tf.add_paragraph()
    p.text = "Facultad de Ingeniería Industrial y de Sistemas (FIIS) · SI806 Desarrollo Adaptativo"
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_MUTED

    p = tf.add_paragraph()
    p.text = "\nTaller 3: Desarrollo e Integración de una API REST"
    p.font.size = Pt(32)
    p.font.bold = True
    p.font.color.rgb = TEXT_LIGHT

    p = tf.add_paragraph()
    p.text = "Plataforma Móvil y Backend Propio: Luxxito Sports"
    p.font.size = Pt(20)
    p.font.bold = True
    p.font.color.rgb = EMERALD

    p = tf.add_paragraph()
    p.text = "Arquitectura en 3 capas (Flutter + Node.js/TS + PostgreSQL) · 7 Reglas de Negocio Oficiales · Demostración en APK"
    p.font.size = Pt(13)
    p.font.color.rgb = TEXT_MUTED

    # Authors Card
    c1 = s1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(1.0), Inches(5.3), Inches(11.333), Inches(1.4))
    c1.fill.solid()
    c1.fill.fore_color.rgb = CARD_BG
    c1.line.color.rgb = CARD_BORDER
    tf_c1 = c1.text_frame
    tf_c1.word_wrap = True
    tf_c1.margin_left = Inches(0.4)
    tf_c1.margin_top = Inches(0.2)

    p = tf_c1.paragraphs[0]
    p.text = "INTEGRANTES DEL EQUIPO:"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE

    p = tf_c1.add_paragraph()
    p.text = "• Steven Cadillo (Líder FrontEnd / QA / Demo)      • Elvis Arboleda (Líder Móvil / Integración)      • Juan Medina (Líder Backend / Base de Datos)"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = TEXT_LIGHT

    p = tf_c1.add_paragraph()
    p.text = "Repositorio: https://github.com/Arbolito-ctrl/LuxxitoSports  |  API en Producción: https://luxxito-sports-api.onrender.com/api"
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 2: OBJETIVO DEL TALLER Y PROBLEMÁTICA (Lámina 01/10 y 04/10)
    # =========================================================================
    s2 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s2)
    add_header(s2, "Objetivo del Taller & Problemática del Negocio")

    # Card 1: Requisito del Curso (PDF Lámina 01)
    card1 = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.5), Inches(5.7), Inches(5.3))
    card1.fill.solid()
    card1.fill.fore_color.rgb = CARD_BG
    card1.line.color.rgb = CARD_BORDER
    tf = card1.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = Inches(0.35)

    p = tf.paragraphs[0]
    p.text = "OBJETIVO DEL TALLER (SI806 - UNI)"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = UNI_RED

    items1 = [
        ("Desarrollar una API REST propia:", " Con base de datos relacional y lógica de negocio en el servidor, consumida realmente por una app cliente móvil."),
        ("El servidor como autoridad:", " Todas las decisiones de negocio (cálculo de tarifas, stock, validaciones, exclusión mutua) residen en el backend."),
        ("No datos simulados:", " Prohibido el uso de mocks, respuestas fijas o reutilización pasiva de servicios previos sin evolución funcional."),
        ("Entregables formales:", " Código en GitHub, documentación de API (OpenAPI/Postman), documento técnico en PDF y demostración en vivo.")
    ]
    for bold_txt, norm_txt in items1:
        p = tf.add_paragraph()
        p.text = f"\n• {bold_txt}"
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = TEXT_LIGHT
        run = p.add_run()
        run.text = norm_txt
        run.font.bold = False
        run.font.color.rgb = TEXT_MUTED

    # Card 2: Necesidad Concreta en Lima (PDF Lámina 04)
    card2 = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.8), Inches(1.5), Inches(5.7), Inches(5.3))
    card2.fill.solid()
    card2.fill.fore_color.rgb = CARD_BG
    card2.line.color.rgb = CARD_BORDER
    tf2 = card2.text_frame
    tf2.word_wrap = True
    tf2.margin_left = tf2.margin_right = tf2.margin_top = Inches(0.35)

    p = tf2.paragraphs[0]
    p.text = "NECESIDAD DEL NEGOCIO (LUXXITO SPORTS)"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = EMERALD

    items2 = [
        ("¿Qué problema concreto se resuelve?", " La desorganización en reservas de complejos deportivos en Lima: cruce de turnos (doble reserva), tarifas arbitrarias día/noche y fraude con comprobantes falsos."),
        ("¿Quién lo necesita y por qué?", " Jugadores que necesitan reservar y pagar en tiempo real sin esperar confirmación manual por chat, y administradores de canchas que requieren control y validación de acceso."),
        ("Solución integral:", " App móvil Android en Flutter integrada a API REST en Node.js/TypeScript y PostgreSQL en Supabase, con ticket QR verificable de uso único.")
    ]
    for bold_txt, norm_txt in items2:
        p = tf2.add_paragraph()
        p.text = f"\n• {bold_txt}"
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = TEXT_LIGHT
        run = p.add_run()
        run.text = norm_txt
        run.font.bold = False
        run.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 3: ESCENARIO Y ARQUITECTURA DE 3 NIVELES (Lámina 02/10)
    # =========================================================================
    s3 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s3)
    add_header(s3, "Escenario y Arquitectura: Separación de Responsabilidades")

    # 3 Column Cards
    col_w = Inches(3.7)
    gap = Inches(0.3)
    left_base = Inches(0.8)

    layers = [
        ("APP CLIENTE MÓVIL", "Flutter 3.x · Android APK", ACCENT_BLUE, [
            "Interfaz de usuario nativa y adaptativa.",
            "Consumo de API propia vía HTTPS (REST + JWT).",
            "Gestión de sesión persistente segura.",
            "Caché offline y reintentos ante desconexión.",
            "NUNCA calcula precios ni valida estados de negocio por su cuenta."
        ]),
        ("API REST PROPIA", "Node.js · Express · TypeScript (Render)", UNI_RED, [
            "Única autoridad de reglas de negocio.",
            "Autenticación JWT y control de acceso RBAC.",
            "Control de concurrencia y serialización de reservas.",
            "Subida y firma temporal de vouchers en Storage.",
            "Generación criptográfica de Ticket QR (SHA-256)."
        ]),
        ("BASE DE DATOS Y STORAGE", "PostgreSQL · Supabase Cloud", EMERALD, [
            "7 entidades relacionales con llaves foráneas y CHECKs.",
            "Row Level Security (RLS) activo en todas las tablas.",
            "Funciones RPC transaccionales SECURITY DEFINER.",
            "Bucket privado 'comprobantes' (máx 5 MB).",
            "Restricción de exclusión para solapamiento horario."
        ])
    ]

    for idx, (title, sub, color, bullet_list) in enumerate(layers):
        x = left_base + idx * (col_w + gap)
        c = s3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, Inches(1.5), col_w, Inches(4.2))
        c.fill.solid()
        c.fill.fore_color.rgb = CARD_BG
        c.line.color.rgb = color
        c.line.width = Pt(1.5)
        tf = c.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = Inches(0.25)

        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(13)
        p.font.bold = True
        p.font.color.rgb = color

        p = tf.add_paragraph()
        p.text = sub
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_MUTED

        for bullet in bullet_list:
            p = tf.add_paragraph()
            p.text = f"• {bullet}"
            p.font.size = Pt(11)
            p.font.color.rgb = TEXT_LIGHT

    # Bottom Architecture Diagram Card
    bot_card = s3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(5.9), Inches(11.7), Inches(1.1))
    bot_card.fill.solid()
    bot_card.fill.fore_color.rgb = CARD_BG
    bot_card.line.color.rgb = CARD_BORDER
    tf_b = bot_card.text_frame
    tf_b.word_wrap = True
    tf_b.margin_left = Inches(0.3)
    tf_b.margin_top = Inches(0.15)

    p = tf_b.paragraphs[0]
    p.text = "FLUJO DE INTEGRACIÓN END-TO-END:"
    p.font.size = Pt(10)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE

    p = tf_b.add_paragraph()
    p.text = "Celular Android (APK v1.0.22)  ──[HTTPS /api + Bearer JWT]──>  API Express en Render  ──[Pool PostgreSQL + RLS]──>  Supabase DB + Bucket Storage"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = TEXT_LIGHT

    # =========================================================================
    # SLIDE 4: MATRIZ DE REQUISITOS TÉCNICOS OBLIGATORIOS (Lámina 03/10)
    # =========================================================================
    s4 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s4)
    add_header(s4, "Cumplimiento Estricto de Requisitos Técnicos Obligatorios")

    # Table layout
    rows = 9
    cols = 4
    left = Inches(0.8)
    top = Inches(1.5)
    width = Inches(11.7)
    height = Inches(5.4)

    table_shape = s4.shapes.add_table(rows, cols, left, top, width, height)
    tbl = table_shape.table
    tbl.columns[0].width = Inches(2.2)
    tbl.columns[1].width = Inches(3.0)
    tbl.columns[2].width = Inches(5.1)
    tbl.columns[3].width = Inches(1.4)

    headers = ["REQUISITO DOCENTE", "ESPECIFICACIÓN", "IMPLEMENTACIÓN EN LUXXITO SPORTS", "ESTADO"]
    for i, h in enumerate(headers):
        cell = tbl.cell(0, i)
        cell.fill.solid()
        cell.fill.fore_color.rgb = CARD_BG
        p = cell.text_frame.paragraphs[0]
        p.text = h
        p.font.size = Pt(10)
        p.font.bold = True
        p.font.color.rgb = ACCENT_BLUE

    matrix_data = [
        ("API REST propia", "≥ 5 endpoints propios", "22 endpoints implementados bajo /api/ (OpenAPI v1.6.0)", "CUMPLE"),
        ("Base de datos", "≥ 2 entidades relacionadas", "7 tablas relacionadas: usuarios, complejos, canchas, extras, reservas, reserva_extras, pagos", "CUMPLE"),
        ("Operaciones", "Operaciones CRUD", "CRUD completo de canchas, complejos, reservas, extras y pagos", "CUMPLE"),
        ("Lógica de negocio", "≥ 1 operación más allá de CRUD", "7 reglas de negocio avanzadas calculadas exclusivamente en el servidor", "CUMPLE"),
        ("Cliente móvil", "Consume ≥ 5 endpoints", "App Flutter consume 15+ endpoints en producción vía HTTPS", "CUMPLE"),
        ("Validaciones y HTTP", "Entradas y códigos HTTP", "Status codes REST estándar: 200, 201, 400, 401, 403, 404, 409, 422, 500", "CUMPLE"),
        ("Manejo de Errores", "Conexión, respuesta y servidor", "Controlador centralizado de errores, reintentos y timeouts de 60s", "CUMPLE"),
        ("Pruebas", "≥ 5 casos: éxitos y fallos", "28 casos automatizados en Vitest/Supertest + 3 pruebas en Flutter + 38 en Postman", "CUMPLE")
    ]

    for r_idx, row in enumerate(matrix_data, start=1):
        for c_idx, val in enumerate(row):
            cell = tbl.cell(r_idx, c_idx)
            cell.fill.solid()
            cell.fill.fore_color.rgb = CARD_BG if r_idx % 2 == 0 else RGBColor(22, 30, 46)
            p = cell.text_frame.paragraphs[0]
            p.text = val
            p.font.size = Pt(10)
            if c_idx == 0:
                p.font.bold = True
                p.font.color.rgb = TEXT_LIGHT
            elif c_idx == 3:
                p.font.bold = True
                p.font.color.rgb = EMERALD
                p.alignment = PP_ALIGN.CENTER
            else:
                p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 5: LÓGICA DE NEGOCIO EN EL SERVIDOR (REGLAS 1 A 3)
    # =========================================================================
    s5 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s5)
    add_header(s5, "Reglas de Negocio en el Servidor: Cotización, Exclusión y Bloqueo")

    rules_p1 = [
        ("REGLA 1: Tarifa Diferenciada y Cotización Oficial (POST /api/reservas/cotizar)", [
            "El servidor es la única autoridad de precios: divide la reserva hora a hora.",
            "Tarifa Diurna: horas < 18:00 (ej. S/ 60/h). Tarifa Nocturna: horas >= 18:00 (ej. S/ 80/h).",
            "Cálculo automático de la seña obligatoria del 50% (modalidad SENA_50).",
            "Validación estricta de duración: mínimo 1 hora, máximo 4 horas consecutivas."
        ]),
        ("REGLA 2: Exclusión Mutua de Horarios y Stock de Extras por Intervalo", [
            "Evita colisiones: no permite reservas sobrelapadas en la misma cancha y fecha.",
            "Responde HTTP 409 Conflict si el horario ya está PENDIENTE_PAGO, EN_REVISION o CONFIRMADA.",
            "Cálculo dinámico de stock de extras (balones, chalecos): descuenta la indumentaria comprometida por otras canchas del complejo en el mismo rango horario."
        ]),
        ("REGLA 3: Bloqueo Transaccional de 20 Minutos y Vencimiento Automático", [
            "Al crear la reserva pasa a PENDIENTE_PAGO con expires_at fijado a NOW() + 20 minutos.",
            "Job automático expireOverdueReservas(): libera turnos abandonados pasando a VENCIDA.",
            "Protege la disponibilidad: otros jugadores pueden reservar turnos liberados de inmediato."
        ])
    ]

    y_pos = Inches(1.5)
    for title, bullets in rules_p1:
        box = s5.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), y_pos, Inches(11.7), Inches(1.65))
        box.fill.solid()
        box.fill.fore_color.rgb = CARD_BG
        box.line.color.rgb = CARD_BORDER
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.3)
        tf.margin_top = Inches(0.15)

        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = ACCENT_BLUE

        for b in bullets:
            p = tf.add_paragraph()
            p.text = f"• {b}"
            p.font.size = Pt(11)
            p.font.color.rgb = TEXT_LIGHT
        y_pos += Inches(1.8)

    # =========================================================================
    # SLIDE 6: LÓGICA DE NEGOCIO EN EL SERVIDOR (REGLAS 4 A 7)
    # =========================================================================
    s6 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s6)
    add_header(s6, "Reglas de Negocio en el Servidor: Pagos, ADMIN, 24 Horas y QR")

    rules_p2 = [
        ("REGLA 4: Pagos con Comprobante y Transición a EN_REVISION", [
            "Soporte para Yape, Plin y transferencia bancaria con N° de operación único.",
            "Subida obligatoria de voucher hacia el bucket privado 'comprobantes' (máx 5 MB, JPG/PNG).",
            "Pasa a estado EN_REVISION: suspende la expiración de 20 minutos mientras el operador revisa."
        ]),
        ("REGLA 5: Aprobación y Rechazo Idempotente por Rol ADMIN (RBAC)", [
            "Endpoints protegidos exclusivamente para ADMIN (JUGADOR recibe HTTP 403 Forbidden).",
            "Idempotencia: aprobar un pago ya conciliado no duplica saldos ni regenera tickets QR.",
            "Rechazo con motivo obligatorio (≥ 5 caracteres): reactiva 20 minutos para subsanar."
        ]),
        ("REGLA 6: Política de Cancelación con Umbral de 24 Horas", [
            "Cancelación con ≥ 24 horas de anticipación: devolución del 100% del monto pagado.",
            "Cancelación con < 24 horas de anticipación: penalidad del 50% y devolución del 50%.",
            "Revocación inmediata del Ticket QR y liberación del turno en la base de datos."
        ]),
        ("REGLA 7: Verificación Criptográfica de Ticket QR de Uso Único (POST /verificar-qr)", [
            "Código QR único generado tras pago aprobado: LUXXITO-QR-{id}-{hash SHA-256}.",
            "Primer escaneo en puerta: valida reserva activa y marca qr_usado_at (HTTP 200).",
            "Segundo escaneo (fraude): rechazo inmediato con HTTP 409 Conflict y fecha/hora del uso previo."
        ])
    ]

    y_pos = Inches(1.4)
    for title, bullets in rules_p2:
        box = s6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), y_pos, Inches(11.7), Inches(1.3))
        box.fill.solid()
        box.fill.fore_color.rgb = CARD_BG
        box.line.color.rgb = CARD_BORDER
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.3)
        tf.margin_top = Inches(0.12)

        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(11)
        p.font.bold = True
        p.font.color.rgb = EMERALD

        for b in bullets:
            p = tf.add_paragraph()
            p.text = f"• {b}"
            p.font.size = Pt(10.5)
            p.font.color.rgb = TEXT_LIGHT
        y_pos += Inches(1.4)

    # =========================================================================
    # SLIDE 7: SEGURIDAD, CONSISTENCIA Y CONCURRENCIA
    # =========================================================================
    s7 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s7)
    add_header(s7, "Seguridad, Integridad de Datos y Manejo de Concurrencia")

    cols_sec = [
        ("AUTENTICACIÓN Y ROLES (RBAC)", UNI_RED, [
            "Tokens JWT con tiempo de expiración.",
            "Roles diferenciados: JUGADOR vs ADMIN.",
            "Endpoints de pagos, catálogo y conciliación restringidos con middleware requireRole('ADMIN').",
            "Protección de privacidad: un jugador solo puede consultar o cancelar sus propias reservas."
        ]),
        ("BASE DE DATOS Y PERSISTENCIA", ACCENT_BLUE, [
            "Row Level Security (RLS) habilitado en las 7 tablas de PostgreSQL.",
            "Contraseñas hasheadas con algoritmo seguro scrypt y sal criptográfica de 16 bytes.",
            "Bucket comprobantes privado: sólo accesible vía URLs firmadas con vencimiento de 1 hora.",
            "Restricciones CHECK en BD para rangos de hora válidos."
        ]),
        ("CONTROL DE CONCURRENCIA", EMERALD, [
            "Manejo de peticiones simultáneas sobre el mismo horario (Race Conditions).",
            "Serialización transaccional en el repositorio con candados por fecha y reserva.",
            "Restricción de exclusión SQL (23P01) como barrera defensiva final en PostgreSQL.",
            "Garantiza que sólo una transacción adquiera el turno."
        ])
    ]

    for idx, (title, color, bullets) in enumerate(cols_sec):
        x = left_base + idx * (col_w + gap)
        c = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, Inches(1.5), col_w, Inches(5.3))
        c.fill.solid()
        c.fill.fore_color.rgb = CARD_BG
        c.line.color.rgb = color
        c.line.width = Pt(1.5)
        tf = c.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = Inches(0.25)

        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = color

        for bullet in bullets:
            p = tf.add_paragraph()
            p.text = f"\n• {bullet}"
            p.font.size = Pt(11)
            p.font.color.rgb = TEXT_LIGHT

    # =========================================================================
    # SLIDE 8: PRUEBAS AUTOMATIZADAS Y SUITE DE CONTROL DE CALIDAD
    # =========================================================================
    s8 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s8)
    add_header(s8, "Pruebas Automatizadas y Calidad de Software")

    p_cards = [
        ("BACKEND API: 28 CASOS EN VITEST + SUPERTEST", [
            "Operaciones CRUD completas y respuestas correctas (200, 201).",
            "Validación de tarifa diferenciada diurna vs nocturna (Casos 4 y 5).",
            "Conflicto de horarios superpuestos HTTP 409 (Caso 6).",
            "Stock insuficiente de extras por intervalo horario (Caso 7).",
            "Horarios pasados o fuera de rango comercial HTTP 422 (Casos 8 y 9).",
            "Aprobación/Rechazo idempotente y generación de Ticket QR (Casos 10 y 11).",
            "Cancelación con política de 24 horas y penalidad 50% (Casos 13 y 14).",
            "Control de acceso RBAC: rechazo 401 y 403 a usuarios no autorizados (Caso 18).",
            "Escaneo único de QR y rechazo 409 por reingreso (Caso 19).",
            "Expiración automática de bloqueos de 20 minutos (Caso 20).",
            "Subida y validación de vouchers a Storage privado (Caso 21).",
            "Concurrencia y exclusión mutua en peticiones paralelas (Casos 24 y 25)."
        ]),
        ("CLIENTE MÓVIL Y POSTMAN", [
            "Flutter Static Analysis: 0 warnings, 0 lint errors (flutter analyze).",
            "Pruebas de widgets automatizadas en Flutter (flutter test).",
            "Colección Postman Newman: 38 peticiones HTTP y 63 aserciones automatizadas.",
            "Validación integral de contratos OpenAPI v1.6.0 sin desviaciones.",
            "Pruebas de latencia y reconexión ante cold-starts de la nube (timeout 60s)."
        ])
    ]

    c_w = Inches(5.7)
    for idx, (title, bullets) in enumerate(p_cards):
        x = Inches(0.8) + idx * Inches(6.0)
        c = s8.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, Inches(1.5), c_w, Inches(5.3))
        c.fill.solid()
        c.fill.fore_color.rgb = CARD_BG
        c.line.color.rgb = CARD_BORDER
        tf = c.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = Inches(0.3)

        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = ACCENT_BLUE if idx == 0 else EMERALD

        for b in bullets:
            p = tf.add_paragraph()
            p.text = f"• {b}"
            p.font.size = Pt(10.5)
            p.font.color.rgb = TEXT_LIGHT

    # =========================================================================
    # SLIDE 9: DEMOSTRACIÓN EN VIVO (FLUJO DEL JUGADOR EN CELULAR REAL)
    # =========================================================================
    s9 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s9)
    add_header(s9, "Demostración en Android Físico: Flujo del Jugador (TECNO KJ5)")

    # Insert screenshots if available
    img_dir = "docs/validaciones/capturas"
    imgs_s9 = [
        ("01-explorar-filtros.png", "1. Explorar Canchas", "Filtros por distrito y deporte"),
        ("02-cotizacion-servidor.png", "2. Cotización Servidor", "Tarifa día/noche + extras"),
        ("03a-reserva-creada-app.png", "3. Reserva Generada", "Bloqueo temporal de 20 min"),
        ("04b-conflicto-409-app.png", "4. Conflicto HTTP 409", "Detección de horario ocupado")
    ]

    for idx, (fname, label, desc) in enumerate(imgs_s9):
        fpath = os.path.join(img_dir, fname)
        x_pos = Inches(0.8) + idx * Inches(2.95)
        # Card background
        card = s9.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x_pos, Inches(1.5), Inches(2.85), Inches(5.4))
        card.fill.solid()
        card.fill.fore_color.rgb = CARD_BG
        card.line.color.rgb = CARD_BORDER

        # Label
        tf = card.text_frame
        tf.word_wrap = True
        tf.margin_top = Inches(0.12)
        tf.margin_left = Inches(0.15)
        p = tf.paragraphs[0]
        p.text = label
        p.font.size = Pt(11)
        p.font.bold = True
        p.font.color.rgb = ACCENT_BLUE
        p2 = tf.add_paragraph()
        p2.text = desc
        p2.font.size = Pt(9.5)
        p2.font.color.rgb = TEXT_MUTED

        if os.path.exists(fpath):
            s9.shapes.add_picture(fpath, x_pos + Inches(0.18), Inches(2.2), Inches(2.49), Inches(4.55))

    # =========================================================================
    # SLIDE 10: DEMOSTRACIÓN EN VIVO (FLUJO DE PAGOS, ADMIN Y TICKET QR)
    # =========================================================================
    s10 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s10)
    add_header(s10, "Demostración en Android Físico: Pagos, ADMIN y Ticket QR")

    imgs_s10 = [
        ("05a-pago-en-revision.png", "5. Pago Subido", "Voucher enviado (EN_REVISION)"),
        ("05d-bandeja-pagos-foto.png", "6. Bandeja ADMIN", "Inspección de comprobante"),
        ("05e-ticket-qr.png", "7. Ticket QR Emitido", "Código único e intransferible"),
        ("05h-qr-ya-usado.png", "8. Doble Uso Rechazado", "Control de fraude HTTP 409")
    ]

    for idx, (fname, label, desc) in enumerate(imgs_s10):
        fpath = os.path.join(img_dir, fname)
        x_pos = Inches(0.8) + idx * Inches(2.95)
        card = s10.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x_pos, Inches(1.5), Inches(2.85), Inches(5.4))
        card.fill.solid()
        card.fill.fore_color.rgb = CARD_BG
        card.line.color.rgb = CARD_BORDER

        tf = card.text_frame
        tf.word_wrap = True
        tf.margin_top = Inches(0.12)
        tf.margin_left = Inches(0.15)
        p = tf.paragraphs[0]
        p.text = label
        p.font.size = Pt(11)
        p.font.bold = True
        p.font.color.rgb = EMERALD
        p2 = tf.add_paragraph()
        p2.text = desc
        p2.font.size = Pt(9.5)
        p2.font.color.rgb = TEXT_MUTED

        if os.path.exists(fpath):
            s10.shapes.add_picture(fpath, x_pos + Inches(0.18), Inches(2.2), Inches(2.49), Inches(4.55))

    # =========================================================================
    # SLIDE 11: ENTREGABLES OBLIGATORIOS (Lámina 08/10)
    # =========================================================================
    s11 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s11)
    add_header(s11, "Inventario de Entregables Obligatorios del Taller 3")

    deliverables = [
        ("1. REPOSITORIO GITHUB OFICIAL", "https://github.com/Arbolito-ctrl/LuxxitoSports", [
            "Código completo: mobile/ (Flutter) y backend/ (Node.js + TS).",
            "Historial trazable con flujo Git de 3 niveles: feature -> develop -> main.",
            "Integraciones vía Pull Requests con Squash & Merge y cero force-pushes."
        ]),
        ("2. DOCUMENTO TÉCNICO FORMAL (PDF)", "entregables/DOCUMENTO_TECNICO_TALLER3.pdf", [
            "Formato académico UNI de 6 páginas (carátula + 5 páginas de contenido técnico).",
            "Explicación exhaustiva de arquitectura, modelo relacional, reglas y endpoints."
        ]),
        ("3. DOCUMENTACIÓN DE LA API REST (PDF)", "entregables/DOCUMENTACION_API_TALLER3.pdf", [
            "Especificación completa de rutas, métodos, parámetros y respuestas JSON.",
            "Contrato formal OpenAPI v1.6.0 en contracts/openapi.yaml."
        ]),
        ("4. EVIDENCIA DE DEMOSTRACIÓN Y APK", "entregables/DEMOSTRACION_TALLER3.pdf", [
            "Registro fotográfico paso a paso ejecutado sobre el teléfono físico Android.",
            "APK descargable y autoinstalable publicado en GitHub Releases (tag latest-apk)."
        ])
    ]

    y_pos = Inches(1.5)
    for title, link, points in deliverables:
        box = s11.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), y_pos, Inches(11.7), Inches(1.25))
        box.fill.solid()
        box.fill.fore_color.rgb = CARD_BG
        box.line.color.rgb = CARD_BORDER
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.3)
        tf.margin_top = Inches(0.12)

        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(11.5)
        p.font.bold = True
        p.font.color.rgb = ACCENT_BLUE

        p = tf.add_paragraph()
        p.text = f"Ubicación / Enlace: {link}"
        p.font.size = Pt(9.5)
        p.font.color.rgb = TEXT_MUTED

        for pt in points:
            p = tf.add_paragraph()
            p.text = f"• {pt}"
            p.font.size = Pt(10)
            p.font.color.rgb = TEXT_LIGHT

        y_pos += Inches(1.35)

    # =========================================================================
    # SLIDE 12: CONCLUSIONES Y PREGUNTAS (CIERRE)
    # =========================================================================
    s12 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s12)
    add_header(s12, "Conclusiones y Ronda de Sustentación")

    c_end = s12.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(1.5), Inches(1.6), Inches(10.333), Inches(4.5))
    c_end.fill.solid()
    c_end.fill.fore_color.rgb = CARD_BG
    c_end.line.color.rgb = EMERALD
    c_end.line.width = Pt(2)
    tf = c_end.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = Inches(0.5)
    tf.margin_top = Inches(0.4)

    p = tf.paragraphs[0]
    p.text = "CONCLUSIONES DEL PROYECTO LUXXITO SPORTS"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = EMERALD

    conclusions = [
        ("Autoridad exclusiva en el Servidor:", " Garantiza que el cliente no pueda adulterar precios, forzar reservas en horarios ocupados ni aprobarse turnos a sí mismo."),
        ("Persistencia Relacional Íntegra:", " La base de datos en PostgreSQL con RLS y transacciones transfiere la seguridad de datos a nivel de motor SQL."),
        ("Calidad Verificable:", " 28 pruebas automatizadas de backend, análisis estático móvil limpio y validación en APK físico demuestran solidez técnica para producción."),
        ("Metodología Colaborativa:", " Desarrollo ágil por componentes (Steven, Elvis, Juan) bajo flujo estricto de Git, PRs revisados y CI/CD automatizado a Render.")
    ]
    for c_title, c_desc in conclusions:
        p = tf.add_paragraph()
        p.text = f"\n✓ {c_title}"
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = TEXT_LIGHT
        run = p.add_run()
        run.text = f" {c_desc}"
        run.font.bold = False
        run.font.color.rgb = TEXT_MUTED

    p_thanks = tf.add_paragraph()
    p_thanks.text = "\n¡Muchas Gracias! Quedamos atentos a sus consultas."
    p_thanks.font.size = Pt(15)
    p_thanks.font.bold = True
    p_thanks.font.color.rgb = ACCENT_BLUE

    # Save to deliverables and docs
    out_dir = "entregables"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "PRESENTACION_TALLER3_LUXXITO_SPORTS.pptx")
    prs.save(out_path)
    print(f"Presentation saved to {out_path}")

    docs_path = os.path.join("docs", "PRESENTACION_TALLER3_LUXXITO_SPORTS.pptx")
    prs.save(docs_path)
    print(f"Presentation copy saved to {docs_path}")

if __name__ == "__main__":
    create_deck()

