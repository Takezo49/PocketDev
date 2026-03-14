import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/connection.dart';
import '../services/workspace_state.dart';
import '../theme/colors.dart';
import '../utils/path_utils.dart';
import 'folder_browser_screen.dart';

class WorkspacePickerScreen extends StatefulWidget {
  final void Function(String path, String name) onSelectWorkspace;
  final VoidCallback onBack;

  const WorkspacePickerScreen({
    super.key,
    required this.onSelectWorkspace,
    required this.onBack,
  });

  @override
  State<WorkspacePickerScreen> createState() => _WorkspacePickerScreenState();
}

class _WorkspacePickerScreenState extends State<WorkspacePickerScreen> {
  final _searchCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  bool _showPathInput = false;
  bool _editMode = false;
  final Set<String> _selected = {};

  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _tryRequestProjects();
  }

  void _tryRequestProjects() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requested) return;
      final conn = context.read<DevBoxConnection>();
      if (conn.status == ConnectionStatus.paired) {
        _requested = true;
        context.read<WorkspaceState>().requestProjects();
      } else {
        // Retry until paired
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _tryRequestProjects();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceState>();
    final active = ws.activeProjects;
    final recent = ws.recentProjects;
    final discovered = ws.discoveredProjects;
    final isSearching = ws.searchQuery.isNotEmpty;
    final filtered = ws.filteredProjects;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DotGridBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Container(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_editMode
                          ? '${_selected.length} selected'
                          : 'Select Workspace',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500,
                          color: _editMode ? AppColors.accent : AppColors.text)),
                    ),
                    if (_editMode && _selected.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          for (final path in _selected) {
                            ws.removeWorkspace(path);
                          }
                          setState(() { _selected.clear(); _editMode = false; });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red.withValues(alpha: 0.8)),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _editMode = !_editMode;
                          if (!_editMode) _selected.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          _editMode ? 'Done' : 'Edit',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
                            color: _editMode ? AppColors.accent : AppColors.textTertiary),
                        ),
                      ),
                    ),
                    if (!_editMode)
                      GestureDetector(
                        onTap: () => ws.refreshProjects(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: ws.loading ? AppColors.textFaint : AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => ws.setSearchQuery(v),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
                    ),
                  ),
                ),
              ),

              // Loading indicator
              if (ws.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
                  ),
                ),

              // Project lists
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (isSearching) ...[
                      _sectionLabel('RESULTS', filtered.length),
                      _projectList(filtered),
                    ] else ...[
                      if (active.isNotEmpty) ...[
                        _sectionLabel('ACTIVE SESSIONS', active.length),
                        _projectList(active),
                      ],
                      if (recent.isNotEmpty) ...[
                        _sectionLabel('RECENT', recent.length),
                        _projectList(recent),
                      ],
                      if (discovered.isNotEmpty) ...[
                        _sectionLabel('PROJECTS', discovered.length),
                        _projectList(discovered),
                      ],
                    ],

                    // Bottom actions
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: CustomPaint(
                          size: const Size(double.infinity, 1),
                          painter: DashedLinePainter(color: AppColors.border),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _actionTile(
                              icon: Icons.folder_open_rounded,
                              label: 'Browse folders',
                              onTap: () => _openBrowser(context),
                            ),
                            _actionTile(
                              icon: Icons.edit_rounded,
                              label: 'Enter path',
                              onTap: () => setState(() => _showPathInput = !_showPathInput),
                            ),
                            if (_showPathInput)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _pathCtrl,
                                        autofocus: true,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.text),
                                        decoration: InputDecoration(
                                          hintText: '/home/user/project',
                                          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.textTertiary),
                                          filled: true,
                                          fillColor: AppColors.surface,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                        onSubmitted: (v) {
                                          if (v.trim().isNotEmpty) {
                                            final name = v.trim().split('/').last;
                                            _selectAndNavigate(v.trim(), name);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        final v = _pathCtrl.text.trim();
                                        if (v.isNotEmpty) {
                                          final name = v.split('/').last;
                                          _selectAndNavigate(v, name);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.text,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.bg),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _actionTile(
                              icon: Icons.home_rounded,
                              label: 'Start in home (~)',
                              onTap: () {
                                final conn = context.read<DevBoxConnection>();
                                final home = conn.homedir.isNotEmpty ? conn.homedir : '/home';
                                _selectAndNavigate(home, 'home');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Save workspace to recents (from picker context where provider is available)
  /// then notify parent to navigate to session.
  void _selectAndNavigate(String path, String name) {
    context.read<WorkspaceState>().selectWorkspace(path, name);
    widget.onSelectWorkspace(path, name);
  }

  Widget _sectionLabel(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2.5)),
            ),
            Text('$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.accent.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _projectList(List<ProjectInfo> projects) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final project = projects[i];
            final isSelected = _selected.contains(project.path);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ProjectCard(
                project: project,
                editMode: _editMode,
                isSelected: isSelected,
                onTap: () {
                  if (_editMode) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selected.remove(project.path);
                      } else {
                        _selected.add(project.path);
                      }
                    });
                  } else {
                    HapticFeedback.mediumImpact();
                    _selectAndNavigate(project.path, project.name);
                  }
                },
                onLongPress: _editMode ? null : () {
                  HapticFeedback.heavyImpact();
                  setState(() {
                    _editMode = true;
                    _selected.add(project.path);
                  });
                },
              ),
            );
          },
          childCount: projects.length,
        ),
      ),
    );
  }

  void _showRemoveSheet(BuildContext context, ProjectInfo project) {
    final ws = context.read<WorkspaceState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: AppColors.border),
            left: BorderSide(color: AppColors.border),
            right: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 32, height: 3,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text(project.name,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text)),
                const SizedBox(height: 4),
                Text(project.path,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textTertiary)),
                const SizedBox(height: 20),
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DashedLinePainter(color: AppColors.border),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ws.removeWorkspace(project.path);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.red.withValues(alpha: 0.8)),
                        const SizedBox(width: 12),
                        Text('Remove workspace', style: GoogleFonts.inter(fontSize: 13, color: AppColors.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  void _openBrowser(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<WorkspaceState>(),
          child: FolderBrowserScreen(
            onSelectFolder: (path) {
              Navigator.of(context).pop();
              final name = path.split('/').last;
              _selectAndNavigate(path, name.isEmpty ? path : name);
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }
}

class _ProjectCard extends StatefulWidget {
  final ProjectInfo project;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool editMode;
  final bool isSelected;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    this.onLongPress,
    this.editMode = false,
    this.isSelected = false,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _pressed = false;

  IconData _frameworkIcon(String? framework) {
    switch (framework) {
      case 'node': return Icons.hexagon_rounded;
      case 'flutter': return Icons.flutter_dash_rounded;
      case 'rust': return Icons.settings_rounded;
      case 'go': return Icons.code_rounded;
      case 'python': return Icons.data_object_rounded;
      default: return Icons.folder_rounded;
    }
  }

  String _abbreviatePath(String path) => abbreviatePath(path);

  String _relativeTime(int? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    final minutes = diff ~/ 60000;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    final days = hours ~/ 24;
    return '${days}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final isActive = p.tier == 'active';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.surfaceLight
              : widget.isSelected
                  ? AppColors.accentBg
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _pressed
                ? AppColors.accent.withValues(alpha: 0.25)
                : widget.isSelected
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : isActive
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Checkbox in edit mode, framework icon otherwise
            if (widget.editMode)
              Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: widget.isSelected ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected ? AppColors.accent : AppColors.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check_rounded, size: 14, color: AppColors.bg)
                    : null,
              ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.accentBg,
              ),
              child: Icon(_frameworkIcon(p.framework), size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 12),

            // Name, path, branch
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(p.name,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text),
                          overflow: TextOverflow.ellipsis),
                      ),
                      if (p.branch != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: AppColors.accentBg,
                          ),
                          child: Text(p.branch!,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.accent),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Git status dot
                      Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.dirty ? AppColors.yellow : AppColors.green,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _abbreviatePath(p.path),
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.dirty && p.changedFiles > 0) ...[
                        Text(' · ${p.changedFiles} changed',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right side: status
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.accent.withValues(alpha: 0.12),
                ),
                child: Text('Active',
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.accent)),
              )
            else if (p.lastUsed != null)
              Text(_relativeTime(p.lastUsed),
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textFaint))
            else
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
