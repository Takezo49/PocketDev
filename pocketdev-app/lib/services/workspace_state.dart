import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connection.dart';

class ProjectInfo {
  final String path;
  final String name;
  final String? branch;
  final String? lastCommitMsg;
  final String? framework;
  final bool dirty;
  final int changedFiles;
  final int? lastUsed;
  final String tier;

  ProjectInfo({
    required this.path,
    required this.name,
    this.branch,
    this.lastCommitMsg,
    this.framework,
    this.dirty = false,
    this.changedFiles = 0,
    this.lastUsed,
    this.tier = 'discovered',
  });

  factory ProjectInfo.fromJson(Map<String, dynamic> json) => ProjectInfo(
        path: json['path'] ?? '',
        name: json['name'] ?? '',
        branch: json['branch'],
        lastCommitMsg: json['lastCommitMsg'],
        framework: json['framework'],
        dirty: json['dirty'] ?? false,
        changedFiles: json['changedFiles'] ?? 0,
        lastUsed: json['lastUsed'],
        tier: json['tier'] ?? 'discovered',
      );
}

class DirEntry {
  final String name;
  final bool hasGit;
  final bool isFile;

  DirEntry({required this.name, required this.hasGit, this.isFile = false});

  factory DirEntry.fromJson(Map<String, dynamic> json) => DirEntry(
        name: json['name'] ?? '',
        hasGit: json['hasGit'] ?? false,
        isFile: json['isFile'] ?? false,
      );
}

class WorkspaceState extends ChangeNotifier {
  final DevBoxConnection _conn;
  StreamSubscription? _sub;

  List<ProjectInfo> _projects = [];
  String? _selectedWorkspace;
  String? _selectedWorkspaceName;
  List<DirEntry> _currentDirs = [];
  String _currentBrowsePath = '';
  bool _loading = false;
  String _searchQuery = '';
  String? _error;

  // Browser search
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  // Last workspace per tool (for fast path on dashboard)
  Map<String, Map<String, String>> _lastWorkspaces = {};
  bool _prefsLoaded = false;

  List<ProjectInfo> get projects => _projects;
  String? get selectedWorkspace => _selectedWorkspace;
  String? get selectedWorkspaceName => _selectedWorkspaceName;
  List<DirEntry> get currentDirs => _currentDirs;
  String get currentBrowsePath => _currentBrowsePath;
  bool get loading => _loading;
  String get searchQuery => _searchQuery;
  String? get error => _error;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get searching => _searching;

  List<ProjectInfo> get activeProjects =>
      _projects.where((p) => p.tier == 'active').toList();

  List<ProjectInfo> get recentProjects =>
      _projects.where((p) => p.tier == 'recent').toList();

  List<ProjectInfo> get discoveredProjects =>
      _projects.where((p) => p.tier == 'discovered').toList();

  List<ProjectInfo> get filteredProjects {
    if (_searchQuery.isEmpty) return _projects;
    final q = _searchQuery.toLowerCase();
    return _projects
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.path.toLowerCase().contains(q))
        .toList();
  }

  WorkspaceState(this._conn) {
    _sub = _conn.messages.listen(_handleMessage);
    _loadPrefs();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'projects:data':
        final list = msg['projects'] as List? ?? [];
        _projects = list
            .map((p) => ProjectInfo.fromJson(p as Map<String, dynamic>))
            .toList();
        _loading = false;
        _error = null;
        notifyListeners();
        break;

      case 'projects:dirs':
        _currentBrowsePath = msg['path'] ?? '';
        final dirs = msg['dirs'] as List? ?? [];
        _currentDirs =
            dirs.map((d) => DirEntry.fromJson(d as Map<String, dynamic>)).toList();
        _loading = false;
        _error = null;
        notifyListeners();
        break;

      case 'projects:search_results':
        final list = msg['results'] as List? ?? [];
        _searchResults = list.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _searching = false;
        notifyListeners();
        break;

      case 'error':
        _loading = false;
        _searching = false;
        _error = msg['message'] ?? 'Unknown error';
        notifyListeners();
        break;
    }
  }

  void requestProjects() {
    _loading = true;
    _error = null;
    notifyListeners();
    _conn.send({'type': 'projects:list'});
    _startLoadingTimeout();
  }

  void refreshProjects() {
    _loading = true;
    _error = null;
    notifyListeners();
    _conn.send({'type': 'projects:refresh'});
    _startLoadingTimeout();
  }

  void browseTo(String path) {
    _loading = true;
    _error = null;
    notifyListeners();
    _conn.send({'type': 'projects:browse', 'path': path});
    _startLoadingTimeout();
  }

  void _startLoadingTimeout() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_loading) {
        _loading = false;
        _error = 'Request timed out — check connection';
        notifyListeners();
      }
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void searchFolders(String query) {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _searching = false;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    _conn.send({'type': 'projects:search', 'query': query.trim()});
  }

  void clearSearchResults() {
    _searchResults = [];
    _searching = false;
    notifyListeners();
  }

  Future<void> selectWorkspace(String path, String name) async {
    _selectedWorkspace = path;
    _selectedWorkspaceName = name;

    // Tell daemon to save + un-exclude
    _conn.send({'type': 'workspace:save', 'path': path, 'name': name});

    // Save last workspace locally for dashboard fast path
    _lastWorkspaces['claude'] = {'path': path, 'name': name};
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_workspaces', jsonEncode(_lastWorkspaces));
  }

  void clearWorkspace() {
    _selectedWorkspace = null;
    _selectedWorkspaceName = null;
    notifyListeners();
  }

  String? getLastWorkspacePath(String toolId) {
    return _lastWorkspaces[toolId]?['path'];
  }

  String? getLastWorkspaceName(String toolId) {
    return _lastWorkspaces[toolId]?['name'];
  }

  bool get prefsLoaded => _prefsLoaded;

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_workspaces');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _lastWorkspaces = map.map((k, v) =>
            MapEntry(k, Map<String, String>.from(v as Map)));
      } catch (_) {}
    }
    // Clean up old exclusion data
    await prefs.remove('excluded_workspaces');
    _prefsLoaded = true;
    notifyListeners();
  }

  void removeWorkspace(String path) {
    // Remove from UI immediately
    _projects.removeWhere((p) => p.path == path);
    _lastWorkspaces.removeWhere((_, v) => v['path'] == path);

    // Tell daemon to delete + exclude permanently
    _conn.send({'type': 'workspace:remove', 'path': path});

    notifyListeners();

    // Persist last workspaces change
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_workspaces', jsonEncode(_lastWorkspaces));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
