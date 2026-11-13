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
    yield const LicenseEntryWithLineBreaks(
      ['Rider–Waite–Smith Tarot'],
      'Public-domain illustrations by Pamela Colman Smith, 1909.\n'
      'https://commons.wikimedia.org/wiki/Category:Rider-Waite_tarot_deck_(Roses_%26_Lilies)\n'
      'Minor Arcana image files sourced from https://arcanebra.com/cards/',
    );
  });
  final dependencies = AppDependencies(await SharedPreferences.getInstance());
  runApp(
    DependencyScope(
      dependencies: dependencies,
      child: FateApp(dependencies: dependencies, playOpening: true),
    ),
  );
  unawaited(dependencies.session.initialize());
}
