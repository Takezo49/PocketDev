import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';
import { PairingManager } from './pairing.js';
import { SessionManager } from './session-manager.js';
import { ProjectScanner } from './projects.js';
import { Dashboard } from './dashboard.js';
import { getRecentCwds, loadWorkspaces, saveWorkspace, removeWorkspace, loadExcludedPaths, removeExcludedPath } from './persistence.js';
import type { DaemonMessage, MobileMessage, Card, Session, UsageInfo } from './types.js';
import os from 'os';
import { basename, resolve } from 'path';

interface Client {
  ws: WebSocket;
  paired: boolean;
  deviceId?: string;
}

export class DevBoxServer extends EventEmitter {
  private wss: WebSocketServer | null = null;
  private clients = new Map<string, Client>();
  private pairing: PairingManager;
  private sessions: SessionManager;
  private projectScanner: ProjectScanner;
  private dashboard: Dashboard;
  private clientCounter = 0;

  constructor() {
    super();
    this.pairing = new PairingManager();
    this.sessions = new SessionManager();
    this.projectScanner = new ProjectScanner();
    this.dashboard = new Dashboard();
    this.setupSessionEvents();
  }

  start(port = 0): Promise<number> {
    return new Promise((resolve, reject) => {
      this.wss = new WebSocketServer({ port }, () => {
        const addr = this.wss!.address();
        const resolvedPort = (addr && typeof addr === 'object') ? addr.port : port;

        this.pairing.displayQR(resolvedPort);
        console.log(`  PocketDev daemon listening on port ${resolvedPort}`);
        console.log(`  Hostname: ${os.hostname()}`);
        console.log(`  Waiting for mobile app to connect...\n`);

        // Start web dashboard on fixed port 7778
        this.dashboard.start(7778, resolvedPort, this.pairing)
          .then((dashPort) => {
            console.log(`  Dashboard: http://localhost:${dashPort}`);
            console.log(`  Open in browser to see QR code & connection details\n`);
          })
          .catch((err) => {
            console.error('  Dashboard failed to start:', err.message);
          });

        resolve(resolvedPort);
      });

      this.wss.on('error', reject);

      this.wss.on('connection', (ws: WebSocket) => {
        const clientId = `client-${++this.clientCounter}`;
        const client: Client = { ws, paired: false };
        this.clients.set(clientId, client);

        console.log(`  [connect] Client ${clientId} connected`);

        ws.on('message', (raw: Buffer) => {
          try {
            const msg: MobileMessage = JSON.parse(raw.toString());
            this.handleMessage(clientId, msg);
          } catch (err) {
            this.sendTo(clientId, { type: 'error', message: 'Invalid message format' });
          }
        });

        ws.on('close', () => {
          console.log(`  [disconnect] Client ${clientId} disconnected`);
          this.clients.delete(clientId);
        });

        ws.on('error', (err) => {
          console.error(`  [error] Client ${clientId}:`, err.message);
        });

        // Send initial status
        this.sendTo(clientId, {
          type: 'status',
          online: true,
          hostname: os.hostname(),
          homedir: os.homedir(),
          sessions: this.sessions.listSessions().length,
        });
      });
    });
  }

  stop(): void {
    this.sessions.killAll();
    this.dashboard.stop();
    for (const [, client] of this.clients) {
      client.ws.close();
    }
    this.wss?.close();
  }

  private handleMessage(clientId: string, msg: MobileMessage): void {
    const client = this.clients.get(clientId);
    if (!client) return;

    // Pairing must happen first (unless already paired)
    if (msg.type === 'pair:verify') {
      const success = this.pairing.verify(msg.token);
      client.paired = success;
      if (success) {
        console.log(`  [paired] Client ${clientId} paired successfully!`);
        this.pairing.addDevice(clientId);
      }
      this.sendTo(clientId, {
        type: 'paired',
        success,
        daemonId: this.pairing.daemonId,
      });

      // Send session list after pairing
      if (success) {
        this.sendTo(clientId, {
          type: 'session:list',
          sessions: this.sessions.listSessions(),
        });
      }
      return;
    }

    // All other messages require pairing
    if (!client.paired) {
      this.sendTo(clientId, { type: 'error', message: 'Not paired. Send pair:verify first.' });
      return;
    }

    switch (msg.type) {
      case 'session:create': {
        try {
          const session = this.sessions.createSession(msg.tool, msg.cwd);
          console.log(`  [session] Created ${session.tool} session: ${session.id}`);
          this.broadcast({
            type: 'session:update',
            session: session.toJSON(),
          });
        } catch (err: any) {
          console.error(`  [session] Failed to create session:`, err.message);
          this.sendTo(clientId, { type: 'error', message: `Failed to create session: ${err.message}` });
        }
        break;
      }

      case 'session:kill': {
        this.sessions.killSession(msg.sessionId);
        console.log(`  [session] Killed session: ${msg.sessionId}`);
        break;
      }

      case 'session:list': {
        this.sendTo(clientId, {
          type: 'session:list',
          sessions: this.sessions.listSessions(),
        });
        break;
      }

      case 'command': {
        const session = this.sessions.getSession(msg.sessionId);
        if (session) {
          console.log(`  [prompt] ${msg.sessionId}: ${msg.text.slice(0, 60)}...`);
          session.sendPrompt(msg.text);
        } else {
          this.sendTo(clientId, { type: 'error', message: `Session ${msg.sessionId} not found` });
        }
        break;
      }

      case 'session:cancel': {
        const session = this.sessions.getSession(msg.sessionId);
        if (session) {
          console.log(`  [cancel] ${msg.sessionId}`);
          session.cancel();
        } else {
          this.sendTo(clientId, { type: 'error', message: `Session ${msg.sessionId} not found` });
        }
        break;
      }

      case 'session:config': {
        const session = this.sessions.getSession(msg.sessionId);
        if (session) {
          console.log(`  [config] ${msg.sessionId}: ${JSON.stringify(msg.config)}`);
          session.setConfig(msg.config);
        } else {
          this.sendTo(clientId, { type: 'error', message: `Session ${msg.sessionId} not found` });
        }
        break;
      }

      case 'projects:list': {
        console.log(`  [projects] Listing projects for ${clientId}`);
        const recentCwds = getRecentCwds();
        const savedWorkspaces = loadWorkspaces();
        const excluded = loadExcludedPaths();
        const activeSessions = this.sessions.listSessions();
        this.projectScanner.getProjects(recentCwds).then(projects => {
          // Merge active session info
          for (const session of activeSessions) {
            const idx = projects.findIndex(p => p.path === session.cwd);
            if (idx >= 0) {
              projects[idx] = { ...projects[idx], tier: 'active' };
            } else if (session.cwd) {
              projects.unshift({
                path: session.cwd,
                name: basename(session.cwd) || session.cwd,
                dirty: false,
                changedFiles: 0,
                tier: 'active',
              });
            }
          }
          // Merge saved workspaces (user-selected dirs that scanner might miss)
          for (const sw of savedWorkspaces) {
            if (!projects.some(p => p.path === sw.path)) {
              projects.push({
                path: sw.path,
                name: sw.name,
                dirty: false,
                changedFiles: 0,
                lastUsed: sw.lastUsed,
                tier: 'recent',
              });
            }
          }
          // Filter out excluded paths
          const filtered = projects.filter(p => !excluded.has(p.path));
          this.sendTo(clientId, { type: 'projects:data', projects: filtered });
        }).catch((err: any) => {
          console.error(`  [projects] Error listing projects:`, err.message);
          this.sendTo(clientId, { type: 'error', message: 'Failed to list projects' });
        });
        break;
      }

      case 'projects:refresh': {
        console.log(`  [projects] Refreshing projects for ${clientId}`);
        this.projectScanner.invalidate();
        const recentCwds = getRecentCwds();
        this.projectScanner.getProjects(recentCwds).then(projects => {
          this.sendTo(clientId, { type: 'projects:data', projects });
        }).catch((err: any) => {
          console.error(`  [projects] Error refreshing projects:`, err.message);
          this.sendTo(clientId, { type: 'error', message: 'Failed to refresh projects' });
        });
        break;
      }

      case 'projects:browse': {
        const browsePath = msg.path;
        // Path traversal mitigation
        if (browsePath.includes('\0') || resolve(browsePath) !== browsePath) {
          this.sendTo(clientId, { type: 'error', message: 'Invalid path' });
          break;
        }
        console.log(`  [projects] Browsing ${browsePath} for ${clientId}`);
        const dirs = this.projectScanner.listDirectories(browsePath);
        this.sendTo(clientId, { type: 'projects:dirs', path: browsePath, dirs });
        break;
      }

      case 'projects:search': {
        console.log(`  [projects] Searching "${msg.query}" for ${clientId}`);
        const results = this.projectScanner.searchDirectories(msg.query);
        this.sendTo(clientId, { type: 'projects:search_results', results });
        break;
      }

      case 'workspace:save': {
        console.log(`  [workspace] Saving ${msg.path} for ${clientId}`);
        saveWorkspace(msg.path, msg.name);
        removeExcludedPath(msg.path);
        break;
      }

      case 'workspace:remove': {
        console.log(`  [workspace] Removing ${msg.path} for ${clientId}`);
        removeWorkspace(msg.path);
        break;
      }
    }
  }

  private setupSessionEvents(): void {
    this.sessions.on('card', (card: Card) => {
      this.broadcast({ type: 'card', card });
    });

    this.sessions.on('session:update', (session: Session) => {
      this.broadcast({ type: 'session:update', session });
    });

    this.sessions.on('stream:start', (data: { sessionId: string; cardId: string }) => {
      this.broadcast({ type: 'stream:start', sessionId: data.sessionId, cardId: data.cardId });
    });

    this.sessions.on('stream:delta', (data: { sessionId: string; cardId: string; delta: string }) => {
      this.broadcast({ type: 'stream:delta', sessionId: data.sessionId, cardId: data.cardId, delta: data.delta });
    });

    this.sessions.on('stream:tool_start', (data: { sessionId: string; cardId: string; tool: string; input: string }) => {
      this.broadcast({ type: 'stream:tool_start', sessionId: data.sessionId, cardId: data.cardId, tool: data.tool, input: data.input });
    });

    this.sessions.on('stream:tool_result', (data: { sessionId: string; toolName: string; toolId: string; content: string; contentType: string }) => {
      this.broadcast({ type: 'stream:tool_result', sessionId: data.sessionId, toolName: data.toolName, toolId: data.toolId, content: data.content, contentType: data.contentType });
    });

    this.sessions.on('stream:tool_update', (data: { sessionId: string; cardId: string; tool: string; summary: string }) => {
      this.broadcast({ type: 'stream:tool_update', sessionId: data.sessionId, cardId: data.cardId, tool: data.tool, summary: data.summary });
    });

    this.sessions.on('stream:tool_end', (data: { sessionId: string; cardId: string; tool: string; toolId?: string }) => {
      this.broadcast({ type: 'stream:tool_end', sessionId: data.sessionId, cardId: data.cardId, tool: data.tool, toolId: data.toolId });
    });

    this.sessions.on('stream:end', (data: { sessionId: string; cardId: string; usage?: UsageInfo }) => {
      this.broadcast({ type: 'stream:end', sessionId: data.sessionId, cardId: data.cardId, usage: data.usage });
    });
  }

  private sendTo(clientId: string, msg: DaemonMessage): void {
    const client = this.clients.get(clientId);
    if (client && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(JSON.stringify(msg));
    }
  }

  private broadcast(msg: DaemonMessage): void {
    const data = JSON.stringify(msg);
    for (const [, client] of this.clients) {
      if (client.paired && client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(data);
      }
    }
  }
}
