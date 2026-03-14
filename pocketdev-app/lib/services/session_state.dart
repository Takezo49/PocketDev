import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection.dart';

class SessionInfo {
  final String id;
  final String tool;
  final String cwd;
  final String status;
  final int createdAt;
  final double totalCost;
  final String model;
  final String effort;
  final int queueLength;

  SessionInfo({
    required this.id,
    required this.tool,
    required this.cwd,
    required this.status,
    required this.createdAt,
    this.totalCost = 0,
    this.model = '',
    this.effort = '',
    this.queueLength = 0,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: json['id'] ?? '',
        tool: json['tool'] ?? '',
        cwd: json['cwd'] ?? '',
        status: json['status'] ?? 'idle',
        createdAt: json['createdAt'] ?? 0,
        totalCost: (json['totalCost'] ?? 0).toDouble(),
        model: json['model'] ?? '',
        effort: json['effort'] ?? '',
        queueLength: json['queueLength'] ?? 0,
      );
}

class UsageInfo {
  final double totalCostUsd;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final int durationMs;
  final String model;
  final int contextWindow;
  final int maxOutputTokens;

  UsageInfo({
    this.totalCostUsd = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
    this.durationMs = 0,
    this.model = '',
    this.contextWindow = 0,
    this.maxOutputTokens = 0,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) => UsageInfo(
        totalCostUsd: (json['totalCostUsd'] ?? 0).toDouble(),
        inputTokens: json['inputTokens'] ?? 0,
        outputTokens: json['outputTokens'] ?? 0,
        cacheReadTokens: json['cacheReadTokens'] ?? 0,
        cacheCreationTokens: json['cacheCreationTokens'] ?? 0,
        durationMs: json['durationMs'] ?? 0,
        model: json['model'] ?? '',
        contextWindow: json['contextWindow'] ?? 0,
        maxOutputTokens: json['maxOutputTokens'] ?? 0,
      );

  double get contextUsedRatio {
    if (contextWindow == 0) return 0;
    return (inputTokens + outputTokens) / contextWindow;
  }
}

class CardData {
  final String id;
  final String type;
  final String sessionId;
  final int timestamp;
  final Map<String, dynamic> raw;

  CardData({
    required this.id,
    required this.type,
    required this.sessionId,
    required this.timestamp,
    required this.raw,
  });

  String get text => raw['text'] ?? '';
  String get prompt => raw['prompt'] ?? '';
  String get command => raw['command'] ?? '';
  String get output => raw['output'] ?? '';
  String get file => raw['file'] ?? '';
  int get passed => raw['passed'] ?? 0;
  int get failed => raw['failed'] ?? 0;
  String get summary => raw['summary'] ?? '';
  bool get isStreaming => raw['streaming'] == true;

  // Tool result fields
  String get toolName => raw['toolName'] ?? '';
  String get content => raw['content'] ?? '';
  String get contentType => raw['contentType'] ?? 'other';
  bool get truncated => raw['truncated'] == true;
}

class SessionState extends ChangeNotifier {
  final DevBoxConnection _conn;
  StreamSubscription? _sub;

  final List<SessionInfo> _sessions = [];
  final List<CardData> _cards = [];
  final Map<String, CardData> _streamingCards = {};
  final Map<String, String> streamingText = {};
  String? _activeSessionId;
  String? _pendingCommand;

  /// Working directory for new sessions (set by workspace picker)
  String? workspaceCwd;

  // Usage tracking
  UsageInfo? _lastUsage;
  double _cumulativeCost = 0;

  List<SessionInfo> get sessions => _sessions;
  String? get activeSessionId => _activeSessionId;
  UsageInfo? get lastUsage => _lastUsage;
  double get cumulativeCost => _cumulativeCost;

  /// Get the active session's model name.
  String get currentModel {
    final session = _sessions.where((s) => s.id == _activeSessionId).firstOrNull;
    return session?.model ?? _lastUsage?.model ?? '';
  }

  /// Get the active session's effort level.
  String get currentEffort {
    final session = _sessions.where((s) => s.id == _activeSessionId).firstOrNull;
    return session?.effort ?? '';
  }

  /// Context window usage ratio (0.0 - 1.0).
  double get contextUsedRatio => _lastUsage?.contextUsedRatio ?? 0;

  /// Returns all cards for the active session, including any in-progress
  /// streaming cards appended at the end (sorted by timestamp).
  List<CardData> get cards {
    final sessionId = _activeSessionId;
    final settled = sessionId != null
        ? _cards.where((c) => c.sessionId == sessionId).toList()
        : List<CardData>.from(_cards);

    // Append streaming cards that belong to this session.
    final streaming = _streamingCards.values
        .where((c) => sessionId == null || c.sessionId == sessionId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return [...settled, ...streaming];
  }

  /// True when at least one card is actively streaming for the current session.
  bool get isStreaming {
    if (_activeSessionId == null) return _streamingCards.isNotEmpty;
    return _streamingCards.values
        .any((c) => c.sessionId == _activeSessionId);
  }

  /// Queue length for the active session.
  int get queueLength {
    final session = _sessions.where((s) => s.id == _activeSessionId).firstOrNull;
    return session?.queueLength ?? 0;
  }

  /// Get the current accumulated streaming text for a card.
  String streamingCardText(String cardId) {
    return streamingText[cardId] ?? '';
  }

  SessionState(this._conn) {
    _sub = _conn.messages.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'session:list':
        _sessions.clear();
        for (final s in (msg['sessions'] as List)) {
          _sessions.add(SessionInfo.fromJson(s));
        }
        _autoSelectSession();
        notifyListeners();
        break;

      case 'session:update':
        final session = SessionInfo.fromJson(msg['session']);
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx >= 0) {
          _sessions[idx] = session;
        } else {
          _sessions.add(session);
        }
        // Update cumulative cost from session
        if (session.id == _activeSessionId) {
          _cumulativeCost = session.totalCost;
        }
        _autoSelectSession();
        // Send pending command if session just appeared
        if (_pendingCommand != null && _activeSessionId != null) {
          sendCommand(_activeSessionId!, _pendingCommand!);
          _pendingCommand = null;
        }
        notifyListeners();
        break;

      case 'session:cards':
        // Populate cards from daemon history (only if no local cards for this session)
        final histSessionId = msg['sessionId'] ?? '';
        final hasLocal = _cards.any((c) => c.sessionId == histSessionId);
        if (!hasLocal) {
          final histCards = msg['cards'] as List? ?? [];
          for (final c in histCards) {
            final card = c is Map<String, dynamic> ? c : <String, dynamic>{};
            _cards.add(CardData(
              id: card['id'] ?? 'hist-${DateTime.now().millisecondsSinceEpoch}',
              type: card['type'] ?? 'message',
              sessionId: card['sessionId'] ?? histSessionId,
              timestamp: card['timestamp'] ?? 0,
              raw: card,
            ));
          }
          notifyListeners();
        }
        break;

      case 'card':
        final card = msg['card'] as Map<String, dynamic>;
        _cards.add(CardData(
          id: card['id'] ?? 'card-${DateTime.now().millisecondsSinceEpoch}',
          type: card['type'] ?? 'message',
          sessionId: card['sessionId'] ?? '',
          timestamp: card['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          raw: card,
        ));
        notifyListeners();
        break;

      // ── Streaming messages ──────────────────────────────────────────

      case 'stream:start':
        final cardId = msg['cardId'] ?? '';
        final sessionId = msg['sessionId'] ?? '';
        _streamingCards[cardId] = CardData(
          id: cardId,
          type: 'message',
          sessionId: sessionId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          raw: {'text': '', 'streaming': true},
        );
        streamingText[cardId] = '';
        notifyListeners();
        break;

      case 'stream:delta':
        final cardId = msg['cardId'] ?? '';
        final delta = msg['delta'] ?? '';
        final existing = _streamingCards[cardId];
        if (existing != null) {
          final newText = (existing.raw['text'] ?? '') + delta;
          streamingText[cardId] = newText;
          _streamingCards[cardId] = CardData(
            id: existing.id,
            type: 'message',
            sessionId: existing.sessionId,
            timestamp: existing.timestamp,
            raw: Map<String, dynamic>.from(existing.raw)..['text'] = newText,
          );
          notifyListeners();
        }
        break;

      case 'stream:tool_start':
        final cardId = msg['cardId'] ?? '';
        final sessionId = msg['sessionId'] ?? '';
        _cards.add(CardData(
          id: cardId,
          type: 'command',
          sessionId: sessionId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          raw: {
            'command': msg['tool'] ?? '',
            'output': msg['input'] ?? '',
            'streaming': true,
          },
        ));
        notifyListeners();
        break;

      case 'stream:tool_update':
        // Update tool card with summary (file path, command, etc.)
        {
          final cardId = msg['cardId'] ?? '';
          final summary = msg['summary'] ?? '';
          final updIdx = _cards.indexWhere((c) => c.id == cardId);
          if (updIdx >= 0) {
            final old = _cards[updIdx];
            _cards[updIdx] = CardData(
              id: old.id,
              type: old.type,
              sessionId: old.sessionId,
              timestamp: old.timestamp,
              raw: Map<String, dynamic>.from(old.raw)..['output'] = summary,
            );
            notifyListeners();
          }
        }
        break;

      case 'stream:tool_result':
        // Add a tool_result card with the actual content
        {
          final sessionId = msg['sessionId'] ?? '';
          final toolName = msg['toolName'] ?? '';
          final toolId = msg['toolId'] ?? '';
          final content = msg['content'] ?? '';
          final contentType = msg['contentType'] ?? 'other';
          _cards.add(CardData(
            id: 'tr-$toolId-${DateTime.now().millisecondsSinceEpoch}',
            type: 'tool_result',
            sessionId: sessionId,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            raw: {
              'toolName': toolName,
              'content': content,
              'contentType': contentType,
              'truncated': (content as String).length >= 50000,
            },
          ));
          notifyListeners();
        }
        break;

      case 'stream:tool_end':
        // Mark the tool card as done (spinner → checkmark)
        {
          final cardId = msg['cardId'] ?? '';
          final toolName = msg['tool'] ?? '';
          // Find by cardId (tracked), or fallback: last streaming command card with matching tool
          var idx = _cards.indexWhere((c) => c.id == cardId);
          if (idx < 0) {
            idx = _cards.lastIndexWhere(
              (c) => c.type == 'command' && c.isStreaming && c.command == toolName,
            );
          }
          if (idx < 0) {
            idx = _cards.lastIndexWhere((c) => c.type == 'command' && c.isStreaming);
          }
          if (idx >= 0) {
            final old = _cards[idx];
            _cards[idx] = CardData(
              id: old.id,
              type: old.type,
              sessionId: old.sessionId,
              timestamp: old.timestamp,
              raw: Map<String, dynamic>.from(old.raw)..['streaming'] = false,
            );
            notifyListeners();
          }
        }
        break;

      case 'stream:end':
        final cardId = msg['cardId'] ?? '';
        final streaming = _streamingCards.remove(cardId);
        streamingText.remove(cardId);
        if (streaming != null) {
          // Don't add to _cards — the daemon will send the final 'card' message
        }
        // Extract usage info if present
        if (msg['usage'] != null) {
          _lastUsage = UsageInfo.fromJson(msg['usage'] as Map<String, dynamic>);
          _cumulativeCost += _lastUsage!.totalCostUsd;
        }
        notifyListeners();
        break;
    }
  }

  void _autoSelectSession() {
    if (_activeSessionId == null && _sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
    }
  }

  void setActiveSession(String id) {
    _activeSessionId = id;
    notifyListeners();
  }

  /// Select (or clear) the session for a given workspace directory.
  /// Finds an existing session matching that cwd; if found and no local cards
  /// exist, requests card history from the daemon.
  void selectSessionForWorkspace(String? cwd) {
    workspaceCwd = cwd;

    if (cwd == null) {
      _activeSessionId = null;
      notifyListeners();
      return;
    }

    // Find an existing session matching this workspace
    final match = _sessions.where((s) => s.cwd == cwd).firstOrNull;
    if (match != null) {
      _activeSessionId = match.id;
      // If we have no local cards for this session, request history from daemon
      final hasLocalCards = _cards.any((c) => c.sessionId == match.id);
      if (!hasLocalCards) {
        requestHistory(match.id);
      }
    } else {
      _activeSessionId = null;
    }

    notifyListeners();
  }

  /// Request card history from the daemon for a session.
  void requestHistory(String sessionId) {
    _conn.send({'type': 'session:history', 'sessionId': sessionId});
  }

  void createSession(String tool, {String? cwd}) {
    _conn.send({'type': 'session:create', 'tool': tool, 'cwd': cwd});
  }

  void sendCommand(String sessionId, String text) {
    _conn.send({'type': 'command', 'sessionId': sessionId, 'text': text});
  }

  void sendApproval(bool approved) {
    _conn.send({'type': 'approval:response', 'approved': approved});
  }

  void sendPrompt(String text) {
    if (text.trim().isEmpty) return;

    // Add user prompt card locally for immediate display
    if (_activeSessionId != null) {
      _cards.add(CardData(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        type: 'user_prompt',
        sessionId: _activeSessionId!,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        raw: {'text': text},
      ));
      notifyListeners();
    }

    if (_activeSessionId == null) {
      createSession('claude', cwd: workspaceCwd);
      _pendingCommand = text;
    } else {
      sendCommand(_activeSessionId!, text);
    }
  }

  void cancelSession() {
    if (_activeSessionId != null) {
      _conn.send({'type': 'session:cancel', 'sessionId': _activeSessionId!});
    }
  }

  void setSessionConfig({String? model, String? effort, bool? skipPermissions}) {
    if (_activeSessionId == null) return;
    final config = <String, dynamic>{};
    if (model != null) config['model'] = model;
    if (effort != null) config['effort'] = effort;
    if (skipPermissions != null) config['skipPermissions'] = skipPermissions;
    _conn.send({
      'type': 'session:config',
      'sessionId': _activeSessionId!,
      'config': config,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
