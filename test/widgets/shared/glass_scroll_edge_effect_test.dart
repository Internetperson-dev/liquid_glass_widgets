import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/widgets/shared/glass_scroll_edge_effect.dart';

void main() {
  group('GlassScrollEdgeEffect', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            child: ListView(
              children: const [Text('Hello')],
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('wraps child in Stack with fade overlays when fading',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            child: ListView(
              children: const [Text('Content')],
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(GlassScrollEdgeEffect),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('skips Stack when both fades disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            fadeTop: false,
            fadeBottom: false,
            child: ListView(
              children: const [Text('No Fade')],
            ),
          ),
        ),
      );

      // Should not have a Stack
      expect(
        find.descendant(
          of: find.byType(GlassScrollEdgeEffect),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });

    test('defaults are correct', () {
      final widget = GlassScrollEdgeEffect(
        child: const SizedBox(),
      );

      expect(widget.topFadeHeight, equals(100.0));
      expect(widget.bottomFadeHeight, equals(60.0));
      expect(widget.fadeTop, isTrue);
      expect(widget.fadeBottom, isTrue);
      expect(widget.style, equals(GlassScrollEdgeStyle.soft));
    });

    test('GlassScrollEdgeStyle has soft and hard values', () {
      expect(GlassScrollEdgeStyle.values, hasLength(2));
      expect(GlassScrollEdgeStyle.values, contains(GlassScrollEdgeStyle.soft));
      expect(GlassScrollEdgeStyle.values, contains(GlassScrollEdgeStyle.hard));
    });

    testWidgets('top-only fade renders one overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            fadeTop: true,
            fadeBottom: false,
            child: ListView(
              children: const [Text('Top only')],
            ),
          ),
        ),
      );

      // One Stack and one Positioned for the top fade
      expect(
        find.descendant(
          of: find.byType(GlassScrollEdgeEffect),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bottom-only fade renders one overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            fadeTop: false,
            fadeBottom: true,
            child: ListView(
              children: const [Text('Bottom only')],
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(GlassScrollEdgeEffect),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hard style renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            style: GlassScrollEdgeStyle.hard,
            child: ListView(
              children: const [Text('Hard edge')],
            ),
          ),
        ),
      );

      expect(find.text('Hard edge'), findsOneWidget);
    });

    testWidgets('custom fade heights render without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScrollEdgeEffect(
            topFadeHeight: 200,
            bottomFadeHeight: 120,
            child: ListView(
              children: const [Text('Custom heights')],
            ),
          ),
        ),
      );

      expect(find.text('Custom heights'), findsOneWidget);
    });

    // ── New code paths from 0.17.0 refactor ─────────────────────────────────
    // Covers: bottom edge positioning (isTop: false → bottom: 0),
    // _buildColorOverlay with explicit fadeColor, and the hasTexture=false
    // branch (outside GlassPage, no captured image → colour overlay).

    testWidgets(
        'bottom-only fade with explicit fadeColor exercises _buildColorOverlay',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: GlassScrollEdgeEffect(
              fadeTop: false,
              fadeBottom: true,
              fadeColor:
                  const Color(0xFFFFFFFF), // explicit → skips theme lookup
              child: ListView(
                children: const [Text('Bottom only with color')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassScrollEdgeEffect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'both fades enabled exercises top and bottom positioning branches',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: GlassScrollEdgeEffect(
              fadeTop: true,
              fadeBottom: true,
              child: ListView(
                children: const [Text('Both fades')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassScrollEdgeEffect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'bottom fade with hard style exercises style branch in _buildColorOverlay',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: GlassScrollEdgeEffect(
              fadeTop: false,
              fadeBottom: true,
              style: GlassScrollEdgeStyle.hard,
              fadeColor: const Color(0xFFF5F5F5),
              child: ListView(
                children: const [Text('Bottom hard')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassScrollEdgeEffect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'both fades with custom fadeColor covers both top and bottom overlay builds',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: GlassScrollEdgeEffect(
              fadeTop: true,
              fadeBottom: true,
              fadeColor: const Color(0xFFEEEEEE),
              topFadeHeight: 80,
              bottomFadeHeight: 60,
              child: ListView(
                children:
                    List.generate(20, (i) => Text('Item $i', key: ValueKey(i))),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassScrollEdgeEffect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
