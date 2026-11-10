import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/dependencies.dart';
import 'app/fate_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans Thai',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL-CJK.txt'));
  });
  final dependencies = AppDependencies(await SharedPreferences.getInstance());
  runApp(
    DependencyScope(
      dependencies: dependencies,
      child: FateApp(dependencies: dependencies),
    ),
  );
  unawaited(dependencies.session.initialize());
}
