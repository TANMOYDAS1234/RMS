import 'package:flutter/material.dart';

/// Wraps a tappable icon with [Semantics] + [Tooltip] so screen readers
/// announce a label and a long-press shows the tooltip for sighted users.
///
/// Replaces the pattern:
/// ```
/// GestureDetector(onTap: doX, child: const Icon(Icons.delete))
/// ```
/// which is invisible to assistive tech.
class A11yIconButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;

  const A11yIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 18,
    this.padding = const EdgeInsets.all(6),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Icon(icon, color: color, size: size),
          ),
        ),
      ),
    );
  }
}
