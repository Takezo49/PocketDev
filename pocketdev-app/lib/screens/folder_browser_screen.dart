import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/workspace_state.dart';
import '../theme/colors.dart';

class FolderBrowserScreen extends StatefulWidget {
  final void Function(String path) onSelectFolder;

  const FolderBrowserScreen({super.key, required this.onSelectFolder});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start browsing from common project directories
      final ws = context.read<WorkspaceState>();
      ws.browseTo('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceState>();
    final path = ws.currentBrowsePath;
    final dirs = ws.currentDirs;

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
                  // Navigate up
                  if (path.isNotEmpty && path != '/')
                    GestureDetector(
                      onTap: () {
                        final parent = path.substring(0, path.lastIndexOf('/'));
                        ws.browseTo(parent.isEmpty ? '/' : parent);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.textTertiary),
                      ),
                    ),
                  // Home button
                  GestureDetector(
                    onTap: () => ws.browseTo('/home'),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.home_rounded, size: 18, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

            // Loading
            if (ws.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
                ),
              ),

            // Directory list
            Expanded(
              child: ws.error != null
                  ? Center(
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
                    )
                  : dirs.isEmpty && !ws.loading
                  ? Center(
                      child: Text('Empty directory',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary)),
                    )
                  : ListView.builder(
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
                    ),
            ),

            // Open here button
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
