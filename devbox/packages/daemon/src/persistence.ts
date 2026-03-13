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
