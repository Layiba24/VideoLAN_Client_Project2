import 'package:flutter/material.dart';

class VLCTheme {
  static ThemeData get darkTheme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    primaryColor: const Color(0xFFF48B00), // VLC orange
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFF48B00),
      secondary: const Color(0xFFF48B00),
      surface: const Color(0xFF232323),
      background: const Color(0xFF1A1A1A),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: const Color(0xFFF48B00),
      thumbColor: const Color(0xFFF48B00),
      inactiveTrackColor: Colors.grey[800],
    ),
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),
  );
}