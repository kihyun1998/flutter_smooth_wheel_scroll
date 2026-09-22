import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

const _duration = Duration(milliseconds: 160);
const _itemExtent = 50.0;
const _viewport = 600.0;

const _motions = <String, WheelMotion>{
  'spring': WheelMotion.spring(duration: _duration),
  'curve': WheelMotion.curve(duration: _duration),
  'lerp': WheelMotion.lerp(timeConstant: Duration(milliseconds: 40)),
};

const _physics = <String, ScrollPhysics>{
  'clamping': ClampingScrollPhysics(),
  'bouncing': BouncingScrollPhysics(),
};

Widget _list(
  ScrollController controller, {
  int itemCount = 100,
  Key? key,
  ScrollPhysics? physics,
  VoidCallback? onTapItem,
}) {
  return Directionality(
    key: key,
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        height: _viewport,
        child: ListView.builder(
          controller: controller,
          physics: physics,
          itemExtent: _itemExtent,
          itemCount: itemCount,
          itemBuilder: (_, i) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapItem,
            child: Text('$i'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _wheel(WidgetTester tester, double dy, {Offset? at}) async {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: at ?? tester.getCenter(find.byType(Scrollable).first),
      scrollDelta: Offset(0, dy),
    ),
  );
  await tester.pump();
}

const _innerKey = Key('inner');

/// A vertical outer list with a 300 px inner list of 8 items (max extent 100)
/// after 4 outer items. [wrap] puts scroll views between the two.
Widget _nested({
  Key? key,
  required ScrollController outer,
  required ScrollController inner,
  bool outerReverse = false,
  bool innerReverse = false,
  Widget Function(Widget inner)? wrap,
}) {
  final innerList = SizedBox(
    key: _innerKey,
    height: 300,
    child: ListView.builder(
      controller: inner,
      reverse: innerReverse,
      itemExtent: _itemExtent,
      itemCount: 8,
      itemBuilder: (_, i) => Text('inner $i'),
    ),
  );
  return Directionality(
    key: key,
    textDirection: TextDirection.ltr,
    child: ListView(
      controller: outer,
      reverse: outerReverse,
      children: [
        for (var i = 0; i < 4; i++)
          SizedBox(height: _itemExtent, child: Text('before $i')),
        wrap == null ? innerList : wrap(innerList),
        for (var i = 0; i < 40; i++)
          SizedBox(height: _itemExtent, child: Text('after $i')),
      ],
    ),
  );
}

void main() {
  test('the default motion is a 400 ms spring without bounce', () {
    final motion = SmoothScrollController().motion as SpringWheelMotion;
    expect(motion.duration, const Duration(milliseconds: 400));
    expect(motion.bounce, 0.0);
  });

  test('each motion has the chosen defaults', () {
    const curve = WheelMotion.curve() as CurveWheelMotion;
    expect(curve.duration, const Duration(milliseconds: 400));
    expect(curve.curve, Curves.easeOutCubic);

    const lerp = WheelMotion.lerp() as LerpWheelMotion;
    expect(lerp.timeConstant, const Duration(milliseconds: 60));
  });

  for (final MapEntry(key: name, value: motion) in _motions.entries) {
    group(name, () {
      testWidgets('animates to the target instead of jumping', (tester) async {
        final controller = SmoothScrollController(motion: motion);
        await tester.pumpWidget(_list(controller));

        await _wheel(tester, 60);
        expect(controller.offset, 0);

        await tester.pump(_duration ~/ 2);
        expect(controller.offset, greaterThan(0));
        expect(controller.offset, lessThan(60));

        await tester.pumpAndSettle();
        expect(controller.offset, 60);
      });

      testWidgets('accumulates wheel input during the animation', (
        tester,
      ) async {
        final controller = SmoothScrollController(motion: motion);
        await tester.pumpWidget(_list(controller));

        await _wheel(tester, 60);
        await tester.pump(const Duration(milliseconds: 20));
        await _wheel(tester, 60);
        await tester.pump(const Duration(milliseconds: 20));
        await _wheel(tester, 60);
        await tester.pumpAndSettle();

        expect(controller.offset, 180);
      });

      for (final MapEntry(key: physicsName, value: physics)
          in _physics.entries) {
        testWidgets('does not pass the scroll extent with $physicsName '
            'physics', (tester) async {
          final controller = SmoothScrollController(motion: motion);
          await tester.pumpWidget(
            _list(controller, itemCount: 14, physics: physics),
          );
          final max = controller.position.maxScrollExtent;
          expect(max, 100);

          for (var i = 0; i < 5; i++) {
            await _wheel(tester, 60);
            expect(controller.offset, lessThanOrEqualTo(max));
          }
          await tester.pumpAndSettle();
          expect(controller.offset, max);

          for (var i = 0; i < 5; i++) {
            await _wheel(tester, -60);
            expect(controller.offset, greaterThanOrEqualTo(0));
          }
          await tester.pumpAndSettle();
          expect(controller.offset, 0);
        });
      }

      testWidgets('items stay tappable during the motion', (tester) async {
        var taps = 0;
        final controller = SmoothScrollController(motion: motion);
        await tester.pumpWidget(_list(controller, onTapItem: () => taps++));

        await _wheel(tester, 60);
        await tester.pump(_duration ~/ 4);
        await tester.tap(find.text('5'));

        expect(taps, 1);
      });

      testWidgets('wheel input at a clamped target leaves the motion as is', (
        tester,
      ) async {
        Future<double> run(Key key, {required bool extraWheel}) async {
          final controller = SmoothScrollController(motion: motion);
          await tester.pumpWidget(_list(controller, itemCount: 14, key: key));
          await _wheel(tester, 200);
          await tester.pump(_duration ~/ 2);
          if (extraWheel) await _wheel(tester, 60);
          await tester.pump(_duration ~/ 2);
          return controller.offset;
        }

        final withExtra = await run(const ValueKey(1), extraWheel: true);
        final without = await run(const ValueKey(2), extraWheel: false);

        expect(withExtra, without);
      });

      testWidgets('wheel input during a programmatic animation starts from the '
          'current position', (tester) async {
        final controller = SmoothScrollController(motion: motion);
        await tester.pumpWidget(_list(controller));

        await _wheel(tester, 60);
        await tester.pumpAndSettle();
        expect(controller.offset, 60);

        controller.animateTo(
          2000,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final before = controller.offset;
        expect(before, greaterThan(1000));

        await _wheel(tester, 60);
        await tester.pumpAndSettle();

        expect(controller.offset, before + 60);
      });

      testWidgets('reports the user scroll direction while animating', (
        tester,
      ) async {
        final controller = SmoothScrollController(motion: motion);
        await tester.pumpWidget(_list(controller));

        await _wheel(tester, 60);
        await tester.pump(_duration ~/ 2);
        expect(
          controller.position.userScrollDirection,
          ScrollDirection.reverse,
        );

        await tester.pumpAndSettle();
        expect(controller.position.userScrollDirection, ScrollDirection.idle);

        await _wheel(tester, -60);
        await tester.pump(_duration ~/ 2);
        expect(
          controller.position.userScrollDirection,
          ScrollDirection.forward,
        );
      });

      testWidgets(
        'the outer list receives the wheel once the inner one is at its end',
        (tester) async {
          final outer = SmoothScrollController(motion: motion);
          final inner = SmoothScrollController(motion: motion);
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: ListView(
                controller: outer,
                children: [
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      controller: inner,
                      itemExtent: _itemExtent,
                      itemCount: 8,
                      itemBuilder: (_, i) => Text('inner $i'),
                    ),
                  ),
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: _itemExtent, child: Text('outer $i')),
                ],
              ),
            ),
          );
          final innerCenter = tester.getCenter(find.byType(Scrollable).at(1));

          await _wheel(tester, 60, at: innerCenter);
          await tester.pumpAndSettle();
          expect(inner.offset, 60);
          expect(outer.offset, 0);

          await _wheel(tester, 60, at: innerCenter);
          await tester.pumpAndSettle();
          expect(inner.offset, inner.position.maxScrollExtent);
          expect(outer.offset, 0);

          await _wheel(tester, 60, at: innerCenter);
          await tester.pumpAndSettle();
          expect(inner.offset, inner.position.maxScrollExtent);
          expect(outer.offset, 60);
        },
      );

      testWidgets(
        'the outer list receives the wheel during a motion that already aims '
        'at the inner end',
        (tester) async {
          final outer = ScrollController();
          final inner = SmoothScrollController(motion: motion);
          await tester.pumpWidget(_nested(outer: outer, inner: inner));
          final at = tester.getCenter(find.byKey(_innerKey));

          await _wheel(tester, 1000, at: at);
          await tester.pump(const Duration(milliseconds: 20));
          expect(inner.offset, lessThan(inner.position.maxScrollExtent));

          await _wheel(tester, 60, at: at);
          expect(outer.offset, 60);

          await tester.pumpAndSettle();
          expect(inner.offset, inner.position.maxScrollExtent);
          expect(outer.offset, 60);
        },
      );
    });
  }

  group('wheel input the inner list cannot use during a motion', () {
    /// Sends [first] to the inner list, then [second] 20 ms later, and returns
    /// the offsets once everything settles. Run once with a [ScrollController]
    /// inner list as Flutter's own behaviour, and once with a smooth one.
    Future<List<({double outer, double inner})>> both(
      WidgetTester tester, {
      double first = 1000,
      double second = 60,
      double outerOffset = 0,
      double innerOffset = 0,
      bool outerReverse = false,
      bool innerReverse = false,
      Widget Function(Widget inner)? wrap,
    }) async {
      final results = <({double outer, double inner})>[];
      for (final smooth in [false, true]) {
        final outer = ScrollController(initialScrollOffset: outerOffset);
        final inner = smooth
            ? SmoothScrollController(
                motion: _motions['spring']!,
                initialScrollOffset: innerOffset,
              )
            : ScrollController(initialScrollOffset: innerOffset);
        await tester.pumpWidget(
          _nested(
            key: ValueKey(smooth),
            outer: outer,
            inner: inner,
            outerReverse: outerReverse,
            innerReverse: innerReverse,
            wrap: wrap,
          ),
        );
        final at = tester.getCenter(find.byKey(_innerKey));
        await _wheel(tester, first, at: at);
        await tester.pump(const Duration(milliseconds: 20));
        await _wheel(tester, second, at: at);
        await tester.pumpAndSettle();
        results.add((outer: outer.offset, inner: inner.offset));
      }
      return results;
    }

    testWidgets('passes nothing on when it reaches the inner end part way', (
      tester,
    ) async {
      final [flutter, smooth] = await both(tester, first: 90);
      expect(flutter, (outer: 0.0, inner: 100.0));
      expect(smooth, flutter);
    });

    testWidgets('skips an enclosing scroll view on the other axis', (
      tester,
    ) async {
      final [flutter, smooth] = await both(
        tester,
        wrap: (inner) => SizedBox(
          height: 300,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SizedBox(width: 800, child: inner),
              const SizedBox(width: 800),
            ],
          ),
        ),
      );
      expect(flutter, (outer: 60.0, inner: 100.0));
      expect(smooth, flutter);
    });

    for (final (name, offset, physics) in [
      ('is at its end', 100.0, null),
      ('does not scroll', 0.0, const NeverScrollableScrollPhysics()),
    ]) {
      testWidgets('skips an enclosing scroll view that $name', (tester) async {
        final [flutter, smooth] = await both(
          tester,
          wrap: (inner) => SizedBox(
            height: 300,
            child: ListView(
              controller: ScrollController(initialScrollOffset: offset),
              physics: physics,
              children: [inner, const SizedBox(height: 100)],
            ),
          ),
        );
        expect(flutter, (outer: 60.0, inner: 100.0));
        expect(smooth, flutter);
      });
    }

    testWidgets('goes toward the start past an enclosing scroll view at its '
        'start', (tester) async {
      final [flutter, smooth] = await both(
        tester,
        first: -1000,
        second: -60,
        outerOffset: 100,
        innerOffset: 100,
        wrap: (inner) => SizedBox(
          height: 300,
          child: ListView(children: [inner, const SizedBox(height: 100)]),
        ),
      );
      expect(flutter, (outer: 40.0, inner: 0.0));
      expect(smooth, flutter);
    });

    testWidgets('keeps its direction in a reversed inner list', (tester) async {
      final [flutter, smooth] = await both(
        tester,
        first: -1000,
        second: -60,
        outerOffset: 100,
        innerReverse: true,
      );
      expect(flutter, (outer: 40.0, inner: 100.0));
      expect(smooth, flutter);
    });

    testWidgets('keeps its direction in a reversed outer list', (tester) async {
      final [flutter, smooth] = await both(
        tester,
        outerOffset: 100,
        outerReverse: true,
      );
      expect(flutter, (outer: 40.0, inner: 100.0));
      expect(smooth, flutter);
    });

    testWidgets('leaves a scroll view behind an overlay alone', (tester) async {
      final results = <({double outer, double inner})>[];
      for (final smooth in [false, true]) {
        final outer = ScrollController();
        final inner = smooth
            ? SmoothScrollController(motion: _motions['spring']!)
            : ScrollController();
        final popup = OverlayPortalController()..show();
        await tester.pumpWidget(
          Directionality(
            key: ValueKey(smooth),
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => _nested(
                    outer: outer,
                    inner: inner,
                    wrap: (innerList) => OverlayPortal(
                      controller: popup,
                      overlayChildBuilder: (_) => Positioned(
                        left: 0,
                        top: 0,
                        width: 400,
                        child: innerList,
                      ),
                      child: const SizedBox(height: 300),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final at = tester.getCenter(find.byKey(_innerKey));
        await _wheel(tester, 1000, at: at);
        await tester.pump(const Duration(milliseconds: 20));
        await _wheel(tester, 60, at: at);
        await tester.pumpAndSettle();
        results.add((outer: outer.offset, inner: inner.offset));
      }
      final [flutter, smooth] = results;
      expect(flutter, (outer: 0.0, inner: 100.0));
      expect(smooth, flutter);
    });

    testWidgets('passes through an enclosing smooth list that already aims at '
        'its end', (tester) async {
      final results = <({double outer, double middle, double inner})>[];
      for (final smooth in [false, true]) {
        ScrollController controller() => smooth
            ? SmoothScrollController(motion: _motions['spring']!)
            : ScrollController();
        final outer = ScrollController();
        final middle = controller();
        final inner = controller();
        await tester.pumpWidget(
          _nested(
            key: ValueKey(smooth),
            outer: outer,
            inner: inner,
            wrap: (innerList) => SizedBox(
              height: 300,
              child: ListView(
                controller: middle,
                children: [innerList, const SizedBox(height: 100)],
              ),
            ),
          ),
        );
        final at = tester.getCenter(find.byKey(_innerKey));
        await _wheel(tester, 1000, at: at);
        await tester.pump(const Duration(milliseconds: 20));
        await _wheel(tester, 1000, at: at);
        await tester.pump(const Duration(milliseconds: 20));
        if (smooth) {
          expect(middle.offset, lessThan(middle.position.maxScrollExtent));
        }
        await _wheel(tester, 60, at: at);
        await tester.pumpAndSettle();
        results.add((
          outer: outer.offset,
          middle: middle.offset,
          inner: inner.offset,
        ));
      }
      final [flutter, smooth] = results;
      expect(flutter, (outer: 60.0, middle: 100.0, inner: 100.0));
      expect(smooth, flutter);
    });

    testWidgets('moves a smooth outer list with its own motion', (
      tester,
    ) async {
      final outer = SmoothScrollController(motion: _motions['spring']!);
      final inner = SmoothScrollController(motion: _motions['spring']!);
      await tester.pumpWidget(_nested(outer: outer, inner: inner));
      final at = tester.getCenter(find.byKey(_innerKey));

      await _wheel(tester, 1000, at: at);
      await tester.pump(const Duration(milliseconds: 20));
      await _wheel(tester, 60, at: at);
      await tester.pump(_duration ~/ 4);
      expect(outer.offset, greaterThan(0));
      expect(outer.offset, lessThan(60));

      await tester.pumpAndSettle();
      expect(outer.offset, 60);
      expect(inner.offset, 100);
    });
  });

  testWidgets('a spring keeps its velocity when the target moves', (
    tester,
  ) async {
    const step = Duration(milliseconds: 1);
    final controller = SmoothScrollController(
      motion: const WheelMotion.spring(duration: _duration),
    );
    await tester.pumpWidget(_list(controller));

    await _wheel(tester, 60);
    await tester.pump(_duration ~/ 4);
    final a = controller.offset;
    await tester.pump(step);
    final before = controller.offset - a;

    await _wheel(tester, 60);
    final b = controller.offset;
    await tester.pump(step);
    final after = controller.offset - b;

    expect(before, greaterThan(0));
    expect(after, closeTo(before, before * 0.1));
  });

  for (final MapEntry(key: physicsName, value: physics) in _physics.entries) {
    testWidgets('a spring with bounce stays within the scroll extent with '
        '$physicsName physics', (tester) async {
      final controller = SmoothScrollController(
        motion: const WheelMotion.spring(duration: _duration, bounce: 0.5),
      );
      await tester.pumpWidget(
        _list(controller, itemCount: 14, physics: physics),
      );
      final max = controller.position.maxScrollExtent;

      await _wheel(tester, 90);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(controller.offset, lessThanOrEqualTo(max));
      }
      await tester.pumpAndSettle();
      expect(controller.offset, lessThanOrEqualTo(max));
    });
  }

  testWidgets('a lerp covers the same distance at any frame rate', (
    tester,
  ) async {
    Future<double> run(Key key, Duration frame, int frames) async {
      final controller = SmoothScrollController(
        motion: const WheelMotion.lerp(
          timeConstant: Duration(milliseconds: 40),
        ),
      );
      await tester.pumpWidget(_list(controller, key: key));
      await _wheel(tester, 300);
      for (var i = 0; i < frames; i++) {
        await tester.pump(frame);
      }
      return controller.offset;
    }

    final at60Hz = await run(
      const ValueKey(60),
      const Duration(milliseconds: 16),
      6,
    );
    final at120Hz = await run(
      const ValueKey(120),
      const Duration(milliseconds: 8),
      12,
    );

    expect(at60Hz, greaterThan(0));
    expect(at120Hz, closeTo(at60Hz, 1e-6));
  });

  for (final motion in const [
    WheelMotion.spring(duration: Duration.zero),
    WheelMotion.curve(duration: Duration.zero),
    WheelMotion.lerp(timeConstant: Duration.zero),
  ]) {
    testWidgets('a zero ${motion.runtimeType} jumps', (tester) async {
      final controller = SmoothScrollController(motion: motion);
      await tester.pumpWidget(_list(controller));

      await _wheel(tester, 60);

      expect(controller.offset, 60);
    });
  }

  testWidgets('motion can change while attached', (tester) async {
    final controller = SmoothScrollController(
      motion: const WheelMotion.spring(duration: _duration),
    );
    await tester.pumpWidget(_list(controller));

    controller.motion = const WheelMotion.curve(
      duration: Duration(milliseconds: 400),
      curve: Curves.linear,
    );
    await _wheel(tester, 60);
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.offset, closeTo(30, 1));
    await tester.pumpAndSettle();
    expect(controller.offset, 60);
  });
}
