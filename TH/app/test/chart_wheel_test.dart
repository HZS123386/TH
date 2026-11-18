import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fate_app/core/models/calculation.dart';
import 'package:fate_app/features/chart/chart_wheel.dart';

Offset planetCenter(CalculationSnapshot result, int index, double width) {
  final angle =
      (180 + (result.ascendant ?? 0) - result.planets[index].longitude) *
      pi /
      180;
  return Offset(width / 2, width / 2) +
      Offset(cos(angle), sin(angle)) * (width * (.32 + index % 2 * .035));
}

void main() {
  for (final width in [280.0, 320.0, 380.0]) {
    testWidgets('each visible planet center selects itself at width $width', (
      tester,
    ) async {
      final result = CalculationSnapshot.fromJson(
        jsonDecode(
              File(
                'test/fixtures/western_roxy_snapshot.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ChartWheel(
                  result: result,
                  selected: 'sun',
                  onSelected: (key) => selected = key,
                ),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(ChartWheel));
      for (var i = 0; i < result.planets.length; i++) {
        selected = null;
        await tester.tapAt(origin + planetCenter(result, i, width));
        expect(selected, result.planets[i].key);
      }
    });
  }

  testWidgets(
    'small planet accepts nearby taps and ignores empty chart space',
    (tester) async {
      const result = CalculationSnapshot(
        id: 'single-planet',
        engineVersion: 'test',
        rulesetVersion: 'test',
        exactTime: true,
        planets: [ChartPlanet('sun', 0)],
      );
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: ChartWheel(
                  result: result,
                  selected: 'sun',
                  onSelected: (_) => selections++,
                ),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(ChartWheel));
      final center = origin + planetCenter(result, 0, 320);
      for (final offset in [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(-10, 0),
        const Offset(0, 21),
      ]) {
        await tester.tapAt(center + offset);
      }
      expect(selections, 4);
      await tester.tapAt(origin + const Offset(160, 160));
      await tester.tapAt(origin + const Offset(10, 10));
      expect(selections, 4);
    },
  );
}
