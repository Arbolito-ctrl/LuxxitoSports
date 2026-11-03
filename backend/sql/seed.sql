-- ============================================================================
-- LUXXITO SPORTS - DATOS SEMILLA INICIALES (LIMA, PERÚ - MONEDA PEN S/)
-- ============================================================================

INSERT INTO usuarios (id, nombre, dni, telefono, email, password_hash, rol)
VALUES
  (1, 'Elvis Arboleda', '74125896', '987654321', 'elvis.arboleda@uni.pe', 'luxxito2026', 'JUGADOR'),
  (2, 'Admin Luxxito Sports', '70001111', '999888777', 'admin@luxxitosports.pe', 'admin2026', 'ADMIN')
ON CONFLICT (email) DO NOTHING;

SELECT setval('usuarios_id_seq', (SELECT COALESCE(MAX(id), 1) FROM usuarios));

INSERT INTO complejos (id, nombre, distrito, direccion, telefono, hora_apertura, hora_cierre, imagen_url, activo)
VALUES
  (1, 'Luxxito Arena San Miguel', 'San Miguel', 'Av. La Marina 2450, San Miguel', '987654321', 7, 23, 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=800&q=80', TRUE),
  (2, 'Complejo Deportivo Surco Pro', 'Santiago de Surco', 'Av. Primavera 1520, Surco', '987111222', 7, 23, 'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80', TRUE),
  (3, 'Centro Deportivo Miraflores Club', 'Miraflores', 'Av. Ejército 890, Miraflores', '987333444', 8, 22, 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&w=800&q=80', TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO canchas (id, complejo_id, nombre, deporte, superficie, techada, iluminacion, precio_hora_diurno, precio_hora_nocturno, estado)
VALUES
  (1, 1, 'Cancha Monumental 1', 'Futbol 7', 'Grass Sintetico FIFA Quality', FALSE, TRUE, 90.00, 120.00, 'ACTIVA'),
  (2, 1, 'Cancha La Bombonera 2', 'Futbol 5', 'Grass Sintetico Pro', TRUE, TRUE, 70.00, 95.00, 'ACTIVA'),
  (3, 1, 'Polideportivo Vóley Central', 'Voley', 'Piso Flotante Poliuretano', TRUE, TRUE, 65.00, 85.00, 'ACTIVA'),
  (4, 2, 'Cancha Champions Surco', 'Futbol 7', 'Grass Sintetico FIFA Pro', FALSE, TRUE, 100.00, 135.00, 'ACTIVA'),
  (5, 2, 'Pádel Crystal Court 1', 'Padel', 'Césped Azul + Cristal Templado', TRUE, TRUE, 80.00, 110.00, 'ACTIVA'),
  (6, 3, 'Court Central Tenis', 'Tenis', 'Arcilla Roja', FALSE, TRUE, 75.00, 100.00, 'ACTIVA')
ON CONFLICT (id) DO NOTHING;

INSERT INTO extras (id, complejo_id, nombre, descripcion, precio_unitario, stock_total, activo)
VALUES
  (1, 1, 'Juego de Chalecos (x12)', 'Pack de 12 chalecos deportivos diferenciados en 2 colores', 15.00, 4, TRUE),
  (2, 1, 'Balón Oficial Adidas Pro', 'Balón de alta presión cosido térmicamente', 10.00, 6, TRUE),
  (3, 1, 'Árbitro Oficial Por Hora', 'Servicio de arbitraje con tarjetas y silbato', 45.00, 2, TRUE),
  (4, 2, 'Juego de Chalecos Surco (x14)', 'Pack de 14 chalecos deportivos transpirables', 15.00, 3, TRUE),
  (5, 2, 'Pack 2 Palas de Pádel + Tubo Pelotas', 'Alquiler de equipamiento completo para pádel', 25.00, 4, TRUE),
  (6, 3, 'Canasta de 30 Pelotas de Tenis', 'Pelotas presurizadas para entrenamiento o partido', 20.00, 3, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Ajustar secuencias de PostgreSQL
SELECT setval('complejos_id_seq', (SELECT COALESCE(MAX(id), 1) FROM complejos));
SELECT setval('canchas_id_seq', (SELECT COALESCE(MAX(id), 1) FROM canchas));
SELECT setval('extras_id_seq', (SELECT COALESCE(MAX(id), 1) FROM extras));
