import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/workspace_state.dart';
import '../theme/colors.dart';
import '../utils/path_utils.dart';

class FolderBrowserScreen extends StatefulWidget {
  final void Function(String path) onSelectFolder;

  const FolderBrowserScreen({super.key, required this.onSelectFolder});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = context.read<WorkspaceState>();
      ws.browseTo('/home');
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      context.read<WorkspaceState>().clearSearchResults();
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<WorkspaceState>().searchFolders(query);
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _isSearching = false);
    context.read<WorkspaceState>().clearSearchResults();
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceState>();
    final path = ws.currentBrowsePath;
    final dirs = ws.currentDirs;
    final results = ws.searchResults;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with path
            Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      path.isEmpty ? '/' : path,
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (path.isNotEmpty && path != '/')
                    GestureDetector(
                      onTap: () {
                        _clearSearch();
                        final parent = path.substring(0, path.lastIndexOf('/'));
                        ws.browseTo(parent.isEmpty ? '/' : parent);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.textTertiary),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      _clearSearch();
                      ws.browseTo('/home');
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.home_rounded, size: 18, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Search folders...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary),
                  suffixIcon: _isSearching
                      ? GestureDetector(
                          onTap: _clearSearch,
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
                  ),
                ),
              ),
            ),

            // Loading
            if (ws.loading || ws.searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
                ),
              ),

            // Content: search results or directory listing
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(ws, results)
                  : _buildDirectoryListing(ws, path, dirs),
            ),

            // Open here button (only when not searching)
            if (!_isSearching)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                ),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onSelectFolder(path);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('Open here',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.bg)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(WorkspaceState ws, List<Map<String, dynamic>> results) {
    if (results.isEmpty && !ws.searching) {
      return Center(
        child: Text(
          _searchCtrl.text.isEmpty ? '' : 'No matches found',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final r = results[i];
        final rPath = r['path'] as String;
        final rName = r['name'] as String;
        final hasGit = r['hasGit'] as bool? ?? false;
        final isFile = r['isFile'] as bool? ?? false;
        if (isFile) {
          return _SearchFileTile(name: rName, path: rPath);
        }
        return _SearchResultTile(
          name: rName,
          path: rPath,
          hasGit: hasGit,
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onSelectFolder(rPath);
          },
          onNavigate: () {
            HapticFeedback.selectionClick();
            _clearSearch();
            ws.browseTo(rPath);
          },
        );
      },
    );
  }

  Widget _buildDirectoryListing(WorkspaceState ws, String path, List<DirEntry> dirs) {
    if (ws.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 24, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(ws.error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ws.browseTo(path.isEmpty ? '/home' : path),
              child: Text('Retry', style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
            ),
          ],
        ),
      );
    }
    if (dirs.isEmpty && !ws.loading) {
      return Center(
        child: Text('Empty directory',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: dirs.length,
      itemBuilder: (_, i) {
        final dir = dirs[i];
        if (dir.isFile) {
          return _FileTile(dir: dir);
        }
        return _DirTile(
          dir: dir,
          onTap: () {
            HapticFeedback.selectionClick();
            final newPath = path == '/' ? '/${dir.name}' : '$path/${dir.name}';
            ws.browseTo(newPath);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

class _SearchResultTile extends StatelessWidget {
  final String name;
  final String path;
  final bool hasGit;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  const _SearchResultTile({
    required this.name,
    required this.path,
    required this.hasGit,
    required this.onTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, size: 18,
              color: hasGit ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                      color: hasGit ? AppColors.text : AppColors.textSecondary)),
                  Text(abbreviatePath(path),
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textTertiary)),
                ],
              ),
            ),
            if (hasGit)
              Container(
                width: 5, height: 5,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
              ),
            GestureDetector(
              onTap: onNavigate,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFileTile extends StatelessWidget {
  final String name;
  final String path;

  const _SearchFileTile({required this.name, required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, size: 16, color: AppColors.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary)),
                Text(abbreviatePath(path),
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirTile extends StatelessWidget {
  final DirEntry dir;
  final VoidCallback onTap;

  const _DirTile({required this.dir, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, size: 18,
              color: dir.hasGit ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dir.name,
                style: GoogleFonts.inter(fontSize: 14,
                  color: dir.hasGit ? AppColors.text : AppColors.textSecondary)),
            ),
            if (dir.hasGit)
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final DirEntry dir;

  const _FileTile({required this.dir});

  IconData _fileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code_rounded;
    if (name.endsWith('.ts') || name.endsWith('.js') || name.endsWith('.tsx') || name.endsWith('.jsx')) return Icons.javascript_rounded;
    if (name.endsWith('.py')) return Icons.code_rounded;
    if (name.endsWith('.rs')) return Icons.settings_rounded;
    if (name.endsWith('.go')) return Icons.code_rounded;
    if (name.endsWith('.json') || name.endsWith('.yaml') || name.endsWith('.yml') || name.endsWith('.toml')) return Icons.data_object_rounded;
    if (name.endsWith('.md') || name.endsWith('.txt')) return Icons.description_rounded;
    if (name.endsWith('.lock')) return Icons.lock_rounded;
    if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.svg')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(_fileIcon(dir.name), size: 16, color: AppColors.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(dir.name,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}
