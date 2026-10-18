import 'package:flutter/material.dart';

import '../theme.dart';

/// Initials avatar with a green dot while [online] is true. Each name gets its own
/// gradient, so the same person always has the same color.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.online, this.radius = 22});

  final String name;
  final bool? online;
  final double radius;

  static const _palettes = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFFF59E0B), Color(0xFFF97316)],
    [Color(0xFF10B981), Color(0xFF14B8A6)],
    [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
    [Color(0xFFA855F7), Color(0xFFD946EF)],
    [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
    [Color(0xFFEF4444), Color(0xFFF59E0B)],
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  List<Color> get _colors {
    // Stable across runs (String.hashCode isn't guaranteed to be).
    var h = 0;
    for (final c in name.trim().toLowerCase().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palettes[h % _palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = (radius * 0.55).clamp(10.0, 18.0);
    return SizedBox.square(
      dimension: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _colors,
              ),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (online ?? false)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: AppTheme.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
