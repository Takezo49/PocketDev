import pg from 'pg';

const { Pool } = pg;

let pool: pg.Pool;

export function getPool(): pg.Pool {
  if (!pool) {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL ?? 'postgres://devbox:devbox@localhost:5432/devbox',
      max: 20,
    });
  }
  return pool;
}

export async function initDb(): Promise<void> {
  const db = getPool();

  await db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      name TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      hostname TEXT NOT NULL,
      os TEXT,
      token TEXT NOT NULL,
      pair_code TEXT,
      pair_code_expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS app_clients (
      id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
      user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      token TEXT NOT NULL,
      name TEXT,
      paired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
      claude_session_id TEXT,
      cwd TEXT,
      model TEXT,
      effort TEXT,
      total_cost NUMERIC DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      payload JSONB NOT NULL DEFAULT '{}',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_app_clients_device_id ON app_clients(device_id);
    CREATE INDEX IF NOT EXISTS idx_sessions_device_id ON sessions(device_id);
    CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
    CREATE INDEX IF NOT EXISTS idx_devices_pair_code ON devices(pair_code);
  `);

  console.log('[db] tables initialized');
}

// --- Device queries ---

export async function createDevice(id: string, hostname: string, os: string | null, token: string): Promise<void> {
  await getPool().query(
    `INSERT INTO devices (id, hostname, os, token)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (id) DO UPDATE SET hostname = $2, os = $3, token = $4, last_seen = NOW()`,
    [id, hostname, os, token],
  );
}

export async function getDeviceByToken(token: string) {
  const { rows } = await getPool().query('SELECT * FROM devices WHERE token = $1', [token]);
  return rows[0] ?? null;
}

export async function getDeviceById(id: string) {
  const { rows } = await getPool().query('SELECT * FROM devices WHERE id = $1', [id]);
  return rows[0] ?? null;
}

export async function getDeviceByPairCode(code: string) {
  const { rows } = await getPool().query(
    `SELECT * FROM devices WHERE pair_code = $1 AND pair_code_expires_at > NOW()`,
    [code],
  );
  return rows[0] ?? null;
}

export async function setPairCode(deviceId: string, code: string, expiresMinutes: number = 10): Promise<void> {
  await getPool().query(
    `UPDATE devices SET pair_code = $1, pair_code_expires_at = NOW() + INTERVAL '1 minute' * $2 WHERE id = $3`,
    [code, expiresMinutes, deviceId],
  );
}

export async function clearPairCode(deviceId: string): Promise<void> {
  await getPool().query(
    `UPDATE devices SET pair_code = NULL, pair_code_expires_at = NULL WHERE id = $1`,
    [deviceId],
  );
}

/** Atomically claim a pair code — returns device row or null if code invalid/already used */
export async function atomicClaimPairCode(code: string): Promise<any> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT * FROM devices WHERE pair_code = $1 AND pair_code_expires_at > NOW() FOR UPDATE`,
      [code],
    );
    if (rows.length === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    await client.query(
      `UPDATE devices SET pair_code = NULL, pair_code_expires_at = NULL WHERE id = $1`,
      [rows[0].id],
    );
    await client.query('COMMIT');
    return rows[0];
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

export async function touchDevice(deviceId: string): Promise<void> {
  await getPool().query('UPDATE devices SET last_seen = NOW() WHERE id = $1', [deviceId]);
}

// --- App client queries ---

export async function createAppClient(id: string, deviceId: string, token: string, name: string | null, userId: string | null = null): Promise<void> {
  await getPool().query(
    `INSERT INTO app_clients (id, device_id, token, name, user_id) VALUES ($1, $2, $3, $4, $5)`,
    [id, deviceId, token, name, userId],
  );
}

export async function getAppClientByToken(token: string) {
  const { rows } = await getPool().query('SELECT * FROM app_clients WHERE token = $1', [token]);
  return rows[0] ?? null;
}

export async function touchAppClient(clientId: string): Promise<void> {
  await getPool().query('UPDATE app_clients SET last_seen = NOW() WHERE id = $1', [clientId]);
}

// --- Session queries ---

export async function createSession(
  id: string, deviceId: string, claudeSessionId: string | null,
  cwd: string | null, model: string | null, effort: string | null,
): Promise<void> {
  await getPool().query(
    `INSERT INTO sessions (id, device_id, claude_session_id, cwd, model, effort) VALUES ($1, $2, $3, $4, $5, $6)`,
    [id, deviceId, claudeSessionId, cwd, model, effort],
  );
}

export async function updateSessionCost(sessionId: string, cost: number): Promise<void> {
  await getPool().query(
    `UPDATE sessions SET total_cost = total_cost + $1 WHERE id = $2`,
    [cost, sessionId],
  );
}

// --- Message queries ---

export async function createMessage(id: string, sessionId: string, type: string, payload: unknown): Promise<void> {
  await getPool().query(
    `INSERT INTO messages (id, session_id, type, payload) VALUES ($1, $2, $3, $4)`,
    [id, sessionId, type, JSON.stringify(payload)],
  );
}

export async function getSessionMessages(sessionId: string, limit: number = 100) {
  const { rows } = await getPool().query(
    'SELECT * FROM messages WHERE session_id = $1 ORDER BY created_at ASC LIMIT $2',
    [sessionId, limit],
  );
  return rows;
}

// --- User queries ---

export async function createUser(id: string, email: string, passwordHash: string, name: string | null): Promise<void> {
  await getPool().query(
    `INSERT INTO users (id, email, password_hash, name) VALUES ($1, $2, $3, $4)`,
    [id, email, passwordHash, name],
  );
}

export async function getUserByEmail(email: string) {
  const { rows } = await getPool().query('SELECT * FROM users WHERE email = $1', [email]);
  return rows[0] ?? null;
}

export async function getUserById(id: string) {
  const { rows } = await getPool().query('SELECT * FROM users WHERE id = $1', [id]);
  return rows[0] ?? null;
}

export async function getUserDevices(userId: string) {
  const { rows } = await getPool().query(
    `SELECT d.id, d.hostname, d.os, d.last_seen, ac.id as client_id, ac.token as app_token
     FROM app_clients ac JOIN devices d ON ac.device_id = d.id
     WHERE ac.user_id = $1 ORDER BY ac.paired_at DESC`,
    [userId],
  );
  return rows;
}
