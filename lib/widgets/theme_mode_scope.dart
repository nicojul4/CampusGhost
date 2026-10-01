import 'package:flutter/material.dart';

class ThemeModeScope extends InheritedWidget {
  const ThemeModeScope({
    super.key,
    required this.isDark,
    required this.onChanged,
    required super.child,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;

  static ThemeModeScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()!;

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) =>
      isDark != oldWidget.isDark || onChanged != oldWidget.onChanged;
}
