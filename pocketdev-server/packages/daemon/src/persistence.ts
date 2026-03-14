import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

export interface PersistedSession {
  id: string;
  claudeSessionId: string | null;
  cwd: string;
  config: {
    model?: string;
    effort?: string;
    skipPermissions?: boolean;
  };
  cost: number;
  createdAt: number;
}

const DIR = join(homedir(), '.devbox');
const FILE = join(DIR, 'sessions.json');

function ensureDir(): void {
  if (!existsSync(DIR)) {
    mkdirSync(DIR, { recursive: true });
  }
}

export function loadSessions(): PersistedSession[] {
  try {
    ensureDir();
    if (!existsSync(FILE)) return [];
    const data = readFileSync(FILE, 'utf-8');
    return JSON.parse(data);
  } catch {
    return [];
  }
}

export function saveSessions(sessions: PersistedSession[]): void {
  try {
    ensureDir();
    writeFileSync(FILE, JSON.stringify(sessions, null, 2));
  } catch (err) {
    console.error('  [persistence] Failed to save sessions:', err);
  }
}

export function getRecentCwds(): Map<string, number> {
  const sessions = loadSessions();
  const cwdMap = new Map<string, number>();
  for (const s of sessions) {
    if (!s.cwd) continue;
    const existing = cwdMap.get(s.cwd);
    if (!existing || s.createdAt > existing) {
      cwdMap.set(s.cwd, s.createdAt);
    }
  }
  return cwdMap;
}

// --- Saved Workspaces ---

export interface SavedWorkspace {
  path: string;
  name: string;
  lastUsed: number;
}

const WS_FILE = join(DIR, 'workspaces.json');

export function loadWorkspaces(): SavedWorkspace[] {
  try {
    ensureDir();
    if (!existsSync(WS_FILE)) return [];
    return JSON.parse(readFileSync(WS_FILE, 'utf-8'));
  } catch {
    return [];
  }
}

export function saveWorkspace(path: string, name: string): SavedWorkspace[] {
  const workspaces = loadWorkspaces();
  const now = Date.now();
  const idx = workspaces.findIndex(w => w.path === path);
  if (idx >= 0) {
    workspaces[idx] = { path, name, lastUsed: now };
  } else {
    workspaces.unshift({ path, name, lastUsed: now });
  }
  // Cap at 50
  const capped = workspaces.slice(0, 50);
  try {
    ensureDir();
    writeFileSync(WS_FILE, JSON.stringify(capped, null, 2));
  } catch {}
  return capped;
}

export function removeWorkspace(path: string): SavedWorkspace[] {
  let workspaces = loadWorkspaces();
  workspaces = workspaces.filter(w => w.path !== path);
  try {
    ensureDir();
    writeFileSync(WS_FILE, JSON.stringify(workspaces, null, 2));
  } catch {}
  // Also add to exclusion list so scanner doesn't rediscover it
  addExcludedPath(path);
  return workspaces;
}

// --- Excluded Paths (hidden from project list) ---

const EXCLUDED_FILE = join(DIR, 'excluded.json');

export function loadExcludedPaths(): Set<string> {
  try {
    ensureDir();
    if (!existsSync(EXCLUDED_FILE)) return new Set();
    return new Set(JSON.parse(readFileSync(EXCLUDED_FILE, 'utf-8')));
  } catch {
    return new Set();
  }
}

export function addExcludedPath(path: string): void {
  const excluded = loadExcludedPaths();
  excluded.add(path);
  try {
    ensureDir();
    writeFileSync(EXCLUDED_FILE, JSON.stringify([...excluded], null, 2));
  } catch {}
}

export function removeExcludedPath(path: string): void {
  const excluded = loadExcludedPaths();
  excluded.delete(path);
  try {
    ensureDir();
    writeFileSync(EXCLUDED_FILE, JSON.stringify([...excluded], null, 2));
  } catch {}
}
