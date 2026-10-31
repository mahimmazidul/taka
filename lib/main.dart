import 'package:flutter/material.dart';

import 'app.dart';
import 'store/app_state.dart';

/// Entry point. Everything is local: the SQLite file lives in the app's private
/// directory, so Taka works with the network switched off.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  runApp(const TakaApp());
}
