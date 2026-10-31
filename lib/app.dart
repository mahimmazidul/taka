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
        final AppState state = AppState.instance;
        final bool dark = state.settings.darkMode;
        return MaterialApp(
          title: 'Taka',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          // Until the saved setting is known, follow the OS so a dark-mode user
          // never sees a white flash (or the reverse).
          themeMode: state.isLoading
              ? ThemeMode.system
              : (dark ? ThemeMode.dark : ThemeMode.light),
          builder: (BuildContext context, Widget? child) {
            applySystemUiFor(dark ? Brightness.dark : Brightness.light);
            return child ?? const SizedBox.shrink();
          },
          home: state.isLoading ? const _Launch() : const AppShell(),
        );
      },
    );
  }
}

/// The launch colour, matched to the OS brightness so the very first Flutter
/// frame is the same colour as the Android window it replaces.
class _Launch extends StatelessWidget {
  const _Launch();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.launch(MediaQuery.platformBrightnessOf(context)),
      child: const SizedBox.expand(),
    );
  }
}
