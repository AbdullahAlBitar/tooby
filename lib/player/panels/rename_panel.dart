import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../services/video_actions.dart';
import '../player_service.dart';
import 'panel_header.dart';

/// Rename the current video's file without leaving the player.
class RenamePanel extends ConsumerStatefulWidget {
  final PlayerService service;
  const RenamePanel({super.key, required this.service});

  @override
  ConsumerState<RenamePanel> createState() => _RenamePanelState();
}

class _RenamePanelState extends ConsumerState<RenamePanel> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.service.current?.title ?? '');
  bool _saving = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final video = widget.service.current;
    if (video == null || _saving) return;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    if (title == video.title) {
      widget.service.closePanel();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await renameVideoFlow(ref, video, title);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
      _done = error == null;
    });
    if (error == null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) widget.service.closePanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(title: 'Rename video', onClose: widget.service.closePanel),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'File name',
              helperText: 'Renames the file on your device too',
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
              ],
            ),
          ),
        if (_done)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Renamed'),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.service.closePanel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
