import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/ui/jy_components.dart';

class InterruptedArtwork extends CachingAssetBundle {
  int remainingFailures = 0, requests = 0;
  int manifestFailures = 0;
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin' && manifestFailures-- > 0) {
      throw StateError('Interrupted asset manifest');
    }
    if (key == 'assets/images/fate-brand.png') {
      requests++;
      if (remainingFailures-- > 0) {
        throw StateError('Interrupted image request');
      }
    }
    return rootBundle.load(key);
  }
}

void main() {
  Widget artwork(InterruptedArtwork bundle) => DefaultAssetBundle(
    bundle: bundle,
    child: const MaterialApp(
      home: Center(
        child: SizedBox(
          width: 240,
          height: 160,
          child: FateImage('assets/images/fate-brand.png'),
        ),
      ),
    ),
  );

  testWidgets(
    'artwork recovers when manifest resolution also fails during a retry',
    (tester) async {
      final bundle = InterruptedArtwork()..manifestFailures = 4;
      await tester.pumpWidget(artwork(bundle));
      await tester.pumpAndSettle();
      expect(bundle.requests, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'artwork recovers after interrupted requests without shifting size',
    (tester) async {
      final bundle = InterruptedArtwork()..remainingFailures = 2;
      await tester.pumpWidget(artwork(bundle));
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(FateImage));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(bundle.requests, 3);
      expect(tester.getSize(find.byType(FateImage)), before);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'artwork stops retrying, permits a manual retry, and disposes cleanly',
    (tester) async {
      final bundle = InterruptedArtwork()..remainingFailures = 20;
      await tester.pumpWidget(artwork(bundle));
      await tester.pumpAndSettle();
      for (final delay in [500, 1000, 1500]) {
        await tester.pump(Duration(milliseconds: delay));
        await tester.pumpAndSettle();
      }
      expect(bundle.requests, 4);
      expect(find.byType(IconButton), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(bundle.requests, 4);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pump();
      expect(bundle.requests, 5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(bundle.requests, 5);
      expect(tester.takeException(), isNull);
    },
  );
}
