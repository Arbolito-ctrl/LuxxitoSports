export type DeporteTipo =
  | 'Futbol 5'
  | 'Futbol 7'
  | 'Futbol 11'
  | 'Voley'
  | 'Tenis'
  | 'Padel'
  | 'Basquet';

export type EstadoCancha = 'ACTIVA' | 'MANTENIMIENTO' | 'INACTIVA';

export type EstadoReserva =
  | 'PENDIENTE_PAGO'
  | 'EN_REVISION'
  | 'CONFIRMADA'
  | 'CANCELADA'
  | 'VENCIDA';

export type MetodoPago = 'YAPE' | 'PLIN' | 'TRANSFERENCIA';
export type ModalidadPago = 'SENA_50' | 'TOTAL';
export type EstadoPago = 'PENDIENTE_REVISION' | 'APROBADO' | 'RECHAZADO' | 'REEMBOLSADO';

export interface Complejo {
  id: number;
  nombre: string;
  distrito: string;
  direccion: string;
  telefono: string;
  hora_apertura: number;
  hora_cierre: number;
  imagen_url: string | null;
  activo: boolean;
  created_at?: string;
}

export interface Cancha {
  id: number;
  complejo_id: number;
  complejo_nombre?: string;
  distrito?: string;
  direccion?: string;
  nombre: string;
  deporte: DeporteTipo;
  superficie: string;
  techada: boolean;
  iluminacion: boolean;
  precio_hora_diurno: number;
  precio_hora_nocturno: number;
  estado: EstadoCancha;
  created_at?: string;
}

export interface Extra {
  id: number;
  complejo_id: number;
  nombre: string;
  descripcion: string | null;
  precio_unitario: number;
  stock_total: number;
  stock_disponible?: number;
  activo: boolean;
}

export interface ReservaExtraItem {
  id?: number;
  reserva_id?: number;
  extra_id: number;
  nombre?: string;
  cantidad: number;
  precio_unitario: number;
  subtotal: number;
}

export interface Pago {
  id: number;
  reserva_id: number;
  metodo: MetodoPago;
  modalidad: ModalidadPago;
  monto: number;
  numero_operacion: string;
  comprobante_url: string | null;
  estado: EstadoPago;
  observacion: string | null;
  created_at: string;
  reviewed_at: string | null;
}

export interface Reserva {
  id: number;
  cancha_id: number;
  cancha_nombre?: string;
  deporte?: string;
  complejo_id?: number;
  complejo_nombre?: string;
  distrito?: string;
  cliente_nombre: string;
  cliente_dni: string;
  cliente_telefono: string;
  cliente_email: string;
  fecha: string; // YYYY-MM-DD
  hora_inicio: number; // 0..23
  hora_fin: number; // 1..24
  subtotal_cancha: number;
  subtotal_extras: number;
  total: number;
  monto_pagado: number;
  monto_devolucion: number;
  estado: EstadoReserva;
  codigo_qr: string | null;
  motivo_cancelacion: string | null;
  notas: string | null;
  expires_at: string;
  created_at: string;
  updated_at: string;
  extras?: ReservaExtraItem[];
  pagos?: Pago[];
}

export interface TurnoDisponibilidad {
  hora_inicio: number;
  hora_fin: number;
  etiqueta: string;
  tarifa_tipo: 'DIURNA' | 'NOCTURNA';
  precio: number;
  estado: 'DISPONIBLE' | 'BLOQUEADA' | 'OCUPADA' | 'MANTENIMIENTO' | 'PASADA';
  reserva_id?: number;
}

export interface DisponibilidadResponse {
  cancha: Cancha;
  complejo: Complejo;
  fecha: string;
  horario_operacion: { apertura: number; cierre: number };
  turnos: TurnoDisponibilidad[];
  extras_disponibles: Extra[];
}

export interface CotizacionInput {
  cancha_id: number;
  fecha: string;
  hora_inicio: number;
  hora_fin: number;
  extras?: Array<{ extra_id: number; cantidad: number }>;
}

export interface CotizacionOutput {
  cancha_id: number;
  cancha_nombre: string;
  complejo_nombre: string;
  fecha: string;
  hora_inicio: number;
  hora_fin: number;
  duracion_horas: number;
  subtotal_cancha: number;
  subtotal_extras: number;
  total: number;
  monto_sena_50: number;
  desglose_horas: Array<{
    hora: string;
    tipo: 'DIURNA' | 'NOCTURNA';
    precio: number;
  }>;
  desglose_extras: ReservaExtraItem[];
}
