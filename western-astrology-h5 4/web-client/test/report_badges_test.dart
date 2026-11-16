import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/app/languages.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/ui/jy_components.dart';
import 'package:fate_h5/ui/theme.dart';
import 'support.dart';

void main() {
  testWidgets(
    'all nine languages retain the six original benefit illustrations and colours',
    (tester) async {
      final data = translations();
      for (final language in h5Languages.map((option) => option.$1)) {
        await tester.pumpWidget(
          MaterialApp(
            theme: h5Theme(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: ReportBadges(copy: Copy(data, language)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final illustrations = tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .map((picture) => picture.bytesLoader)
            .whereType<SvgAssetLoader>()
            .map((loader) => loader.assetName);
        expect(illustrations, [
          for (final name in [
            'natal',
            'career',
            'finance',
            'love',
            'opportunities',
            'advice',
          ])
            'assets/images/badges/$name.svg',
        ], reason: language);
        final colours = tester
            .widgetList<Container>(find.byType(Container))
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.gradient)
            .whereType<RadialGradient>()
            .map((gradient) => gradient.colors.first)
            .toSet();
        expect(colours, hasLength(6), reason: language);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'chapter cards adapt to narrow screens and keep navigation in all nine languages',
    (tester) async {
      const keys = ['natal', 'career', 'wealth', 'love', 'risk', 'plan'];
      final data = translations();
      for (final width in [260.0, 220.0]) {
        for (final language in h5Languages.map((option) => option.$1)) {
          final tapped = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: h5Theme(),
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    child: ReportBadges(
                      copy: Copy(data, language),
                      locked: false,
                      western: true,
                      onTap: tapped.add,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final first = tester.getTopLeft(
            find.byKey(const ValueKey('report-section-natal')),
          );
          final second = tester.getTopLeft(
            find.byKey(const ValueKey('report-section-career')),
          );
          if (width >= 250) {
            expect(first.dy, second.dy);
            expect(second.dx, greaterThan(first.dx));
          } else {
            expect(first.dx, second.dx);
            expect(second.dy, greaterThan(first.dy));
          }
          for (final key in keys) {
            final card = find.byKey(ValueKey('report-section-$key'));
            await tester.ensureVisible(card);
            await tester.tap(card);
          }
          expect(tapped, keys, reason: '$language at $width');
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
