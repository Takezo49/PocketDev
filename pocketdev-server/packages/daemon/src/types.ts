// PocketDev Protocol Types

// --- Cards ---

export type CardType = 'message' | 'diff' | 'command' | 'test' | 'approval' | 'error' | 'tool_result' | 'user_prompt';

export interface BaseCard {
  id: string;
  type: CardType;
  timestamp: number;
  sessionId: string;
}

export interface MessageCard extends BaseCard {
  type: 'message';
  text: string;
}

export interface DiffHunk {
  oldStart: number;
  newStart: number;
  lines: { type: 'add' | 'remove' | 'context'; content: string }[];
}

export interface DiffCard extends BaseCard {
  type: 'diff';
  file: string;
  hunks: DiffHunk[];
}

export interface CommandCard extends BaseCard {
  type: 'command';
  command: string;
  output: string;
  exitCode?: number;
}

export interface TestCard extends BaseCard {
  type: 'test';
  passed: number;
  failed: number;
  total: number;
  summary: string;
}

export interface ApprovalCard extends BaseCard {
  type: 'approval';
  prompt: string;
  options: string[];
}

export interface ErrorCard extends BaseCard {
  type: 'error';
  message: string;
}

export interface ToolResultCard extends BaseCard {
  type: 'tool_result';
  toolName: string;
  content: string;
  contentType: 'file' | 'bash' | 'diff' | 'search' | 'other';
  truncated: boolean;
}

export interface UserPromptCard extends BaseCard {
  type: 'user_prompt';
  text: string;
}

export type Card = MessageCard | DiffCard | CommandCard | TestCard | ApprovalCard | ErrorCard | ToolResultCard | UserPromptCard;

// --- Usage & Config ---

export interface UsageInfo {
  totalCostUsd: number;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
  durationMs: number;
  model: string;
  contextWindow: number;
  maxOutputTokens: number;
}

export interface SessionConfig {
  model?: string;
  effort?: 'low' | 'medium' | 'high';
  skipPermissions?: boolean;
}

// --- Sessions ---

export interface Session {
  id: string;
  tool: string;
  cwd: string;
  status: 'running' | 'idle' | 'stopped';
  createdAt: number;
  queueLength?: number;
  totalCost?: number;
  model?: string;
  effort?: string;
}

// --- Protocol Messages ---

// --- Project Discovery ---

export interface ProjectInfo {
  path: string;
  name: string;
  branch?: string;
  dirty: boolean;
  changedFiles: number;
  lastCommitMsg?: string;
  framework?: string;
  lastUsed?: number;
  tier: 'active' | 'recent' | 'discovered';
}

export interface DirEntry {
  name: string;
  hasGit: boolean;
  isFile: boolean;
}

// Daemon -> Mobile
export type DaemonMessage =
  | { type: 'card'; card: Card }
  | { type: 'stream'; sessionId: string; chunk: string }
  | { type: 'stream:start'; sessionId: string; cardId: string }
  | { type: 'stream:delta'; sessionId: string; cardId: string; delta: string }
  | { type: 'stream:tool_start'; sessionId: string; cardId: string; tool: string; input: string }
  | { type: 'stream:tool_result'; sessionId: string; toolName: string; toolId: string; content: string; contentType: string }
  | { type: 'stream:tool_update'; sessionId: string; cardId: string; tool: string; summary: string }
  | { type: 'stream:tool_end'; sessionId: string; cardId: string; tool: string; toolId?: string }
  | { type: 'stream:end'; sessionId: string; cardId: string; usage?: UsageInfo }
  | { type: 'session:update'; session: Session }
  | { type: 'session:list'; sessions: Session[] }
  | { type: 'approval:request'; id: string; sessionId: string; prompt: string }
  | { type: 'status'; online: boolean; hostname: string; homedir: string; sessions: number }
  | { type: 'paired'; success: boolean; daemonId: string }
  | { type: 'projects:data'; projects: ProjectInfo[] }
  | { type: 'projects:dirs'; path: string; dirs: DirEntry[] }
  | { type: 'projects:search_results'; results: { path: string; name: string; hasGit: boolean; isFile: boolean }[] }
  | { type: 'session:cards'; sessionId: string; cards: any[] }
  | { type: 'error'; message: string };

// Mobile -> Daemon
export type MobileMessage =
  | { type: 'command'; sessionId: string; text: string }
  | { type: 'approval:response'; id: string; approved: boolean }
  | { type: 'session:create'; tool: string; cwd?: string }
  | { type: 'session:kill'; sessionId: string }
  | { type: 'session:list' }
  | { type: 'pair:verify'; token: string }
  | { type: 'session:cancel'; sessionId: string }
  | { type: 'session:config'; sessionId: string; config: SessionConfig }
  | { type: 'projects:list' }
  | { type: 'projects:refresh' }
  | { type: 'projects:browse'; path: string }
  | { type: 'workspace:save'; path: string; name: string }
  | { type: 'workspace:remove'; path: string }
  | { type: 'projects:search'; query: string }
  | { type: 'session:history'; sessionId: string };

// --- Pairing ---

export interface PairingPayload {
  daemonId: string;
  host: string;
  port: number;
  secret: string;
}
