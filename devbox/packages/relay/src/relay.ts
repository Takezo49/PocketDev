import { WebSocketServer, WebSocket } from 'ws';
import type { IncomingMessage } from 'node:http';
import type { Server as HttpServer } from 'node:http';
import Redis from 'ioredis';
import { nanoid } from 'nanoid';
import * as auth from './auth.js';
import * as db from './db.js';

// --- Types ---

interface DaemonConnection {
  ws: WebSocket;
  deviceId: string;
}

interface AppConnection {
  ws: WebSocket;
  clientId: string;
  deviceId: string;
}

// --- Relay State ---

// deviceId -> daemon WebSocket
const daemonsByDevice = new Map<string, DaemonConnection>();
// deviceId -> Set of app WebSockets
const appsByDevice = new Map<string, Set<AppConnection>>();

let redis: Redis | null = null;

function getRedis(): Redis {
  if (!redis) {
    redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  }
  return redis;
}

// --- Helpers ---

function send(ws: WebSocket, data: unknown): void {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(typeof data === 'string' ? data : JSON.stringify(data));
  }
}

function sendError(ws: WebSocket, message: string): void {
  send(ws, { type: 'error', message });
}

function parseToken(req: IncomingMessage): string | null {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
  return url.searchParams.get('token');
}

// --- Daemon path: /daemon?token=xxx ---

async function handleDaemonConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
  const token = parseToken(req);
  if (!token) {
    sendError(ws, 'missing token');
    ws.close(4001, 'missing token');
    return;
  }

  const result = await auth.authenticateDaemon(token);
  if (!result) {
    sendError(ws, 'invalid daemon token');
    ws.close(4003, 'unauthorized');
    return;
  }

  const { deviceId } = result;

  // Disconnect existing daemon for this device (only one daemon per device)
  const existing = daemonsByDevice.get(deviceId);
  if (existing && existing.ws.readyState === WebSocket.OPEN) {
    sendError(existing.ws, 'replaced by new daemon connection');
    existing.ws.close(4000, 'replaced');
  }

  const conn: DaemonConnection = { ws, deviceId };
  daemonsByDevice.set(deviceId, conn);

  console.log(`[relay] daemon connected: ${deviceId}`);

  // Notify connected apps that daemon is online
  const apps = appsByDevice.get(deviceId);
  if (apps) {
    for (const app of apps) {
      send(app.ws, { type: 'status', online: true });
    }
  }

  // Track presence in Redis
  await getRedis().set(`device:online:${deviceId}`, '1', 'EX', 300);

  // Forward all daemon messages to paired apps
  ws.on('message', (raw) => {
    const apps = appsByDevice.get(deviceId);
    if (!apps || apps.size === 0) return;

    // Transparent forwarding - raw bytes, no parsing
    const data = typeof raw === 'string' ? raw : raw.toString();
    for (const app of apps) {
      send(app.ws, data);
    }
  });

  ws.on('close', () => {
    console.log(`[relay] daemon disconnected: ${deviceId}`);
    daemonsByDevice.delete(deviceId);
    getRedis().del(`device:online:${deviceId}`).catch(() => {});

    // Notify apps that daemon went offline
    const apps = appsByDevice.get(deviceId);
    if (apps) {
      for (const app of apps) {
        send(app.ws, { type: 'status', online: false });
      }
    }
  });

  ws.on('error', (err) => {
    console.error(`[relay] daemon ws error (${deviceId}):`, err.message);
  });

  // Heartbeat: keep Redis presence alive
  const heartbeat = setInterval(() => {
    if (ws.readyState !== WebSocket.OPEN) {
      clearInterval(heartbeat);
      return;
    }
    getRedis().set(`device:online:${deviceId}`, '1', 'EX', 300).catch(() => {});
  }, 60_000);

  ws.on('close', () => clearInterval(heartbeat));
}

// --- App path: /app?token=xxx ---

async function handleAppConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
  const token = parseToken(req);
  if (!token) {
    sendError(ws, 'missing token');
    ws.close(4001, 'missing token');
    return;
  }

  const result = await auth.authenticateApp(token);
  if (!result) {
    sendError(ws, 'invalid app token');
    ws.close(4003, 'unauthorized');
    return;
  }

  const { clientId, deviceId } = result;
  const conn: AppConnection = { ws, clientId, deviceId };

  // Add to device's app set
  if (!appsByDevice.has(deviceId)) {
    appsByDevice.set(deviceId, new Set());
  }
  appsByDevice.get(deviceId)!.add(conn);

  console.log(`[relay] app connected: ${clientId} -> device ${deviceId}`);

  // Send initial online status
  const daemon = daemonsByDevice.get(deviceId);
  send(ws, { type: 'status', online: daemon?.ws.readyState === WebSocket.OPEN });

  // Forward all app messages to the paired daemon
  ws.on('message', (raw) => {
    const daemon = daemonsByDevice.get(deviceId);
    if (!daemon || daemon.ws.readyState !== WebSocket.OPEN) {
      sendError(ws, 'daemon offline');
      return;
    }

    // Transparent forwarding - raw bytes, no parsing
    const data = typeof raw === 'string' ? raw : raw.toString();
    send(daemon.ws, data);
  });

  ws.on('close', () => {
    console.log(`[relay] app disconnected: ${clientId}`);
    const apps = appsByDevice.get(deviceId);
    if (apps) {
      apps.delete(conn);
      if (apps.size === 0) appsByDevice.delete(deviceId);
    }
  });

  ws.on('error', (err) => {
    console.error(`[relay] app ws error (${clientId}):`, err.message);
  });
}

// --- WebSocket Server ---

export function createRelayServer(server: HttpServer): WebSocketServer {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
    const pathname = url.pathname;

    if (pathname === '/daemon' || pathname === '/app') {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req);
      });
    } else {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
    }
  });

  wss.on('connection', (ws: WebSocket, req: IncomingMessage) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);

    if (url.pathname === '/daemon') {
      handleDaemonConnection(ws, req).catch((err) => {
        console.error('[relay] daemon connection error:', err);
        ws.close(4500, 'internal error');
      });
    } else if (url.pathname === '/app') {
      handleAppConnection(ws, req).catch((err) => {
        console.error('[relay] app connection error:', err);
        ws.close(4500, 'internal error');
      });
    }
  });

  console.log('[relay] WebSocket relay ready (paths: /daemon, /app)');
  return wss;
}

// --- Stats ---

export function getStats() {
  return {
    daemons: daemonsByDevice.size,
    apps: Array.from(appsByDevice.values()).reduce((sum, set) => sum + set.size, 0),
    devices: [...new Set([...daemonsByDevice.keys(), ...appsByDevice.keys()])].length,
  };
}

export async function shutdown(): Promise<void> {
  if (redis) {
    redis.disconnect();
    redis = null;
  }
}
