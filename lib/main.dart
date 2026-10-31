import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'store/app_state.dart';

/// Entry point. Everything is local: the SQLite file lives in the app's private
/// directory, so Taka works with the network switched off.
///
/// The first frame is drawn *before* the database is read. Awaiting the load
/// before `runApp` left the native window's colour on screen for the whole
/// query — that blank moment is what looked like a black-screen bug.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Not awaited on purpose; [TakaApp] listens and swaps itself in.
  AppState.instance.load();

  runApp(const TakaApp());
}
