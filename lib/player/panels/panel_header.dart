import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PanelHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const PanelHeader({super.key, required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
      ],
    );
  }
}
