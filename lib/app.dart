import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/app_shell.dart';
import 'store/app_state.dart';

/// Root widget. Watches [AppState] for the theme mode only, so the dark-mode
/// switch in Settings repaints the whole tree instantly.
class TakaApp extends StatelessWidget {
  const TakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (BuildContext context, Widget? _) {
        final bool dark = AppState.instance.settings.darkMode;
        return MaterialApp(
          title: 'Taka',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (BuildContext context, Widget? child) {
            applySystemUiFor(dark ? Brightness.dark : Brightness.light);
            return child ?? const SizedBox.shrink();
          },
          home: const AppShell(),
        );
      },
    );
  }
}
