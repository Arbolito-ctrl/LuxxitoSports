import fs from 'fs';
import path from 'path';
import { getDbMode, getPgPool, getSupabaseClient } from '../config/database';
import {
  Cancha,
  Complejo,
  EstadoCancha,
  EstadoPago,
  EstadoReserva,
  Extra,
  Pago,
  Reserva,
  ReservaExtraItem,
} from '../types/models';

interface LocalDatabaseState {
  complejos: Complejo[];
  canchas: Cancha[];
  extras: Extra[];
  reservas: Reserva[];
  reserva_extras: ReservaExtraItem[];
  pagos: Pago[];
}

function getInitialSeedState(): LocalDatabaseState {
  return {
    complejos: [
      {
        id: 1,
        nombre: 'Luxxito Arena San Miguel',
        distrito: 'San Miguel',
        direccion: 'Av. La Marina 2450, San Miguel',
        telefono: '987654321',
        hora_apertura: 7,
        hora_cierre: 23,
        imagen_url:
          'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=800&q=80',
        activo: true,
      },
      {
        id: 2,
        nombre: 'Complejo Deportivo Surco Pro',
        distrito: 'Santiago de Surco',
        direccion: 'Av. Primavera 1520, Surco',
        telefono: '987111222',
        hora_apertura: 7,
        hora_cierre: 23,
        imagen_url:
          'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80',
        activo: true,
      },
      {
        id: 3,
        nombre: 'Centro Deportivo Miraflores Club',
        distrito: 'Miraflores',
        direccion: 'Av. Ejército 890, Miraflores',
        telefono: '987333444',
        hora_apertura: 8,
        hora_cierre: 22,
        imagen_url:
          'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&w=800&q=80',
        activo: true,
      },
    ],
    canchas: [
      {
        id: 1,
        complejo_id: 1,
        nombre: 'Cancha Monumental 1',
        deporte: 'Futbol 7',
        superficie: 'Grass Sintetico FIFA Quality',
        techada: false,
        iluminacion: true,
        precio_hora_diurno: 90,
        precio_hora_nocturno: 120,
        estado: 'ACTIVA',
      },
      {
        id: 2,
        complejo_id: 1,
        nombre: 'Cancha La Bombonera 2',
        deporte: 'Futbol 5',
        superficie: 'Grass Sintetico Pro',
        techada: true,
        iluminacion: true,
        precio_hora_diurno: 70,
        precio_hora_nocturno: 95,
        estado: 'ACTIVA',
      },
      {
        id: 3,
        complejo_id: 1,
        nombre: 'Polideportivo Vóley Central',
        deporte: 'Voley',
        superficie: 'Piso Flotante Poliuretano',
        techada: true,
        iluminacion: true,
        precio_hora_diurno: 65,
        precio_hora_nocturno: 85,
        estado: 'ACTIVA',
      },
      {
        id: 4,
        complejo_id: 2,
        nombre: 'Cancha Champions Surco',
        deporte: 'Futbol 7',
        superficie: 'Grass Sintetico FIFA Pro',
        techada: false,
        iluminacion: true,
        precio_hora_diurno: 100,
        precio_hora_nocturno: 135,
        estado: 'ACTIVA',
      },
      {
        id: 5,
        complejo_id: 2,
        nombre: 'Pádel Crystal Court 1',
        deporte: 'Padel',
        superficie: 'Césped Azul + Cristal Templado',
        techada: true,
        iluminacion: true,
        precio_hora_diurno: 80,
        precio_hora_nocturno: 110,
        estado: 'ACTIVA',
      },
      {
        id: 6,
        complejo_id: 3,
        nombre: 'Court Central Tenis',
        deporte: 'Tenis',
        superficie: 'Arcilla Roja',
        techada: false,
        iluminacion: true,
        precio_hora_diurno: 75,
        precio_hora_nocturno: 100,
        estado: 'ACTIVA',
      },
    ],
    extras: [
      {
        id: 1,
        complejo_id: 1,
        nombre: 'Juego de Chalecos (x12)',
        descripcion: 'Pack de 12 chalecos deportivos diferenciados en 2 colores',
        precio_unitario: 15,
        stock_total: 4,
        activo: true,
      },
      {
        id: 2,
        complejo_id: 1,
        nombre: 'Balón Oficial Adidas Pro',
        descripcion: 'Balón de alta presión cosido térmicamente',
        precio_unitario: 10,
        stock_total: 6,
        activo: true,
      },
      {
        id: 3,
        complejo_id: 1,
        nombre: 'Árbitro Oficial Por Hora',
        descripcion: 'Servicio de arbitraje con tarjetas y silbato',
        precio_unitario: 45,
        stock_total: 2,
        activo: true,
      },
      {
        id: 4,
        complejo_id: 2,
        nombre: 'Juego de Chalecos Surco (x14)',
        descripcion: 'Pack de 14 chalecos deportivos transpirables',
        precio_unitario: 15,
        stock_total: 3,
        activo: true,
      },
      {
        id: 5,
        complejo_id: 2,
        nombre: 'Pack 2 Palas de Pádel + Tubo Pelotas',
        descripcion: 'Alquiler de equipamiento completo para pádel',
        precio_unitario: 25,
        stock_total: 4,
        activo: true,
      },
      {
        id: 6,
        complejo_id: 3,
        nombre: 'Canasta de 30 Pelotas de Tenis',
        descripcion: 'Pelotas presurizadas para entrenamiento o partido',
        precio_unitario: 20,
        stock_total: 3,
        activo: true,
      },
    ],
    reservas: [],
    reserva_extras: [],
    pagos: [],
  };
}

const LOCAL_FILE_PATH = path.join(__dirname, '../../data/local_db.json');

export class DataRepository {
  private memState: LocalDatabaseState;

  constructor() {
    this.memState = this.loadLocalState();
  }

  private loadLocalState(): LocalDatabaseState {
    if (process.env.NODE_ENV === 'test') {
      return getInitialSeedState();
    }
    try {
      if (fs.existsSync(LOCAL_FILE_PATH)) {
        const raw = fs.readFileSync(LOCAL_FILE_PATH, 'utf-8');
        return JSON.parse(raw) as LocalDatabaseState;
      }
    } catch {
      // Fallback to seed state
    }
    const seed = getInitialSeedState();
    this.saveLocalState(seed);
    return seed;
  }

  private saveLocalState(state: LocalDatabaseState = this.memState): void {
    if (process.env.NODE_ENV === 'test') return;
    try {
      const dir = path.dirname(LOCAL_FILE_PATH);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(LOCAL_FILE_PATH, JSON.stringify(state, null, 2), 'utf-8');
    } catch {
      // Ignore write error in restricted environments
    }
  }

  public resetTestState(): void {
    this.memState = getInitialSeedState();
  }

  private normalizeCancha(row: any): Cancha {
    return {
      ...row,
      id: Number(row.id),
      complejo_id: Number(row.complejo_id),
      precio_hora_diurno: Number(row.precio_hora_diurno),
      precio_hora_nocturno: Number(row.precio_hora_nocturno),
      techada: Boolean(row.techada),
      iluminacion: Boolean(row.iluminacion),
    };
  }

  private normalizeExtra(row: any): Extra {
    return {
      ...row,
      id: Number(row.id),
      complejo_id: Number(row.complejo_id),
      precio_unitario: Number(row.precio_unitario),
      stock_total: Number(row.stock_total),
      activo: Boolean(row.activo),
    };
  }

  private normalizeReserva(row: any): Reserva {
    const fechaStr =
      row.fecha instanceof Date
        ? row.fecha.toISOString().split('T')[0]
        : String(row.fecha).split('T')[0];
    return {
      ...row,
      id: Number(row.id),
      cancha_id: Number(row.cancha_id),
      hora_inicio: Number(row.hora_inicio),
      hora_fin: Number(row.hora_fin),
      subtotal_cancha: Number(row.subtotal_cancha),
      subtotal_extras: Number(row.subtotal_extras),
      total: Number(row.total),
      monto_pagado: Number(row.monto_pagado),
      monto_devolucion: Number(row.monto_devolucion ?? 0),
      fecha: fechaStr,
    };
  }

  private normalizePago(row: any): Pago {
    return {
      ...row,
      id: Number(row.id),
      reserva_id: Number(row.reserva_id),
      monto: Number(row.monto),
    };
  }

  // ==========================================================================
  // COMPLEJOS
  // ==========================================================================
  async getComplejos(distrito?: string): Promise<Complejo[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const pool = getPgPool();
      if (distrito) {
        const res = await pool.query(
          'SELECT * FROM complejos WHERE activo = TRUE AND LOWER(distrito) = LOWER($1) ORDER BY id ASC',
          [distrito]
        );
        return res.rows;
      }
      const res = await pool.query('SELECT * FROM complejos WHERE activo = TRUE ORDER BY id ASC');
      return res.rows;
    }
    if (mode === 'SUPABASE_REST') {
      let query = getSupabaseClient().from('complejos').select('*').eq('activo', true).order('id');
      if (distrito) {
        query = query.ilike('distrito', distrito);
      }
      const { data, error } = await query;
      if (error) throw error;
      return (data || []) as Complejo[];
    }
    return this.memState.complejos.filter(
      (c) => c.activo && (!distrito || c.distrito.toLowerCase() === distrito.toLowerCase())
    );
  }

  async getComplejoById(id: number): Promise<Complejo | null> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query('SELECT * FROM complejos WHERE id = $1', [id]);
      return res.rows[0] || null;
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('complejos')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      return data as Complejo | null;
    }
    return this.memState.complejos.find((c) => c.id === id) || null;
  }

  // ==========================================================================
  // CANCHAS (CRUD COMPLETO)
  // ==========================================================================
  async getCanchas(filters?: {
    complejo_id?: number;
    distrito?: string;
    deporte?: string;
    estado?: string;
  }): Promise<Cancha[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (filters?.complejo_id) {
        params.push(filters.complejo_id);
        conditions.push(`c.complejo_id = $${params.length}`);
      }
      if (filters?.distrito) {
        params.push(filters.distrito);
        conditions.push(`LOWER(co.distrito) = LOWER($${params.length})`);
      }
      if (filters?.deporte) {
        params.push(filters.deporte);
        conditions.push(`LOWER(c.deporte) = LOWER($${params.length})`);
      }
      if (filters?.estado) {
        params.push(filters.estado);
        conditions.push(`c.estado = $${params.length}`);
      }
      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const sql = `
        SELECT c.*, co.nombre AS complejo_nombre, co.distrito, co.direccion
        FROM canchas c
        JOIN complejos co ON co.id = c.complejo_id
        ${whereClause}
        ORDER BY c.id ASC
      `;
      const res = await getPgPool().query(sql, params);
      return res.rows.map((r) => this.normalizeCancha(r));
    }

    if (mode === 'SUPABASE_REST') {
      const { data: complejos } = await getSupabaseClient().from('complejos').select('*');
      const complejoMap = new Map((complejos || []).map((c: any) => [Number(c.id), c]));
      let query = getSupabaseClient().from('canchas').select('*').order('id');
      if (filters?.complejo_id) query = query.eq('complejo_id', filters.complejo_id);
      if (filters?.deporte) query = query.ilike('deporte', filters.deporte);
      if (filters?.estado) query = query.eq('estado', filters.estado);
      const { data, error } = await query;
      if (error) throw error;
      let list = (data || []).map((r: any) => {
        const comp = complejoMap.get(Number(r.complejo_id));
        return this.normalizeCancha({
          ...r,
          complejo_nombre: comp?.nombre,
          distrito: comp?.distrito,
          direccion: comp?.direccion,
        });
      });
      if (filters?.distrito) {
        list = list.filter(
          (c) => c.distrito?.toLowerCase() === filters.distrito!.toLowerCase()
        );
      }
      return list;
    }

    return this.memState.canchas
      .map((c) => {
        const comp = this.memState.complejos.find((co) => co.id === c.complejo_id);
        return {
          ...c,
          complejo_nombre: comp?.nombre,
          distrito: comp?.distrito,
          direccion: comp?.direccion,
        };
      })
      .filter((c) => {
        if (filters?.complejo_id && c.complejo_id !== filters.complejo_id) return false;
        if (
          filters?.distrito &&
          c.distrito?.toLowerCase() !== filters.distrito.toLowerCase()
        )
          return false;
        if (filters?.deporte && c.deporte.toLowerCase() !== filters.deporte.toLowerCase())
          return false;
        if (filters?.estado && c.estado !== filters.estado) return false;
        return true;
      });
  }

  async getCanchaById(id: number): Promise<Cancha | null> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `SELECT c.*, co.nombre AS complejo_nombre, co.distrito, co.direccion
         FROM canchas c
         JOIN complejos co ON co.id = c.complejo_id
         WHERE c.id = $1`,
        [id]
      );
      return res.rows[0] ? this.normalizeCancha(res.rows[0]) : null;
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('canchas')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      const comp = await this.getComplejoById(Number(data.complejo_id));
      return this.normalizeCancha({
        ...data,
        complejo_nombre: comp?.nombre,
        distrito: comp?.distrito,
        direccion: comp?.direccion,
      });
    }
    const cancha = this.memState.canchas.find((c) => c.id === id);
    if (!cancha) return null;
    const comp = this.memState.complejos.find((co) => co.id === cancha.complejo_id);
    return {
      ...cancha,
      complejo_nombre: comp?.nombre,
      distrito: comp?.distrito,
      direccion: comp?.direccion,
    };
  }

  async createCancha(input: Omit<Cancha, 'id' | 'created_at'>): Promise<Cancha> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `INSERT INTO canchas
          (complejo_id, nombre, deporte, superficie, techada, iluminacion, precio_hora_diurno, precio_hora_nocturno, estado)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          input.complejo_id,
          input.nombre,
          input.deporte,
          input.superficie,
          input.techada,
          input.iluminacion,
          input.precio_hora_diurno,
          input.precio_hora_nocturno,
          input.estado,
        ]
      );
      return (await this.getCanchaById(Number(res.rows[0].id)))!;
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('canchas')
        .insert({
          complejo_id: input.complejo_id,
          nombre: input.nombre,
          deporte: input.deporte,
          superficie: input.superficie,
          techada: input.techada,
          iluminacion: input.iluminacion,
          precio_hora_diurno: input.precio_hora_diurno,
          precio_hora_nocturno: input.precio_hora_nocturno,
          estado: input.estado,
        })
        .select('*')
        .single();
      if (error) throw error;
      return (await this.getCanchaById(Number(data.id)))!;
    }
    const nextId =
      this.memState.canchas.reduce((max, c) => Math.max(max, c.id), 0) + 1;
    const created: Cancha = {
      id: nextId,
      ...input,
      created_at: new Date().toISOString(),
    };
    this.memState.canchas.push(created);
    this.saveLocalState();
    return (await this.getCanchaById(nextId))!;
  }

  async updateCancha(
    id: number,
    updates: Partial<
      Pick<
        Cancha,
        | 'nombre'
        | 'deporte'
        | 'superficie'
        | 'techada'
        | 'iluminacion'
        | 'precio_hora_diurno'
        | 'precio_hora_nocturno'
        | 'estado'
      >
    >
  ): Promise<Cancha | null> {
    const existing = await this.getCanchaById(id);
    if (!existing) return null;
    const merged = { ...existing, ...updates };
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      await getPgPool().query(
        `UPDATE canchas
         SET nombre = $1, deporte = $2, superficie = $3, techada = $4, iluminacion = $5,
             precio_hora_diurno = $6, precio_hora_nocturno = $7, estado = $8
         WHERE id = $9`,
        [
          merged.nombre,
          merged.deporte,
          merged.superficie,
          merged.techada,
          merged.iluminacion,
          merged.precio_hora_diurno,
          merged.precio_hora_nocturno,
          merged.estado,
          id,
        ]
      );
      return this.getCanchaById(id);
    }
    if (mode === 'SUPABASE_REST') {
      const { error } = await getSupabaseClient()
        .from('canchas')
        .update({
          nombre: merged.nombre,
          deporte: merged.deporte,
          superficie: merged.superficie,
          techada: merged.techada,
          iluminacion: merged.iluminacion,
          precio_hora_diurno: merged.precio_hora_diurno,
          precio_hora_nocturno: merged.precio_hora_nocturno,
          estado: merged.estado,
        })
        .eq('id', id);
      if (error) throw error;
      return this.getCanchaById(id);
    }
    const idx = this.memState.canchas.findIndex((c) => c.id === id);
    this.memState.canchas[idx] = merged;
    this.saveLocalState();
    return this.getCanchaById(id);
  }

  // ==========================================================================
  // EXTRAS Y STOCK POR INTERVALO
  // ==========================================================================
  async getExtrasByComplejo(complejoId: number): Promise<Extra[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        'SELECT * FROM extras WHERE complejo_id = $1 AND activo = TRUE ORDER BY id ASC',
        [complejoId]
      );
      return res.rows.map((r) => this.normalizeExtra(r));
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('extras')
        .select('*')
        .eq('complejo_id', complejoId)
        .eq('activo', true)
        .order('id');
      if (error) throw error;
      return (data || []).map((r) => this.normalizeExtra(r));
    }
    return this.memState.extras.filter((e) => e.complejo_id === complejoId && e.activo);
  }

  async getExtraUsedQuantityInInterval(
    extraId: number,
    fecha: string,
    horaInicio: number,
    horaFin: number
  ): Promise<number> {
    const activeStates: EstadoReserva[] = ['PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'];
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `SELECT COALESCE(SUM(re.cantidad), 0) AS usado
         FROM reserva_extras re
         JOIN reservas r ON r.id = re.reserva_id
         WHERE re.extra_id = $1
           AND r.fecha = $2
           AND r.estado IN ('PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA')
           AND r.hora_inicio < $4
           AND r.hora_fin > $3`,
        [extraId, fecha, horaInicio, horaFin]
      );
      return Number(res.rows[0]?.usado || 0);
    }
    if (mode === 'SUPABASE_REST') {
      const { data: reservas } = await getSupabaseClient()
        .from('reservas')
        .select('id, hora_inicio, hora_fin, estado')
        .eq('fecha', fecha)
        .in('estado', activeStates);
      const overlappingIds = (reservas || [])
        .filter((r: any) => Number(r.hora_inicio) < horaFin && Number(r.hora_fin) > horaInicio)
        .map((r: any) => Number(r.id));
      if (overlappingIds.length === 0) return 0;
      const { data: reItems } = await getSupabaseClient()
        .from('reserva_extras')
        .select('cantidad')
        .eq('extra_id', extraId)
        .in('reserva_id', overlappingIds);
      return (reItems || []).reduce((sum: number, item: any) => sum + Number(item.cantidad), 0);
    }

    const overlappingIds = this.memState.reservas
      .filter(
        (r) =>
          r.fecha === fecha &&
          activeStates.includes(r.estado) &&
          r.hora_inicio < horaFin &&
          r.hora_fin > horaInicio
      )
      .map((r) => r.id);
    return this.memState.reserva_extras
      .filter((re) => re.extra_id === extraId && overlappingIds.includes(re.reserva_id!))
      .reduce((sum, re) => sum + re.cantidad, 0);
  }

  // ==========================================================================
  // RESERVAS (CRUD + CONSULTAS DE DISPONIBILIDAD)
  // ==========================================================================
  async getReservasByCanchaAndDate(canchaId: number, fecha: string): Promise<Reserva[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `SELECT * FROM reservas WHERE cancha_id = $1 AND fecha = $2 ORDER BY hora_inicio ASC`,
        [canchaId, fecha]
      );
      return res.rows.map((r) => this.normalizeReserva(r));
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('reservas')
        .select('*')
        .eq('cancha_id', canchaId)
        .eq('fecha', fecha)
        .order('hora_inicio');
      if (error) throw error;
      return (data || []).map((r) => this.normalizeReserva(r));
    }
    return this.memState.reservas
      .filter((r) => r.cancha_id === canchaId && r.fecha === fecha)
      .sort((a, b) => a.hora_inicio - b.hora_inicio);
  }

  async getReservas(filters?: {
    estado?: string;
    cliente_dni?: string;
    fecha?: string;
  }): Promise<Reserva[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (filters?.estado) {
        params.push(filters.estado);
        conditions.push(`r.estado = $${params.length}`);
      }
      if (filters?.cliente_dni) {
        params.push(filters.cliente_dni);
        conditions.push(`r.cliente_dni = $${params.length}`);
      }
      if (filters?.fecha) {
        params.push(filters.fecha);
        conditions.push(`r.fecha = $${params.length}`);
      }
      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const res = await getPgPool().query(
        `SELECT r.*, c.nombre AS cancha_nombre, c.deporte, co.id AS complejo_id, co.nombre AS complejo_nombre, co.distrito
         FROM reservas r
         JOIN canchas c ON c.id = r.cancha_id
         JOIN complejos co ON co.id = c.complejo_id
         ${whereClause}
         ORDER BY r.fecha DESC, r.hora_inicio DESC, r.id DESC`,
        params
      );
      const list = res.rows.map((r) => this.normalizeReserva(r));
      for (const item of list) {
        item.extras = await this.getReservaExtras(item.id);
        item.pagos = await this.getPagosByReserva(item.id);
      }
      return list;
    }

    if (mode === 'SUPABASE_REST') {
      let query = getSupabaseClient()
        .from('reservas')
        .select('*')
        .order('id', { ascending: false });
      if (filters?.estado) query = query.eq('estado', filters.estado);
      if (filters?.cliente_dni) query = query.eq('cliente_dni', filters.cliente_dni);
      if (filters?.fecha) query = query.eq('fecha', filters.fecha);
      const { data, error } = await query;
      if (error) throw error;
      const list: Reserva[] = [];
      for (const raw of data || []) {
        const enriched = await this.getReservaById(Number(raw.id));
        if (enriched) list.push(enriched);
      }
      return list;
    }

    let list = [...this.memState.reservas];
    if (filters?.estado) list = list.filter((r) => r.estado === filters.estado);
    if (filters?.cliente_dni)
      list = list.filter((r) => r.cliente_dni === filters.cliente_dni);
    if (filters?.fecha) list = list.filter((r) => r.fecha === filters.fecha);
    list.sort((a, b) => b.id - a.id);

    const result: Reserva[] = [];
    for (const r of list) {
      const full = await this.getReservaById(r.id);
      if (full) result.push(full);
    }
    return result;
  }

  async getReservaExtras(reservaId: number): Promise<ReservaExtraItem[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `SELECT re.*, e.nombre
         FROM reserva_extras re
         JOIN extras e ON e.id = re.extra_id
         WHERE re.reserva_id = $1`,
        [reservaId]
      );
      return res.rows.map((r) => ({
        id: Number(r.id),
        reserva_id: Number(r.reserva_id),
        extra_id: Number(r.extra_id),
        nombre: r.nombre,
        cantidad: Number(r.cantidad),
        precio_unitario: Number(r.precio_unitario),
        subtotal: Number(r.subtotal),
      }));
    }
    if (mode === 'SUPABASE_REST') {
      const { data } = await getSupabaseClient()
        .from('reserva_extras')
        .select('*')
        .eq('reserva_id', reservaId);
      const { data: extrasData } = await getSupabaseClient().from('extras').select('id, nombre');
      const nameMap = new Map((extrasData || []).map((e: any) => [Number(e.id), e.nombre]));
      return (data || []).map((r: any) => ({
        id: Number(r.id),
        reserva_id: Number(r.reserva_id),
        extra_id: Number(r.extra_id),
        nombre: nameMap.get(Number(r.extra_id)),
        cantidad: Number(r.cantidad),
        precio_unitario: Number(r.precio_unitario),
        subtotal: Number(r.subtotal),
      }));
    }
    return this.memState.reserva_extras
      .filter((re) => re.reserva_id === reservaId)
      .map((re) => {
        const ex = this.memState.extras.find((e) => e.id === re.extra_id);
        return { ...re, nombre: ex?.nombre };
      });
  }

  async getPagosByReserva(reservaId: number): Promise<Pago[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        'SELECT * FROM pagos WHERE reserva_id = $1 ORDER BY id ASC',
        [reservaId]
      );
      return res.rows.map((r) => this.normalizePago(r));
    }
    if (mode === 'SUPABASE_REST') {
      const { data } = await getSupabaseClient()
        .from('pagos')
        .select('*')
        .eq('reserva_id', reservaId)
        .order('id');
      return (data || []).map((r) => this.normalizePago(r));
    }
    return this.memState.pagos.filter((p) => p.reserva_id === reservaId);
  }

  async getPagos(estado?: EstadoPago): Promise<Pago[]> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = estado
        ? await getPgPool().query(
            'SELECT * FROM pagos WHERE estado = $1 ORDER BY created_at ASC, id ASC',
            [estado]
          )
        : await getPgPool().query('SELECT * FROM pagos ORDER BY created_at ASC, id ASC');
      return res.rows.map((r) => this.normalizePago(r));
    }
    if (mode === 'SUPABASE_REST') {
      let query = getSupabaseClient().from('pagos').select('*');
      if (estado) query = query.eq('estado', estado);
      const { data, error } = await query.order('created_at').order('id');
      if (error) throw error;
      return (data || []).map((r) => this.normalizePago(r));
    }
    return this.memState.pagos.filter((p) => !estado || p.estado === estado);
  }

  async getReservaByCodigoQr(codigoQr: string): Promise<Reserva | null> {
    const clean = codigoQr.trim();
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        'SELECT id FROM reservas WHERE UPPER(codigo_qr) = UPPER($1) LIMIT 1',
        [clean]
      );
      if (!res.rows[0]) return null;
      return this.getReservaById(Number(res.rows[0].id));
    }
    if (mode === 'SUPABASE_REST') {
      const { data } = await getSupabaseClient()
        .from('reservas')
        .select('id')
        .ilike('codigo_qr', clean)
        .maybeSingle();
      if (!data) return null;
      return this.getReservaById(Number(data.id));
    }
    const found = this.memState.reservas.find(
      (r) => r.codigo_qr && r.codigo_qr.toUpperCase() === clean.toUpperCase()
    );
    if (!found) return null;
    return this.getReservaById(found.id);
  }

  async expireOverdueReservas(nowMs: number = Date.now()): Promise<number> {
    const nowIso = new Date(nowMs).toISOString();
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        "UPDATE reservas SET estado = 'VENCIDA', updated_at = NOW() WHERE estado = 'PENDIENTE_PAGO' AND expires_at < $1",
        [nowIso]
      );
      return res.rowCount || 0;
    }
    if (mode === 'SUPABASE_REST') {
      const { data } = await getSupabaseClient()
        .from('reservas')
        .update({ estado: 'VENCIDA', updated_at: nowIso })
        .eq('estado', 'PENDIENTE_PAGO')
        .lt('expires_at', nowIso)
        .select('id');
      return (data || []).length;
    }
    let count = 0;
    for (const r of this.memState.reservas) {
      if (r.estado === 'PENDIENTE_PAGO' && Date.parse(r.expires_at) < nowMs) {
        r.estado = 'VENCIDA';
        r.updated_at = nowIso;
        count++;
      }
    }
    if (count > 0) this.saveLocalState();
    return count;
  }

  async getReservaById(id: number): Promise<Reserva | null> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `SELECT r.*, c.nombre AS cancha_nombre, c.deporte, co.id AS complejo_id, co.nombre AS complejo_nombre, co.distrito
         FROM reservas r
         JOIN canchas c ON c.id = r.cancha_id
         JOIN complejos co ON co.id = c.complejo_id
         WHERE r.id = $1`,
        [id]
      );
      if (!res.rows[0]) return null;
      const reserva = this.normalizeReserva(res.rows[0]);
      reserva.extras = await this.getReservaExtras(id);
      reserva.pagos = await this.getPagosByReserva(id);
      return reserva;
    }

    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('reservas')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      const cancha = await this.getCanchaById(Number(data.cancha_id));
      const reserva = this.normalizeReserva({
        ...data,
        cancha_nombre: cancha?.nombre,
        deporte: cancha?.deporte,
        complejo_id: cancha?.complejo_id,
        complejo_nombre: cancha?.complejo_nombre,
        distrito: cancha?.distrito,
      });
      reserva.extras = await this.getReservaExtras(id);
      reserva.pagos = await this.getPagosByReserva(id);
      return reserva;
    }

    const found = this.memState.reservas.find((r) => r.id === id);
    if (!found) return null;
    const cancha = await this.getCanchaById(found.cancha_id);
    const extras = await this.getReservaExtras(id);
    const pagos = await this.getPagosByReserva(id);
    return {
      ...found,
      cancha_nombre: cancha?.nombre,
      deporte: cancha?.deporte,
      complejo_id: cancha?.complejo_id,
      complejo_nombre: cancha?.complejo_nombre,
      distrito: cancha?.distrito,
      extras,
      pagos,
    };
  }

  async createReserva(
    data: Omit<
      Reserva,
      'id' | 'created_at' | 'updated_at' | 'extras' | 'pagos' | 'monto_pagado' | 'monto_devolucion'
    >,
    extrasItems: ReservaExtraItem[]
  ): Promise<Reserva> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const client = await getPgPool().connect();
      try {
        await client.query('BEGIN');
        const res = await client.query(
          `INSERT INTO reservas
            (cancha_id, cliente_nombre, cliente_dni, cliente_telefono, cliente_email,
             fecha, hora_inicio, hora_fin, subtotal_cancha, subtotal_extras, total,
             monto_pagado, monto_devolucion, estado, codigo_qr, notas, expires_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,0,0,$12,$13,$14,$15)
           RETURNING id`,
          [
            data.cancha_id,
            data.cliente_nombre,
            data.cliente_dni,
            data.cliente_telefono,
            data.cliente_email,
            data.fecha,
            data.hora_inicio,
            data.hora_fin,
            data.subtotal_cancha,
            data.subtotal_extras,
            data.total,
            data.estado,
            data.codigo_qr,
            data.notas,
            data.expires_at,
          ]
        );
        const newId = Number(res.rows[0].id);
        for (const item of extrasItems) {
          await client.query(
            `INSERT INTO reserva_extras (reserva_id, extra_id, cantidad, precio_unitario, subtotal)
             VALUES ($1, $2, $3, $4, $5)`,
            [newId, item.extra_id, item.cantidad, item.precio_unitario, item.subtotal]
          );
        }
        await client.query('COMMIT');
        return (await this.getReservaById(newId))!;
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    }

    if (mode === 'SUPABASE_REST') {
      const { data: inserted, error } = await getSupabaseClient()
        .from('reservas')
        .insert({
          cancha_id: data.cancha_id,
          cliente_nombre: data.cliente_nombre,
          cliente_dni: data.cliente_dni,
          cliente_telefono: data.cliente_telefono,
          cliente_email: data.cliente_email,
          fecha: data.fecha,
          hora_inicio: data.hora_inicio,
          hora_fin: data.hora_fin,
          subtotal_cancha: data.subtotal_cancha,
          subtotal_extras: data.subtotal_extras,
          total: data.total,
          monto_pagado: 0,
          monto_devolucion: 0,
          estado: data.estado,
          codigo_qr: data.codigo_qr,
          notas: data.notas,
          expires_at: data.expires_at,
        })
        .select('id')
        .single();
      if (error) throw error;
      const newId = Number(inserted.id);
      if (extrasItems.length > 0) {
        const rows = extrasItems.map((it) => ({
          reserva_id: newId,
          extra_id: it.extra_id,
          cantidad: it.cantidad,
          precio_unitario: it.precio_unitario,
          subtotal: it.subtotal,
        }));
        const { error: exErr } = await getSupabaseClient().from('reserva_extras').insert(rows);
        if (exErr) throw exErr;
      }
      return (await this.getReservaById(newId))!;
    }

    const nextId =
      this.memState.reservas.reduce((max, r) => Math.max(max, r.id), 0) + 1;
    const nowIso = new Date().toISOString();
    const newReserva: Reserva = {
      id: nextId,
      ...data,
      monto_pagado: 0,
      monto_devolucion: 0,
      created_at: nowIso,
      updated_at: nowIso,
    };
    this.memState.reservas.push(newReserva);
    for (const item of extrasItems) {
      const nextReId =
        this.memState.reserva_extras.reduce((max, re) => Math.max(max, re.id || 0), 0) + 1;
      this.memState.reserva_extras.push({
        id: nextReId,
        reserva_id: nextId,
        extra_id: item.extra_id,
        cantidad: item.cantidad,
        precio_unitario: item.precio_unitario,
        subtotal: item.subtotal,
      });
    }
    this.saveLocalState();
    return (await this.getReservaById(nextId))!;
  }

  async updateReserva(
    id: number,
    updates: Partial<
      Pick<
        Reserva,
        | 'cliente_nombre'
        | 'cliente_telefono'
        | 'cliente_email'
        | 'notas'
        | 'estado'
        | 'monto_pagado'
        | 'monto_devolucion'
        | 'codigo_qr'
        | 'qr_usado_at'
        | 'motivo_cancelacion'
        | 'expires_at'
      >
    >
  ): Promise<Reserva | null> {
    const existing = await this.getReservaById(id);
    if (!existing) return null;
    const merged = {
      ...existing,
      ...updates,
      updated_at: new Date().toISOString(),
    };
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      await getPgPool().query(
        `UPDATE reservas
         SET cliente_nombre = $1, cliente_telefono = $2, cliente_email = $3,
             notas = $4, estado = $5, monto_pagado = $6, monto_devolucion = $7,
             codigo_qr = $8, motivo_cancelacion = $9, expires_at = $10, updated_at = NOW()
         WHERE id = $11`,
        [
          merged.cliente_nombre,
          merged.cliente_telefono,
          merged.cliente_email,
          merged.notas,
          merged.estado,
          merged.monto_pagado,
          merged.monto_devolucion,
          merged.codigo_qr,
          merged.motivo_cancelacion,
          merged.expires_at,
          id,
        ]
      );
      return this.getReservaById(id);
    }
    if (mode === 'SUPABASE_REST') {
      const { error } = await getSupabaseClient()
        .from('reservas')
        .update({
          cliente_nombre: merged.cliente_nombre,
          cliente_telefono: merged.cliente_telefono,
          cliente_email: merged.cliente_email,
          notas: merged.notas,
          estado: merged.estado,
          monto_pagado: merged.monto_pagado,
          monto_devolucion: merged.monto_devolucion,
          codigo_qr: merged.codigo_qr,
          motivo_cancelacion: merged.motivo_cancelacion,
          expires_at: merged.expires_at,
          updated_at: merged.updated_at,
        })
        .eq('id', id);
      if (error) throw error;
      return this.getReservaById(id);
    }

    const idx = this.memState.reservas.findIndex((r) => r.id === id);
    if (idx === -1) return null;
    this.memState.reservas[idx] = merged;
    this.saveLocalState();
    return this.getReservaById(id);
  }

  async deleteReserva(id: number): Promise<boolean> {
    const existing = await this.getReservaById(id);
    if (!existing) return false;
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      await getPgPool().query('DELETE FROM reservas WHERE id = $1', [id]);
      return true;
    }
    if (mode === 'SUPABASE_REST') {
      const { error } = await getSupabaseClient().from('reservas').delete().eq('id', id);
      if (error) throw error;
      return true;
    }
    this.memState.reservas = this.memState.reservas.filter((r) => r.id !== id);
    this.memState.reserva_extras = this.memState.reserva_extras.filter(
      (re) => re.reserva_id !== id
    );
    this.memState.pagos = this.memState.pagos.filter((p) => p.reserva_id !== id);
    this.saveLocalState();
    return true;
  }

  // ==========================================================================
  // PAGOS Y COMPROBANTES
  // ==========================================================================
  async createPago(
    input: Omit<Pago, 'id' | 'created_at' | 'reviewed_at'>
  ): Promise<Pago> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `INSERT INTO pagos
          (reserva_id, metodo, modalidad, monto, numero_operacion, comprobante_url, estado, observacion)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          input.reserva_id,
          input.metodo,
          input.modalidad,
          input.monto,
          input.numero_operacion,
          input.comprobante_url,
          input.estado,
          input.observacion,
        ]
      );
      return this.normalizePago(res.rows[0]);
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('pagos')
        .insert({
          reserva_id: input.reserva_id,
          metodo: input.metodo,
          modalidad: input.modalidad,
          monto: input.monto,
          numero_operacion: input.numero_operacion,
          comprobante_url: input.comprobante_url,
          estado: input.estado,
          observacion: input.observacion,
        })
        .select('*')
        .single();
      if (error) throw error;
      return this.normalizePago(data);
    }
    const nextId =
      this.memState.pagos.reduce((max, p) => Math.max(max, p.id), 0) + 1;
    const pago: Pago = {
      id: nextId,
      ...input,
      created_at: new Date().toISOString(),
      reviewed_at: null,
    };
    this.memState.pagos.push(pago);
    this.saveLocalState();
    return pago;
  }

  async getPagoById(id: number): Promise<Pago | null> {
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query('SELECT * FROM pagos WHERE id = $1', [id]);
      return res.rows[0] ? this.normalizePago(res.rows[0]) : null;
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('pagos')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      return data ? this.normalizePago(data) : null;
    }
    return this.memState.pagos.find((p) => p.id === id) || null;
  }

  async updatePagoEstado(
    id: number,
    estado: EstadoPago,
    observacion?: string | null
  ): Promise<Pago | null> {
    const existing = await this.getPagoById(id);
    if (!existing) return null;
    const nowIso = new Date().toISOString();
    const mode = getDbMode();
    if (mode === 'POSTGRES_POOL') {
      const res = await getPgPool().query(
        `UPDATE pagos
         SET estado = $1, observacion = COALESCE($2, observacion), reviewed_at = NOW()
         WHERE id = $3
         RETURNING *`,
        [estado, observacion ?? null, id]
      );
      return res.rows[0] ? this.normalizePago(res.rows[0]) : null;
    }
    if (mode === 'SUPABASE_REST') {
      const { data, error } = await getSupabaseClient()
        .from('pagos')
        .update({
          estado,
          observacion: observacion ?? existing.observacion,
          reviewed_at: nowIso,
        })
        .eq('id', id)
        .select('*')
        .single();
      if (error) throw error;
      return this.normalizePago(data);
    }
    const idx = this.memState.pagos.findIndex((p) => p.id === id);
    this.memState.pagos[idx] = {
      ...existing,
      estado,
      observacion: observacion ?? existing.observacion,
      reviewed_at: nowIso,
    };
    this.saveLocalState();
    return this.memState.pagos[idx];
  }
}

export const dataRepository = new DataRepository();
