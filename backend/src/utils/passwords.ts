import crypto from 'crypto';

/**
 * Contraseñas con hash scrypt (incluido en Node) y sal aleatoria por usuario.
 * Formato guardado en usuarios.password_hash: "scrypt$<sal hex>$<hash hex>".
 */
const PREFIJO = 'scrypt$';
const LARGO_HASH = 64;

export function hashPassword(password: string): string {
  const sal = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, sal, LARGO_HASH);
  return `${PREFIJO}${sal.toString('hex')}$${hash.toString('hex')}`;
}

export function esHash(valor: string): boolean {
  return valor.startsWith(PREFIJO);
}

/**
 * Compara en tiempo constante. Acepta valores antiguos en texto plano (anteriores
 * a esta versión) para que esos usuarios puedan entrar y se les migre el hash.
 */
export function verificarPassword(password: string, guardado: string): boolean {
  if (!esHash(guardado)) {
    const a = Buffer.from(password);
    const b = Buffer.from(guardado);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  }
  const [, salHex, hashHex] = guardado.split('$');
  const esperado = Buffer.from(hashHex, 'hex');
  const calculado = crypto.scryptSync(password, Buffer.from(salHex, 'hex'), esperado.length);
  return crypto.timingSafeEqual(calculado, esperado);
}
