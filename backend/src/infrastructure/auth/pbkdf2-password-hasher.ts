import type { PasswordHasher } from '../../application/ports/password-hasher';

const DEFAULT_ITERATIONS = 100_000;
const KEY_LENGTH = 32;
const SALT_LENGTH = 16;
const SCHEME = 'pbkdf2-sha256';

export class Pbkdf2PasswordHasher implements PasswordHasher {
  constructor(private readonly iterations: number = DEFAULT_ITERATIONS) {}

  async hash(password: string): Promise<string> {
    const salt = crypto.getRandomValues(new Uint8Array(SALT_LENGTH));
    const derived = await derive(password, salt, this.iterations);
    return `${SCHEME}$${this.iterations}$${toHex(salt)}$${toHex(derived)}`;
  }

  async verify(password: string, encoded: string): Promise<boolean> {
    const [scheme, iterStr, saltHex, hashHex] = encoded.split('$');
    if (scheme !== SCHEME || !iterStr || !saltHex || !hashHex) return false;
    const iterations = Number(iterStr);
    if (!Number.isFinite(iterations) || iterations < 1) return false;
    const salt = fromHex(saltHex);
    const expected = fromHex(hashHex);
    const derived = await derive(password, salt, iterations);
    return timingSafeEqual(derived, expected);
  }
}

async function derive(
  password: string,
  salt: Uint8Array,
  iterations: number,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    key,
    KEY_LENGTH * 8,
  );
  return new Uint8Array(bits);
}

function toHex(buf: Uint8Array): string {
  let out = '';
  for (const b of buf) out += b.toString(16).padStart(2, '0');
  return out;
}

function fromHex(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}
