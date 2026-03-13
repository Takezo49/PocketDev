import { EventEmitter } from 'events';
import { spawn, ChildProcess } from 'child_process';
import { nanoid } from 'nanoid';
import type { Card, Session, UsageInfo, SessionConfig } from './types.js';

/** Classify a tool name into a content type for the UI. */
function classifyTool(toolName: string): 'file' | 'bash' | 'diff' | 'search' | 'other' {
  const name = toolName.toLowerCase();
  if (name === 'read' || name === 'write') return 'file';
  if (name === 'bash') return 'bash';
  if (name === 'edit') return 'diff';
  if (name === 'grep' || name === 'glob') return 'search';
  return 'other';
}

/** Format tool input into a clean one-line summary. */
function formatToolSummary(name: string, input: any): string {
  if (!input) return '';
  if (name === 'Read') return input.file_path || '';
  if (name === 'Edit') {
    const fp = input.file_path || '';
    const oldLines = (input.old_string || '').split('\n').length;
    const newLines = (input.new_string || '').split('\n').length;
    return `${fp} (-${oldLines} +${newLines})`;
  }
  if (name === 'Write') return input.file_path || '';
  if (name === 'Bash') return input.command || '';
  if (name === 'Grep') return `/${input.pattern || ''}/ ${input.path || ''}`.trim();
  if (name === 'Glob') return `${input.pattern || ''} ${input.path || ''}`.trim();
  const keys = Object.keys(input);
  return keys.length > 0 ? String(input[keys[0]]).slice(0, 200) : '';
}

export class ClaudeSession extends EventEmitter {
  public readonly id: string;
  public readonly tool = 'claude';
  public readonly cwd: string;
  public readonly createdAt: number;
  private claudeSessionId: string | null = null;
  private proc: ChildProcess | null = null;
  private _status: 'idle' | 'running' | 'stopped' = 'idle';
  private cardCounter = 0;
  private messageQueue: string[] = [];
  private currentCardId: string | null = null;
  private currentText = '';

  // Track tool card IDs: toolUseId → { cardId, toolName } (so tool_end can find the right card)
  private toolCardIds = new Map<string, { cardId: string; toolName: string }>();
  // Track which tool_use block IDs we've already seen (prevent assistant duplicates)
  private seenToolUseIds = new Set<string>();
  // Store Edit tool inputs so we can construct diffs when the tool_result arrives
  private editToolInputs = new Map<string, { file_path: string; old_string: string; new_string: string }>();
  // Store Write tool inputs so we can show written content
  private writeToolInputs = new Map<string, { file_path: string; content: string }>();

  // Usage tracking
  public cumulativeCost = 0;
  public lastUsage: UsageInfo | null = null;

  // Session config
  public config: SessionConfig = {
    skipPermissions: true,
  };

  constructor(cwd: string) {
    super();
    this.id = nanoid(12);
    this.cwd = cwd;
    this.createdAt = Date.now();
  }

  get status() { return this._status; }
  get alive() { return this._status !== 'stopped'; }
  get queueLength() { return this.messageQueue.length; }

  sendPrompt(text: string): void {
    if (this._status === 'stopped') return;

    if (text.startsWith('/')) {
      const handled = this._handleSlashCommand(text);
      if (handled) return;
    }

    if (this._status === 'running' || this.proc) {
      this.messageQueue.push(text);
      console.log(`  [queue] Session ${this.id}: queued message (${this.messageQueue.length} pending)`);
      this.emit('status', this.toJSON());
      return;
    }

    this._executePrompt(text);
  }

  cancel(): void {
    if (this.proc) {
      this.proc.kill('SIGTERM');
    }
    this.messageQueue = [];
    this.emit('status', this.toJSON());
  }

  setConfig(newConfig: SessionConfig): void {
    if (newConfig.model !== undefined) this.config.model = newConfig.model;
    if (newConfig.effort !== undefined) this.config.effort = newConfig.effort;
    if (newConfig.skipPermissions !== undefined) this.config.skipPermissions = newConfig.skipPermissions;
    this.emit('status', this.toJSON());
  }

  private _handleSlashCommand(text: string): boolean {
    const parts = text.trim().split(/\s+/);
    const cmd = parts[0].toLowerCase();
    const arg = parts.slice(1).join(' ');

    switch (cmd) {
      case '/model': {
        if (arg) {
          this.config.model = arg;
          this.emit('card', this._makeCard('message', {
            text: `Model set to **${arg}**. Next prompt will use this model.`,
          }));
          this.emit('status', this.toJSON());
        } else {
          this.emit('card', this._makeCard('message', {
            text: `Current model: **${this.config.model || 'default'}**\nUsage: /model <name> (e.g., /model sonnet, /model opus, /model haiku)`,
          }));
        }
        return true;
      }

      case '/effort': {
        const level = arg.toLowerCase();
        if (level === 'low' || level === 'medium' || level === 'high') {
          this.config.effort = level;
          this.emit('card', this._makeCard('message', {
            text: `Effort set to **${level}**.`,
          }));
          this.emit('status', this.toJSON());
        } else {
          this.emit('card', this._makeCard('message', {
            text: `Current effort: **${this.config.effort || 'default'}**\nUsage: /effort <low|medium|high>`,
          }));
        }
        return true;
      }

      case '/clear': {
        this.claudeSessionId = null;
        this.emit('card', this._makeCard('message', {
          text: 'Conversation cleared. Next prompt starts a fresh session.',
        }));
        return true;
      }

      case '/cost': {
        const usage = this.lastUsage;
        let msg = `**Cumulative cost:** $${this.cumulativeCost.toFixed(4)}`;
        if (usage) {
          msg += `\n**Last turn:** ${usage.inputTokens} in / ${usage.outputTokens} out`;
          msg += `\n**Cache:** ${usage.cacheReadTokens} read / ${usage.cacheCreationTokens} created`;
          msg += `\n**Model:** ${usage.model}`;
          msg += `\n**Duration:** ${(usage.durationMs / 1000).toFixed(1)}s`;
        }
        this.emit('card', this._makeCard('message', { text: msg }));
        return true;
      }

      default:
        return false;
    }
  }

  private _executePrompt(text: string): void {
    this._status = 'running';
    this.currentCardId = this._makeCardId();
    this.currentText = '';
    // Reset per-prompt tracking
    this.toolCardIds.clear();
    this.seenToolUseIds.clear();
    this.editToolInputs.clear();
    this.writeToolInputs.clear();
    this.emit('status', this.toJSON());

    this.emit('stream:start', {
      sessionId: this.id,
      cardId: this.currentCardId,
    });

    const args = [
      '-p', text,
      '--output-format', 'stream-json',
      '--verbose',
      '--include-partial-messages',
    ];

    if (this.config.skipPermissions) {
      args.push('--dangerously-skip-permissions');
    }
    if (this.config.model) {
      args.push('--model', this.config.model);
    }
    if (this.config.effort) {
      args.push('--effort', this.config.effort);
    }

    if (this.claudeSessionId) {
      args.push('--resume', this.claudeSessionId);
    }

    this.proc = spawn('claude', args, {
      cwd: this.cwd,
      env: { ...process.env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let buffer = '';

    this.proc.stdout?.on('data', (chunk: Buffer) => {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line);
          this._handleStreamEvent(event);
        } catch (e) {
          console.error(`  [parse] Failed to parse stream JSON: ${String(e).slice(0, 100)}`);
        }
      }
    });

    this.proc.stderr?.on('data', (chunk: Buffer) => {
      const text = chunk.toString().trim();
      if (text) {
        console.error(`  [claude stderr] ${text.slice(0, 200)}`);
      }
    });

    this.proc.on('close', (code) => {
      if (buffer.trim()) {
        try {
          const event = JSON.parse(buffer);
          this._handleStreamEvent(event);
        } catch (e) {
          console.error(`  [parse] Failed to parse final buffer: ${String(e).slice(0, 100)}`);
        }
      }

      if (this.currentText.trim()) {
        this.emit('card', this._makeCard('message', { text: this.currentText }));
      }

      // Fix #1: Close any orphaned tool cards (spinner → error state)
      for (const [toolUseId, tracked] of this.toolCardIds) {
        this.emit('stream:tool_end', {
          sessionId: this.id,
          cardId: tracked.cardId,
          tool: tracked.toolName,
          toolId: toolUseId,
        });
      }

      if (this.currentCardId) {
        this.emit('stream:end', {
          sessionId: this.id,
          cardId: this.currentCardId,
          usage: this.lastUsage || undefined,
        });
      }

      this.proc = null;
      this.currentCardId = null;
      this.currentText = '';
      this.toolCardIds.clear();
      this.seenToolUseIds.clear();
      this.editToolInputs.clear();
      this.writeToolInputs.clear();
      this._status = 'idle';
      this.emit('status', this.toJSON());
      this._processQueue();
    });

    this.proc.on('error', (err) => {
      console.error(`  [claude error] ${err.message}`);
      this.proc = null;
      this._status = 'idle';
      this.emit('card', this._makeCard('error', { message: `Failed to start claude: ${err.message}` }));
      this.emit('status', this.toJSON());
      this._processQueue();
    });
  }

  private _processQueue(): void {
    if (this.messageQueue.length > 0 && !this.proc && this._status !== 'stopped') {
      const next = this.messageQueue.shift()!;
      console.log(`  [queue] Session ${this.id}: processing queued message (${this.messageQueue.length} remaining)`);
      this._executePrompt(next);
    }
  }

  private _handleStreamEvent(event: any): void {
    switch (event.type) {
      case 'system': {
        if (event.subtype === 'init' && event.session_id) {
          this.claudeSessionId = event.session_id;
        }
        break;
      }

      case 'stream_event': {
        const inner = event.event;
        if (!inner) break;

        // Text delta
        if (inner.type === 'content_block_delta' && inner.delta?.type === 'text_delta') {
          const delta = inner.delta.text;
          this.currentText += delta;
          this.emit('stream:delta', {
            sessionId: this.id,
            cardId: this.currentCardId,
            delta,
          });
        }

        // Tool use start
        if (inner.type === 'content_block_start' && inner.content_block?.type === 'tool_use') {
          // Flush text stream if any
          if (this.currentText.trim() && this.currentCardId) {
            this.emit('stream:end', {
              sessionId: this.id,
              cardId: this.currentCardId,
            });
            this.emit('card', this._makeCard('message', { text: this.currentText }));
            this.currentText = '';
            this.currentCardId = this._makeCardId();
            this.emit('stream:start', {
              sessionId: this.id,
              cardId: this.currentCardId,
            });
          }

          const toolName = inner.content_block.name || 'unknown';
          const toolUseId = inner.content_block.id || '';
          // Create card with tracked ID
          const toolCardId = this._makeCardId();
          this.toolCardIds.set(toolUseId, { cardId: toolCardId, toolName });
          this.seenToolUseIds.add(toolUseId);

          this.emit('stream:tool_start', {
            sessionId: this.id,
            cardId: toolCardId,
            tool: toolName,
            toolId: toolUseId,
            input: '',
          });
        }

        break;
      }

      case 'assistant': {
        // With --include-partial-messages this fires MANY times.
        const msg = event.message;
        if (!msg?.content) break;

        for (const block of msg.content) {
          if (block.type === 'tool_use' && block.id) {
            if (!block.input || Object.keys(block.input).length === 0) continue;

            // Always update Edit/Write inputs (overwrite with latest, most complete data)
            if (block.name === 'Edit' && (block.input?.old_string !== undefined || block.input?.new_string !== undefined)) {
              this.editToolInputs.set(block.id, {
                file_path: block.input.file_path || '',
                old_string: block.input.old_string || '',
                new_string: block.input.new_string || '',
              });
            }
            if (block.name === 'Write' && block.input?.content !== undefined) {
              this.writeToolInputs.set(block.id, {
                file_path: block.input.file_path || '',
                content: block.input.content,
              });
            }

            // Only emit summary update once per tool
            const summaryKey = `summary-${block.id}`;
            if (this.seenToolUseIds.has(summaryKey)) continue;
            this.seenToolUseIds.add(summaryKey);

            // Flush text before tool
            if (this.currentText.trim()) {
              this.emit('card', this._makeCard('message', { text: this.currentText }));
              this.currentText = '';
            }

            // Update the existing tool card with the summary
            const tracked = this.toolCardIds.get(block.id);
            if (tracked) {
              const summary = formatToolSummary(block.name, block.input);
              this.emit('stream:tool_update', {
                sessionId: this.id,
                cardId: tracked.cardId,
                tool: block.name,
                summary,
              });
            }
          }
        }
        break;
      }

      // Claude CLI sends tool results as 'user' events, not 'tool_result'
      case 'user': {
        const msg = event.message;
        if (!msg?.content) break;

        for (const block of msg.content) {
          if (block.type !== 'tool_result') continue;

          const toolUseId = block.tool_use_id || '';
          const tracked = this.toolCardIds.get(toolUseId);
          let toolName = tracked?.toolName || '';

          let content = '';
          if (typeof block.content === 'string') {
            content = block.content;
          } else if (Array.isArray(block.content)) {
            content = block.content
              .filter((c: any) => c.type === 'text')
              .map((c: any) => c.text)
              .join('\n');
          }

          const editInput = this.editToolInputs.get(toolUseId);
          let contentType = classifyTool(toolName);

          if (editInput) {
            // Construct proper diff from stored input
            const diffLines: string[] = [];
            diffLines.push(`--- ${editInput.file_path}`);
            diffLines.push(`+++ ${editInput.file_path}`);
            for (const line of editInput.old_string.split('\n')) {
              diffLines.push(`- ${line}`);
            }
            for (const line of editInput.new_string.split('\n')) {
              diffLines.push(`+ ${line}`);
            }
            content = diffLines.join('\n');
            contentType = 'diff';
            this.editToolInputs.delete(toolUseId);
          }

          // For Write tools, show the actual written content with all lines as green (new file)
          const writeInput = this.writeToolInputs.get(toolUseId);
          if (writeInput) {
            const diffLines: string[] = [];
            diffLines.push(`+++ ${writeInput.file_path} (new file)`);
            for (const line of writeInput.content.split('\n')) {
              diffLines.push(`+ ${line}`);
            }
            content = diffLines.join('\n');
            contentType = 'diff';
            this.writeToolInputs.delete(toolUseId);
          }

          this.emit('stream:tool_result', {
            sessionId: this.id,
            toolName,
            toolId: toolUseId,
            content: content.slice(0, 50000),
            contentType,
          });

          // Use the TRACKED card ID so Flutter can find the spinner card
          const toolCardId = tracked?.cardId || this.currentCardId;
          this.emit('stream:tool_end', {
            sessionId: this.id,
            cardId: toolCardId,
            tool: toolName,
            toolId: toolUseId,
          });
        }
        break;
      }

      // Fallback: some Claude CLI versions may use 'tool_result' directly
      case 'tool_result': {
        const toolName = event.tool_name || '';
        const toolUseId = event.tool_use_id || '';

        let content = '';
        if (Array.isArray(event.content)) {
          content = event.content
            .filter((c: any) => c.type === 'text')
            .map((c: any) => c.text)
            .join('\n');
        } else if (typeof event.content === 'string') {
          content = event.content;
        }

        let contentType = classifyTool(toolName);

        const editInput = this.editToolInputs.get(toolUseId);
        if (toolName === 'Edit' && editInput) {
          const diffLines: string[] = [];
          diffLines.push(`--- ${editInput.file_path}`);
          diffLines.push(`+++ ${editInput.file_path}`);
          for (const line of editInput.old_string.split('\n')) {
            diffLines.push(`- ${line}`);
          }
          for (const line of editInput.new_string.split('\n')) {
            diffLines.push(`+ ${line}`);
          }
          content = diffLines.join('\n');
          contentType = 'diff';
          this.editToolInputs.delete(toolUseId);
        }

        this.emit('stream:tool_result', {
          sessionId: this.id,
          toolName,
          toolId: toolUseId,
          content: content.slice(0, 50000),
          contentType,
        });

        const tracked2 = this.toolCardIds.get(toolUseId);
        const toolCardId = tracked2?.cardId || this.currentCardId;
        this.emit('stream:tool_end', {
          sessionId: this.id,
          cardId: toolCardId,
          tool: toolName,
          toolId: toolUseId,
        });
        break;
      }

      case 'result': {
        if (event.subtype === 'error' || event.is_error) {
          this.emit('card', this._makeCard('error', {
            message: event.result || 'Unknown error',
          }));
        }
        if (event.session_id) {
          this.claudeSessionId = event.session_id;
        }

        if (event.total_cost_usd !== undefined) {
          const modelKey = Object.keys(event.model_usage || event.modelUsage || {})[0] || '';
          const modelInfo = (event.model_usage || event.modelUsage || {})[modelKey] || {};
          const usage: UsageInfo = {
            totalCostUsd: event.total_cost_usd,
            inputTokens: event.usage?.input_tokens ?? 0,
            outputTokens: event.usage?.output_tokens ?? 0,
            cacheReadTokens: event.usage?.cache_read_input_tokens ?? 0,
            cacheCreationTokens: event.usage?.cache_creation_input_tokens ?? 0,
            durationMs: event.duration_ms ?? 0,
            model: modelKey,
            contextWindow: modelInfo.contextWindow ?? 0,
            maxOutputTokens: modelInfo.maxOutputTokens ?? 0,
          };
          this.cumulativeCost += usage.totalCostUsd;
          this.lastUsage = usage;
        }
        break;
      }
    }
  }

  kill(): void {
    if (this.proc) {
      this.proc.kill('SIGTERM');
      this.proc = null;
    }
    this.messageQueue = [];
    this._status = 'stopped';
  }

  toJSON(): Session {
    return {
      id: this.id,
      tool: this.tool,
      cwd: this.cwd,
      status: this.status,
      createdAt: this.createdAt,
      queueLength: this.messageQueue.length,
      totalCost: this.cumulativeCost,
      model: this.config.model,
      effort: this.config.effort,
    };
  }

  private _makeCardId(): string {
    return `card-${Date.now()}-${++this.cardCounter}`;
  }

  private _makeCard(type: string, data: Record<string, any>): Card {
    return {
      id: this._makeCardId(),
      type,
      timestamp: Date.now(),
      sessionId: this.id,
      ...data,
    } as Card;
  }
}
