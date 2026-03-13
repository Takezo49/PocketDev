import http from 'node:http';
import { initDb } from './db.js';
import { createRelayServer, getStats, shutdown as shutdownRelay } from './relay.js';
import * as auth from './auth.js';

const PORT = parseInt(process.env.PORT ?? '3000', 10);
const MAX_BODY_SIZE = 64 * 1024; // 64KB max request body

// --- Rate limiting (in-memory, per IP) ---
const rateLimits = new Map<string, { count: number; resetAt: number }>();

function isRateLimited(ip: string, maxAttempts = 5, windowMs = 60_000): boolean {
  const now = Date.now();
  const entry = rateLimits.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimits.set(ip, { count: 1, resetAt: now + windowMs });
    return false;
  }
  entry.count++;
  return entry.count > maxAttempts;
}

// Cleanup stale rate limit entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimits) {
    if (now > entry.resetAt) rateLimits.delete(ip);
  }
}, 300_000);

// --- HTTP request handler ---

async function handleRequest(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
  const method = req.method ?? 'GET';

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // --- Routes ---

  // Health check
  if (method === 'GET' && url.pathname === '/health') {
    json(res, 200, { status: 'ok', ...getStats() });
    return;
  }

  // --- User auth routes ---

  if (method === 'POST' && url.pathname === '/api/auth/register') {
    const body = await readBody(req);
    const { email, password, name } = body;
    if (!email || !password) {
      json(res, 400, { error: 'email and password required' });
      return;
    }
    if (typeof password !== 'string' || password.length < 6) {
      json(res, 400, { error: 'password must be at least 6 characters' });
      return;
    }
    const result = await auth.registerUser(email as string, password as string, name as string | undefined);
    if (!result) {
      json(res, 409, { error: 'email already registered' });
      return;
    }
    json(res, 201, result);
    return;
  }

  if (method === 'POST' && url.pathname === '/api/auth/login') {
    const clientIp = req.socket.remoteAddress ?? 'unknown';
    if (isRateLimited(clientIp, 10, 60_000)) {
      json(res, 429, { error: 'too many attempts' });
      return;
    }
    const body = await readBody(req);
    const { email, password } = body;
    if (!email || !password) {
      json(res, 400, { error: 'email and password required' });
      return;
    }
    const result = await auth.loginUser(email as string, password as string);
    if (!result) {
      json(res, 401, { error: 'invalid email or password' });
      return;
    }
    json(res, 200, result);
    return;
  }

  if (method === 'GET' && url.pathname === '/api/auth/me') {
    const token = extractBearerToken(req);
    if (!token) {
      json(res, 401, { error: 'unauthorized' });
      return;
    }
    const user = await auth.authenticateUser(token);
    if (!user) {
      json(res, 403, { error: 'invalid token' });
      return;
    }
    const devices = await (await import('./db.js')).getUserDevices(user.userId);
    json(res, 200, { ...user, devices });
    return;
  }

  // Device registration: daemon calls this to register itself
  if (method === 'POST' && url.pathname === '/api/devices/register') {
    const body = await readBody(req);
    const { hostname, os } = body;
    if (!hostname) {
      json(res, 400, { error: 'hostname required' });
      return;
    }
    const result = await auth.registerDevice(hostname, os);
    json(res, 201, result);
    return;
  }

  // Refresh pair code: daemon requests a new 6-digit code
  if (method === 'POST' && url.pathname === '/api/devices/pair-code') {
    const token = extractBearerToken(req);
    if (!token) {
      json(res, 401, { error: 'unauthorized' });
      return;
    }
    const device = await auth.authenticateDaemon(token);
    if (!device) {
      json(res, 403, { error: 'invalid token' });
      return;
    }
    const pairCode = await auth.refreshPairCode(device.deviceId);
    json(res, 200, { pairCode });
    return;
  }

  // Pair with code: app submits 6-digit pair code to get linked to device
  if (method === 'POST' && url.pathname === '/api/pair') {
    const clientIp = req.socket.remoteAddress ?? 'unknown';
    if (isRateLimited(clientIp, 5, 60_000)) {
      json(res, 429, { error: 'too many attempts, try again in 1 minute' });
      return;
    }
    const body = await readBody(req);
    const { code, name } = body;
    if (!code) {
      json(res, 400, { error: 'code required' });
      return;
    }
    // If user is authenticated, link pairing to their account
    let userId: string | undefined;
    const userToken = extractBearerToken(req);
    if (userToken) {
      const user = await auth.authenticateUser(userToken);
      if (user) userId = user.userId;
    }
    const result = await auth.pairWithCode(code as string, name as string | undefined, userId);
    if (!result) {
      json(res, 404, { error: 'invalid or expired pair code' });
      return;
    }
    json(res, 200, result);
    return;
  }

  // 404
  json(res, 404, { error: 'not found' });
}

// --- Helpers ---

function json(res: http.ServerResponse, status: number, data: unknown): void {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function extractBearerToken(req: http.IncomingMessage): string | null {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return null;
  return header.slice(7);
}

function readBody(req: http.IncomingMessage): Promise<Record<string, unknown>> {
  return new Promise((resolve) => {
    const chunks: Buffer[] = [];
    let size = 0;
    req.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (size > MAX_BODY_SIZE) {
        req.destroy();
        resolve({});
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString()));
      } catch {
        resolve({});
      }
    });
  });
}

// --- Start ---

async function main(): Promise<void> {
  console.log('[relay] initializing database...');
  await initDb();

  const server = http.createServer((req, res) => {
    handleRequest(req, res).catch((err) => {
      console.error('[relay] request error:', err);
      if (!res.headersSent) {
        json(res, 500, { error: 'internal server error' });
      }
    });
  });

  createRelayServer(server);

  server.listen(PORT, () => {
    console.log(`[relay] listening on port ${PORT}`);
    console.log(`[relay] HTTP  -> http://localhost:${PORT}/health`);
    console.log(`[relay] WS    -> ws://localhost:${PORT}/daemon?token=xxx`);
    console.log(`[relay] WS    -> ws://localhost:${PORT}/app?token=xxx`);
  });

  // Graceful shutdown
  const shutdown = () => {
    console.log('\n[relay] shutting down...');
    shutdownRelay();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 5000);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('[relay] fatal:', err);
  process.exit(1);
});
