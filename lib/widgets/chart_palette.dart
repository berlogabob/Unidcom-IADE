import 'package:flutter/material.dart';

Color slotColor(int slot, Brightness brightness) {
  final colors = brightness == Brightness.dark ? _dark : _light;
  return colors[(slot - 1).clamp(0, colors.length - 1)];
}

const _light = [
  Color(0xFF00B49B),
  Color(0xFF2B68B8),
  Color(0xFF7B3F9E),
  Color(0xFFF5A622),
  Color(0xFF16213A),
  Color(0xFF2E7D32),
  Color(0xFFCC2B2B),
  Color(0xFFB4B3B0),
];

const _dark = [
  Color(0xFF33C9B4),
  Color(0xFF5B82D6),
  Color(0xFF9B6BD6),
  Color(0xFFF0B15C),
  Color(0xFF8A94A8),
  Color(0xFF66BB6A),
  Color(0xFFE57373),
  Color(0xFFD4D2CB),
];
