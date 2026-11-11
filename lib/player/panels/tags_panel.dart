import 'package:flutter/material.dart';

import '../../presentation/widgets/tag_editor_body.dart';
import '../player_service.dart';
import 'panel_header.dart';

/// Tag editor shown under the video while it keeps playing.
class TagsPanel extends StatelessWidget {
  final PlayerService service;
  const TagsPanel({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(title: 'Tags', onClose: service.closePanel),
        Expanded(child: TagEditorBody(videoId: service.current!.id!)),
      ],
    );
  }
}
