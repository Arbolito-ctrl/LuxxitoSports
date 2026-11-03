import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';

export interface JwtUserPayload {
  sub: number;
  email: string;
  dni: string;
  rol: 'JUGADOR' | 'ADMIN';
  iat?: number;
  exp?: number;
}

/** La app guarda la sesión en el celular: el token debe vencer. */
const DIAS_VIGENCIA_TOKEN = Number(process.env.JWT_DIAS_VIGENCIA) || 30;

declare global {
  namespace Express {
    interface Request {
      user?: JwtUserPayload;
    }
  }
}

export function getJwtSecret(): string {
  return process.env.JWT_SECRET || 'luxxito_sports_uni_si806_secret_key_2026';
}

export function signJwtToken(user: {
  id: number;
  email: string;
  dni: string;
  rol: 'JUGADOR' | 'ADMIN';
}): string {
  const secret = getJwtSecret();
  const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
  const payload = Buffer.from(
    JSON.stringify({
      sub: user.id,
      email: user.email,
      dni: user.dni,
      rol: user.rol,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + DIAS_VIGENCIA_TOKEN * 24 * 60 * 60,
    })
  ).toString('base64url');

  // Soportar firma sobre payload o header.payload
  const sig = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('base64url');
  return `${header}.${payload}.${sig}`;
}

export function verifyJwtToken(token: string): JwtUserPayload | null {
  try {
    const parts = token.trim().split('.');
    if (parts.length !== 3) return null;
    const [header, payload, signature] = parts;
    if (!header || !payload || !signature) return null;

    const secret = getJwtSecret();
    const expectedPayloadSig = crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('base64url');
    const expectedStandardSig = crypto
      .createHmac('sha256', secret)
      .update(`${header}.${payload}`)
      .digest('base64url');

    if (signature !== expectedPayloadSig && signature !== expectedStandardSig) {
      return null;
    }

    const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (
      !decoded ||
      typeof decoded.sub !== 'number' ||
      (decoded.rol !== 'JUGADOR' && decoded.rol !== 'ADMIN')
    ) {
      return null;
    }
    // Tokens vencidos o emitidos sin vencimiento (versiones anteriores) ya no son válidos
    if (typeof decoded.exp !== 'number' || decoded.exp <= Math.floor(Date.now() / 1000)) {
      return null;
    }
    return decoded as JwtUserPayload;
  } catch {
    return null;
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      ok: false,
      code: 'UNAUTHORIZED',
      message: 'Autenticación requerida. Envía un token válido en Authorization: Bearer <token>.',
    });
    return;
  }

  const token = authHeader.slice('Bearer '.length).trim();
  const payload = verifyJwtToken(token);
  if (!payload) {
    res.status(401).json({
      ok: false,
      code: 'UNAUTHORIZED',
      message: 'Token de autenticación inválido o expirado.',
    });
    return;
  }

  req.user = payload;
  next();
}

export function requireRole(...roles: Array<'JUGADOR' | 'ADMIN'>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        ok: false,
        code: 'UNAUTHORIZED',
        message: 'Autenticación requerida.',
      });
      return;
    }
    if (!roles.includes(req.user.rol)) {
      res.status(403).json({
        ok: false,
        code: 'FORBIDDEN',
        message: `Acceso restringido: esta operación requiere rol ${roles.join(' o ')}.`,
      });
      return;
    }
    next();
  };
}

