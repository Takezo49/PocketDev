import { EventEmitter } from 'events';
import { ClaudeSession } from './claude-session.js';
import type { Card, Session } from './types.js';

export class SessionManager extends EventEmitter {
  private sessions = new Map<string, ClaudeSession>();

  createSession(tool: string, cwd?: string): ClaudeSession {
    const resolvedCwd = cwd ?? process.cwd();
    const session = new ClaudeSession(resolvedCwd);

    session.on('card', (card: Card) => {
      this.emit('card', card);
    });

    session.on('status', () => {
      this.emit('session:update', session.toJSON());
    });

    session.on('stream:start', (data) => {
      this.emit('stream:start', data);
    });

    session.on('stream:delta', (data) => {
      this.emit('stream:delta', data);
    });

    session.on('stream:tool_start', (data) => {
      this.emit('stream:tool_start', data);
    });

    session.on('stream:tool_result', (data) => {
      this.emit('stream:tool_result', data);
    });

    session.on('stream:tool_update', (data) => {
      this.emit('stream:tool_update', data);
    });

    session.on('stream:tool_end', (data) => {
      this.emit('stream:tool_end', data);
    });

    session.on('stream:end', (data) => {
      this.emit('stream:end', data);
    });

    this.sessions.set(session.id, session);
    this.emit('session:update', session.toJSON());

    return session;
  }

  getSession(id: string): ClaudeSession | undefined {
    return this.sessions.get(id);
  }

  listSessions(): Session[] {
    return Array.from(this.sessions.values()).map(s => s.toJSON());
  }

  killSession(id: string): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.kill();
    session.removeAllListeners();
    this.sessions.delete(id);
    this.emit('session:update', session.toJSON());
    return true;
  }

  killAll(): void {
    for (const [, session] of this.sessions) {
      session.kill();
      session.removeAllListeners();
    }
    this.sessions.clear();
  }
}
