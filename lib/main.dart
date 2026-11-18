import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/convert_mode.dart';
import 'state/converter_state.dart';

const _modeKey = 'last_mode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remember the last mode; never fail startup because of preferences.
  SharedPreferences? prefs;
  var mode = ConvertMode.docx2md;
  try {
    prefs = await SharedPreferences.getInstance();
    mode = ConvertMode.values.firstWhere(
      (m) => m.name == prefs!.getString(_modeKey),
      orElse: () => ConvertMode.docx2md,
    );
  } catch (_) {}

  final state = ConverterState(
    initialMode: mode,
    onModeChanged: (m) => prefs?.setString(_modeKey, m.name),
  );
  runApp(DocFlipApp(state: state));
}
