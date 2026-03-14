import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_state.dart';
import '../theme/colors.dart';

void showModelPicker(BuildContext context, SessionState state) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ModelPickerSheet(state: state),
  );
}

class _ModelPickerSheet extends StatefulWidget {
  final SessionState state;

  const _ModelPickerSheet({required this.state});

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  late String _selectedModel;
  late String _selectedEffort;

  static const _models = [
    ('opus', 'Opus'),
    ('sonnet', 'Sonnet'),
    ('haiku', 'Haiku'),
  ];

  static const _efforts = [
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.state.currentModel.isNotEmpty
        ? _normalizeModel(widget.state.currentModel)
        : 'sonnet';
    _selectedEffort = widget.state.currentEffort.isNotEmpty
        ? widget.state.currentEffort
        : 'high';
  }

  String _normalizeModel(String model) {
    if (model.contains('opus')) return 'opus';
    if (model.contains('sonnet')) return 'sonnet';
    if (model.contains('haiku')) return 'haiku';
    return model;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppColors.border),
          left: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32, height: 3,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('MODEL', style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2)),
            ),
          ),

          ...List.generate(_models.length, (i) {
            final (id, name) = _models[i];
            final selected = _selectedModel == id;
            return _option(name, selected, () {
              HapticFeedback.selectionClick();
              setState(() => _selectedModel = id);
              widget.state.setSessionConfig(model: id);
            });
          }),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('EFFORT', style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2)),
            ),
          ),

          ...List.generate(_efforts.length, (i) {
            final (id, name) = _efforts[i];
            final selected = _selectedEffort == id;
            return _option(name, selected, () {
              HapticFeedback.selectionClick();
              setState(() => _selectedEffort = id);
              widget.state.setSessionConfig(effort: id);
            });
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _option(String name, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: AppColors.border) : null,
        ),
        child: Row(
          children: [
            Text(name, style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? AppColors.text : AppColors.textTertiary,
            )),
            const Spacer(),
            if (selected)
              const Icon(Icons.check, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
