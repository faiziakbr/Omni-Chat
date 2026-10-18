import 'package:flutter/material.dart';

import '../theme.dart';

/// Rounded-square app mark: brand gradient with a chat bubble.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Icon(Icons.forum_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}
