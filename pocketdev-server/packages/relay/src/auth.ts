import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import { nanoid } from 'nanoid';
import bcrypt from 'bcryptjs';
import * as db from './db.js';

const JWT_SECRET = process.env.JWT_SECRET ?? 'devbox-relay-dev-secret';
if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required in production');
}

// --- Types ---

export interface DeviceTokenPayload {
  sub: string;       // device id
  role: 'daemon';
  iat?: number;
}

export interface AppTokenPayload {
  sub: string;       // app client id
  deviceId: string;
  role: 'app';
  iat?: number;
}

export type TokenPayload = DeviceTokenPayload | AppTokenPayload;

// --- JWT ---

export function signToken(payload: Omit<TokenPayload, 'iat'>): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '365d' });
}

export function verifyToken(token: string): TokenPayload | null {
  try {
    return jwt.verify(token, JWT_SECRET) as TokenPayload;
  } catch {
    return null;
  }
}

// --- Pair code generation ---

function generatePairCode(): string {
  return crypto.randomInt(100_000, 999_999).toString();
}

// --- Device registration ---

export interface RegisterResult {
  deviceId: string;
  token: string;
  pairCode: string;
}

export async function registerDevice(hostname: string, os?: string): Promise<RegisterResult> {
  const deviceId = nanoid(16);
  const tokenPayload: Omit<DeviceTokenPayload, 'iat'> = { sub: deviceId, role: 'daemon' };
  const token = signToken(tokenPayload);

  await db.createDevice(deviceId, hostname, os ?? null, token);

  const pairCode = generatePairCode();
  await db.setPairCode(deviceId, pairCode, 10);

  console.log(`[auth] device registered: ${deviceId} (${hostname}), pair code: ${pairCode}`);
  return { deviceId, token, pairCode };
}

// --- Refresh pair code ---

export async function refreshPairCode(deviceId: string): Promise<string> {
  const code = generatePairCode();
  await db.setPairCode(deviceId, code, 10);
  console.log(`[auth] pair code refreshed for ${deviceId}: ${code}`);
  return code;
}

// --- Pairing flow ---

export interface PairResult {
  clientId: string;
  token: string;
  deviceId: string;
  hostname: string;
}

export async function pairWithCode(pairCode: string, clientName?: string, userId?: string): Promise<PairResult | null> {
  // Atomic claim prevents race condition where two apps pair with same code
  const device = await db.atomicClaimPairCode(pairCode);
  if (!device) return null;

  const clientId = nanoid(16);
  const tokenPayload: Omit<AppTokenPayload, 'iat'> = {
    sub: clientId,
    deviceId: device.id,
    role: 'app',
  };
  const token = signToken(tokenPayload);

  await db.createAppClient(clientId, device.id, token, clientName ?? null, userId ?? null);

  console.log(`[auth] app ${clientId} paired to device ${device.id}${userId ? ` (user ${userId})` : ''}`);
  return { clientId, token, deviceId: device.id, hostname: device.hostname };
}

// --- Auth middleware helpers ---

export async function authenticateDaemon(token: string): Promise<{ deviceId: string } | null> {
  const payload = verifyToken(token);
  if (!payload || payload.role !== 'daemon') return null;

  const device = await db.getDeviceByToken(token);
  if (!device) return null;

  await db.touchDevice(device.id);
  return { deviceId: device.id };
}

// --- User auth ---

export interface UserTokenPayload {
  sub: string;       // user id
  email: string;
  role: 'user';
  iat?: number;
}

export async function registerUser(email: string, password: string, name?: string): Promise<{ userId: string; token: string } | null> {
  const existing = await db.getUserByEmail(email.toLowerCase().trim());
  if (existing) return null;

  const userId = nanoid(16);
  const passwordHash = await bcrypt.hash(password, 12);
  await db.createUser(userId, email.toLowerCase().trim(), passwordHash, name ?? null);

  const token = signToken({ sub: userId, email: email.toLowerCase().trim(), role: 'user' as const });
  console.log(`[auth] user registered: ${userId} (${email})`);
  return { userId, token };
}

export async function loginUser(email: string, password: string): Promise<{ userId: string; token: string } | null> {
  const user = await db.getUserByEmail(email.toLowerCase().trim());
  if (!user) return null;

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) return null;

  const token = signToken({ sub: user.id, email: user.email, role: 'user' as const });
  console.log(`[auth] user logged in: ${user.id} (${email})`);
  return { userId: user.id, token };
}

export async function authenticateUser(token: string): Promise<{ userId: string; email: string } | null> {
  const payload = verifyToken(token);
  if (!payload || (payload as any).role !== 'user') return null;
  const user = await db.getUserById(payload.sub);
  if (!user) return null;
  return { userId: user.id, email: user.email };
}

export async function authenticateApp(token: string): Promise<{ clientId: string; deviceId: string } | null> {
  const payload = verifyToken(token);
  if (!payload || payload.role !== 'app') return null;

  const client = await db.getAppClientByToken(token);
  if (!client) return null;

  await db.touchAppClient(client.id);
  return { clientId: client.id, deviceId: client.device_id };
}
