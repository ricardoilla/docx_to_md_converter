import 'package:flutter/material.dart';

import 'state/converter_state.dart';
import 'ui/home_page.dart';

/// Root widget: Material 3 with light and dark themes following the system.
class DocFlipApp extends StatelessWidget {
  const DocFlipApp({super.key, required this.state});

  final ConverterState state;

  static ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B6CB0),
      brightness: b,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocFlip',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomePage(state: state),
    );
  }
}
