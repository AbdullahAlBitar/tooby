import 'package:flutter/material.dart';

/// A circular icon button used in the mini-player controls overlay.
class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool animated;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  const CircleButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.animated = false,
    this.size = 52.0,
    this.backgroundColor = Colors.black45,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: iconColor,
      size: size,
      key: ValueKey(icon),
    );

    return Container(
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
        onPressed: onPressed,
        icon: animated
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: iconWidget,
              )
            : iconWidget,
      ),
    );
  }
}
