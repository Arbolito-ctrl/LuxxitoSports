import { Request, Response, NextFunction } from 'express';
import { getDbMode, getPgPool, getSupabaseClient } from '../config/database';
import { signJwtToken } from '../middlewares/authMiddleware';
import { Errors } from '../utils/errors';

interface UsuarioRecord {
  id: number;
  nombre: string;
  dni: string;
  telefono: string;
  email: string;
  password_hash: string;
  rol: 'JUGADOR' | 'ADMIN';
}

const memUsers: UsuarioRecord[] = [
  {
    id: 1,
    nombre: 'Elvis Arboleda',
    dni: '74125896',
    telefono: '987654321',
    email: 'elvis.arboleda@uni.pe',
    password_hash: 'luxxito2026',
    rol: 'JUGADOR',
  },
  {
    id: 2,
    nombre: 'Admin Luxxito Sports',
    dni: '70001111',
    telefono: '999888777',
    email: 'admin@luxxitosports.pe',
    password_hash: 'admin2026',
    rol: 'ADMIN',
  },
];

export class AuthController {
  async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const email = String(req.body?.email || '').trim().toLowerCase();
      const password = String(req.body?.password || '').trim();

      if (!email || !password) {
        throw Errors.badRequest('Debes ingresar tu correo electrónico y contraseña.');
      }

      const mode = getDbMode();
      let found: UsuarioRecord | null = null;

      if (mode === 'POSTGRES_POOL') {
        const q = await getPgPool().query(
          'SELECT * FROM usuarios WHERE LOWER(email) = $1 LIMIT 1',
          [email]
        );
        found = q.rows[0] || null;
      } else if (mode === 'SUPABASE_REST') {
        const { data } = await getSupabaseClient()
          .from('usuarios')
          .select('*')
          .ilike('email', email)
          .maybeSingle();
        found = (data as UsuarioRecord) || null;
      } else {
        found = memUsers.find((u) => u.email.toLowerCase() === email) || null;
      }

      if (!found || found.password_hash !== password) {
        res.status(401).json({
          ok: false,
          code: 'INVALID_CREDENTIALS',
          message: 'Correo o contraseña incorrectos.',
        });
        return;
      }

      const { password_hash: _, ...safeUser } = found;
      const token = signJwtToken({
        ...safeUser,
        id: Number(safeUser.id),
      });

      res.status(200).json({
        ok: true,
        message: 'Inicio de sesión exitoso.',
        data: {
          user: {
            ...safeUser,
            id: Number(safeUser.id),
          },
          token,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  async registro(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const nombre = String(req.body?.nombre || '').trim();
      const dni = String(req.body?.dni || '').trim();
      const telefono = String(req.body?.telefono || '').trim();
      const email = String(req.body?.email || '').trim().toLowerCase();
      const password = String(req.body?.password || '').trim();

      if (nombre.length < 3) {
        throw Errors.badRequest('El nombre debe tener al menos 3 caracteres.');
      }
      if (!/^\d{8}$/.test(dni)) {
        throw Errors.badRequest('El DNI debe tener exactamente 8 dígitos numéricos.');
      }
      if (telefono.length < 7) {
        throw Errors.badRequest('El teléfono es obligatorio.');
      }
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw Errors.badRequest('El correo electrónico no tiene un formato válido.');
      }
      if (password.length < 4) {
        throw Errors.badRequest('La contraseña debe tener al menos 4 caracteres.');
      }

      const mode = getDbMode();
      let createdUser: Omit<UsuarioRecord, 'password_hash'>;

      if (mode === 'POSTGRES_POOL') {
        const exists = await getPgPool().query(
          'SELECT id FROM usuarios WHERE LOWER(email) = $1 OR dni = $2 LIMIT 1',
          [email, dni]
        );
        if (exists.rows.length > 0) {
          throw Errors.conflict('Ya existe una cuenta registrada con ese correo o DNI.');
        }
        const ins = await getPgPool().query(
          `INSERT INTO usuarios (nombre, dni, telefono, email, password_hash, rol)
           VALUES ($1, $2, $3, $4, $5, 'JUGADOR')
           RETURNING id, nombre, dni, telefono, email, rol`,
          [nombre, dni, telefono, email, password]
        );
        createdUser = { ...ins.rows[0], id: Number(ins.rows[0].id) };
      } else if (mode === 'SUPABASE_REST') {
        const { data: existing } = await getSupabaseClient()
          .from('usuarios')
          .select('id')
          .or(`email.ilike.${email},dni.eq.${dni}`)
          .maybeSingle();
        if (existing) {
          throw Errors.conflict('Ya existe una cuenta registrada con ese correo o DNI.');
        }
        const { data, error } = await getSupabaseClient()
          .from('usuarios')
          .insert({
            nombre,
            dni,
            telefono,
            email,
            password_hash: password,
            rol: 'JUGADOR',
          })
          .select('id, nombre, dni, telefono, email, rol')
          .single();
        if (error) throw error;
        createdUser = { ...(data as any), id: Number(data.id) };
      } else {
        const dup = memUsers.find(
          (u) => u.email.toLowerCase() === email || u.dni === dni
        );
        if (dup) {
          throw Errors.conflict('Ya existe una cuenta registrada con ese correo o DNI.');
        }
        const nextId = memUsers.length + 1;
        const nuevo: UsuarioRecord = {
          id: nextId,
          nombre,
          dni,
          telefono,
          email,
          password_hash: password,
          rol: 'JUGADOR',
        };
        memUsers.push(nuevo);
        const { password_hash: _, ...rest } = nuevo;
        createdUser = rest;
      }

      const token = signJwtToken(createdUser);
      res.status(201).json({
        ok: true,
        message: 'Cuenta creada exitosamente.',
        data: {
          user: createdUser,
          token,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  async recuperarAcceso(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const email = String(req.body?.email || '').trim().toLowerCase();
      if (!email || !email.includes('@')) {
        throw Errors.badRequest('Ingresa un correo electrónico válido para recuperar tu cuenta.');
      }
      res.status(200).json({
        ok: true,
        message: `Se han enviado las instrucciones de recuperación de contraseña a ${email}.`,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const authController = new AuthController();
