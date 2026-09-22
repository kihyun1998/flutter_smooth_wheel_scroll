import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

const _duration = Duration(milliseconds: 160);
const _itemExtent = 50.0;
const _viewport = 600.0;

Widget _list(ScrollController controller, {int itemCount = 100}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        height: _viewport,
        child: ListView.builder(
          controller: controller,
          itemExtent: _itemExtent,
          itemCount: itemCount,
          itemBuilder: (_, i) => Text('$i'),
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

void main() {
  testWidgets('animates to the target instead of jumping', (tester) async {
    final controller = SmoothScrollController(duration: _duration);
    await tester.pumpWidget(_list(controller));

    await _wheel(tester, 60);
    expect(controller.offset, 0);

    await tester.pump(_duration ~/ 2);
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(60));

    await tester.pumpAndSettle();
    expect(controller.offset, 60);
  });

  testWidgets('accumulates wheel input during the animation', (tester) async {
    final controller = SmoothScrollController(duration: _duration);
    await tester.pumpWidget(_list(controller));

    await _wheel(tester, 60);
    await tester.pump(const Duration(milliseconds: 20));
    await _wheel(tester, 60);
    await tester.pump(const Duration(milliseconds: 20));
    await _wheel(tester, 60);
    await tester.pumpAndSettle();

    expect(controller.offset, 180);
  });

  testWidgets('does not pass the scroll extent', (tester) async {
    final controller = SmoothScrollController(duration: _duration);
    await tester.pumpWidget(_list(controller, itemCount: 14));
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

  testWidgets(
    'wheel input at a clamped target does not restart the animation',
    (tester) async {
      final controller = SmoothScrollController(duration: _duration);
      await tester.pumpWidget(_list(controller, itemCount: 14));

      await _wheel(tester, 200);
      await tester.pump(_duration ~/ 2);
      await _wheel(tester, 60);
      await tester.pump(_duration ~/ 2);

      expect(controller.offset, controller.position.maxScrollExtent);
    },
  );

  testWidgets('wheel input during a programmatic animation starts from the '
      'current position', (tester) async {
    final controller = SmoothScrollController(duration: _duration);
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
    final controller = SmoothScrollController(duration: _duration);
    await tester.pumpWidget(_list(controller));

    await _wheel(tester, 60);
    await tester.pump(_duration ~/ 2);
    expect(controller.position.userScrollDirection, ScrollDirection.reverse);

    await tester.pumpAndSettle();
    expect(controller.position.userScrollDirection, ScrollDirection.idle);

    await _wheel(tester, -60);
    await tester.pump(_duration ~/ 2);
    expect(controller.position.userScrollDirection, ScrollDirection.forward);
  });

  testWidgets(
    'the outer list receives the wheel once the inner one is at its end',
    (tester) async {
      final outer = SmoothScrollController(duration: _duration);
      final inner = SmoothScrollController(duration: _duration);
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

  testWidgets('duration can change while attached', (tester) async {
    final controller = SmoothScrollController(duration: _duration);
    await tester.pumpWidget(_list(controller));

    controller.duration = const Duration(milliseconds: 400);
    await _wheel(tester, 60);
    await tester.pump(_duration);

    expect(controller.offset, lessThan(60));
    await tester.pumpAndSettle();
    expect(controller.offset, 60);
  });
}
