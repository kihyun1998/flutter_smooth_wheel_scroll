import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

const _width = 400.0;
const _height = 300.0;
const _barWidth = 12.0;
const _itemExtent = 50.0;
const _itemCount = 100;
const _frame = Duration(milliseconds: 16);

const _motions = <String, WheelMotion>{
  'spring': WheelMotion.spring(duration: Duration(milliseconds: 400)),
  'curve': WheelMotion.curve(duration: Duration(milliseconds: 400)),
  'lerp': WheelMotion.lerp(timeConstant: Duration(milliseconds: 100)),
};

/// The wheel position over the scrollbar strip, and over the body beside it.
const _overBar = Offset(_width - _barWidth / 2, _height / 2);
const _overBody = Offset(_width / 2, _height / 2);

/// A list in a `Stack` with a scrollbar over it on its own controller, the
/// two kept equal by a listener on each, as a table or a tree keeps them.
class _Rig extends StatefulWidget {
  const _Rig({
    required this.body,
    required this.bar,
    this.physics,
    this.barExtra = 0.0,
    this.page,
  });

  final ScrollController body;
  final ScrollController bar;
  final ScrollPhysics? physics;

  /// How much taller than the body's content the scrollbar's own content is.
  final double barExtra;

  /// When given, the pair sits at the top of a taller page on this controller.
  final ScrollController? page;

  @override
  State<_Rig> createState() => _RigState();
}

class _RigState extends State<_Rig> {
  bool _syncing = false;

  void _follow(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    final target = from.offset.clamp(
      to.position.minScrollExtent,
      to.position.maxScrollExtent,
    );
    if (target == to.offset) return;
    _syncing = true;
    try {
      to.position.jumpTo(target);
    } finally {
      _syncing = false;
    }
  }

  void _bodyChanged() => _follow(widget.body, widget.bar);

  void _barChanged() => _follow(widget.bar, widget.body);

  @override
  void initState() {
    super.initState();
    widget.body.addListener(_bodyChanged);
    widget.bar.addListener(_barChanged);
  }

  @override
  void didUpdateWidget(_Rig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      oldWidget.body.removeListener(_bodyChanged);
      widget.body.addListener(_bodyChanged);
    }
    if (oldWidget.bar != widget.bar) {
      oldWidget.bar.removeListener(_barChanged);
      widget.bar.addListener(_barChanged);
    }
  }

  @override
  void dispose() {
    widget.body.removeListener(_bodyChanged);
    widget.bar.removeListener(_barChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pair = SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        children: [
          ListView.builder(
            controller: widget.body,
            physics: widget.physics,
            itemExtent: _itemExtent,
            itemCount: _itemCount,
            itemBuilder: (_, i) => Text('$i'),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: _barWidth,
            child: RawScrollbar(
              controller: widget.bar,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: _barWidth,
              child: SingleChildScrollView(
                controller: widget.bar,
                child: SizedBox(
                  height: _itemCount * _itemExtent + widget.barExtra,
                  width: _barWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final page = widget.page;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: page == null
            ? pair
            : SizedBox(
                width: _width,
                height: 2 * _height,
                child: SingleChildScrollView(
                  controller: page,
                  child: Column(
                    children: [
                      pair,
                      const SizedBox(height: 4 * _height),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Physics that take no user offset.
class _RefusingPhysics extends ScrollPhysics {
  const _RefusingPhysics({super.parent});

  @override
  _RefusingPhysics applyTo(ScrollPhysics? ancestor) =>
      _RefusingPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => false;
}

/// A box that never lays its child out, so a scroll view under it has a
/// position, as it does before its first layout, with no content dimensions.
class _Unlaid extends SingleChildRenderObjectWidget {
  const _Unlaid({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderUnlaid();
}

class _RenderUnlaid extends RenderProxyBox {
  @override
  void performLayout() => size = constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;
}

/// A scrollbar on its own controller with no body mounted, and a body
/// controller that has no client.
Widget _barOnly(ScrollController bar, {Axis axis = Axis.vertical}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _width,
        height: _height,
        child: RawScrollbar(
          controller: bar,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: bar,
            scrollDirection: axis,
            child: SizedBox(
              width: axis == Axis.horizontal ? 5000 : _width,
              height: axis == Axis.vertical ? 5000 : _height,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A list with no scrollbar over it, for the motion a wheel over the body
/// itself makes.
Widget _bodyOnly(ScrollController body) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _width,
        height: _height,
        child: ListView.builder(
          controller: body,
          itemExtent: _itemExtent,
          itemCount: _itemCount,
          itemBuilder: (_, i) => Text('$i'),
        ),
      ),
    ),
  );
}

/// Builds [rig] and pumps until the scrollbar has faded in.
Future<void> _mount(WidgetTester tester, Widget rig) async {
  await tester.pumpWidget(rig);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// A horizontal view with a scrollbar strip along its bottom edge, on
/// [bar], built and faded in.
Future<void> _mountHorizontal(
  WidgetTester tester,
  ScrollController body,
  ScrollController bar, {
  ScrollPhysics? bodyPhysics,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: body,
                scrollDirection: Axis.horizontal,
                physics: bodyPhysics,
                child: const SizedBox(width: 5000, height: _height),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barWidth,
                child: RawScrollbar(
                  controller: bar,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: bar,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 5000, height: _barWidth),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _wheel(
  WidgetTester tester,
  Offset at,
  double dy, {
  double dx = 0,
  List<bool>? responses,
}) async {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: at,
      scrollDelta: Offset(dx, dy),
      onRespond: responses == null
          ? null
          : ({bool allowPlatformDefault = false}) =>
                responses.add(allowPlatformDefault),
    ),
  );
  await tester.pump();
}

/// The body's offset after each of [count] frames.
Future<List<double>> _frames(
  WidgetTester tester,
  ScrollController body,
  int count,
) async {
  final offsets = <double>[];
  for (var i = 0; i < count; i++) {
    await tester.pump(_frame);
    offsets.add(body.offset);
  }
  return offsets;
}

void main() {
  for (final MapEntry(key: name, value: motion) in _motions.entries) {
    group('with a $name motion', () {
      testWidgets('a wheel over the scrollbar moves the body as a wheel over '
          'the body does, the scrollbar level with it each frame', (
        tester,
      ) async {
        final reference = SmoothScrollController(motion: motion);
        addTearDown(reference.dispose);
        await tester.pumpWidget(_bodyOnly(reference));
        await _wheel(tester, _overBody, 60);
        final expected = [
          reference.offset,
          ...await _frames(tester, reference, 40),
        ];

        final body = SmoothScrollController(motion: motion);
        final bar = ScrollbarController(body: body);
        addTearDown(body.dispose);
        addTearDown(bar.dispose);
        await _mount(tester, _Rig(body: body, bar: bar));
        await _wheel(tester, _overBar, 60);
        final actual = [body.offset];
        expect(bar.offset, body.offset);
        for (var i = 0; i < 40; i++) {
          await tester.pump(_frame);
          actual.add(body.offset);
          expect(bar.offset, body.offset, reason: 'frame $i');
        }

        expect(expected.first, lessThan(60), reason: 'the reference animates');
        expect(actual, expected);
        expect(body.offset, 60);
      });

      testWidgets('120 then 60 two frames later settles at 180, the '
          'scrollbar level with the body each frame', (tester) async {
        final body = SmoothScrollController(motion: motion);
        final bar = ScrollbarController(body: body);
        addTearDown(body.dispose);
        addTearDown(bar.dispose);
        await _mount(tester, _Rig(body: body, bar: bar));

        await _wheel(tester, _overBar, 120);
        await tester.pump(_frame);
        await tester.pump(_frame);
        await _wheel(tester, _overBar, 60);
        for (var i = 0; i < 60; i++) {
          await tester.pump(_frame);
          expect(bar.offset, body.offset, reason: 'frame $i');
        }

        expect(body.offset, 180);
        expect(bar.offset, 180);
      });
    });
  }

  testWidgets('a plain body takes the wheel as a jump', (tester) async {
    final body = ScrollController();
    final bar = ScrollbarController(body: body);
    addTearDown(body.dispose);
    addTearDown(bar.dispose);
    await _mount(tester, _Rig(body: body, bar: bar));

    await _wheel(tester, _overBar, 60);

    expect(body.offset, 60);
    expect(bar.offset, 60);
  });

  for (final extra in [0.0, 1e-9, 1.0]) {
    testWidgets('a notch over the scrollbar with the body at its end reaches '
        'the page when the scrollbar\'s own content is $extra taller', (
      tester,
    ) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      final page = ScrollController();
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      addTearDown(page.dispose);
      await _mount(
        tester,
        _Rig(body: body, bar: bar, barExtra: extra, page: page),
      );
      body.jumpTo(body.position.maxScrollExtent);
      await tester.pump();

      final offsets = <double>[];
      for (var i = 0; i < 3; i++) {
        await _wheel(tester, const Offset(_width - _barWidth / 2, 50), 60);
        await tester.pump(const Duration(seconds: 1));
        offsets.add(page.offset);
      }

      expect(offsets, [60, 120, 180]);
      expect(bar.position.maxScrollExtent, body.position.maxScrollExtent);
    });
  }

  group('the scrollbar track and thumb', () {
    const track = Offset(_width - _barWidth / 2, 200);
    const spring = WheelMotion.spring(duration: Duration(milliseconds: 400));
    const pageClick = 0.8 * _height;

    testWidgets('a notch during a track click moves on from where the click '
        'had got to, and the click does not carry on', (tester) async {
      final body = SmoothScrollController(motion: spring);
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(tester, _Rig(body: body, bar: bar));

      await tester.tapAt(track, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump(_frame);
      await tester.pump(_frame);
      final before = body.offset;
      expect(before, inExclusiveRange(0, pageClick), reason: 'click running');
      await _wheel(tester, _overBar, 60);
      await tester.pump(const Duration(seconds: 2));

      expect(body.offset, closeTo(before + 60, 1e-9));
      expect(bar.offset, body.offset);
    });

    testWidgets('a track click during a body motion pages on from where the '
        'motion had got to', (tester) async {
      final body = SmoothScrollController(motion: spring);
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(tester, _Rig(body: body, bar: bar));

      await _wheel(tester, _overBar, 300);
      await tester.pump(_frame);
      final before = body.offset;
      expect(before, inExclusiveRange(0, 300), reason: 'motion running');
      await tester.tapAt(track, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(body.offset, closeTo(before + pageClick, 1e-9));
      expect(bar.offset, body.offset);
    });

    testWidgets('pressing the thumb during a body motion stops it, and a drag '
        'then moves both', (tester) async {
      final body = SmoothScrollController(motion: spring);
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(tester, _Rig(body: body, bar: bar));

      await _wheel(tester, _overBar, 300);
      await tester.pump(_frame);
      await tester.pump(_frame);
      final thumb = Offset(_width - _barWidth / 2, 10);
      final gesture = await tester.startGesture(
        thumb,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 100));
      final held = body.offset;
      expect(held, inExclusiveRange(0, 300), reason: 'motion was running');
      await tester.pump(const Duration(seconds: 1));
      expect(body.offset, held, reason: 'the motion stopped at the press');

      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      final dragged = body.offset;
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(dragged, greaterThan(held));
      expect(body.offset, dragged);
      expect(bar.offset, body.offset);
    });
  });

  group('near the end', () {
    const spring = WheelMotion.spring(duration: Duration(milliseconds: 400));

    testWidgets('a wheel far past the end, a track click, then a notch each '
        'move both from where the last one left them', (tester) async {
      final body = SmoothScrollController(motion: spring);
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(tester, _Rig(body: body, bar: bar, barExtra: 8));
      final end = body.position.maxScrollExtent;

      await _wheel(tester, _overBar, 100000);
      await tester.pump(const Duration(seconds: 2));
      expect(body.offset, end);
      expect(bar.offset, end);

      await tester.tapAt(
        const Offset(_width - _barWidth / 2, 100),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(body.offset, end - 0.8 * _height);
      expect(bar.offset, body.offset);

      await _wheel(tester, _overBar, 60);
      await tester.pump(const Duration(seconds: 2));
      expect(body.offset, end - 0.8 * _height + 60);
      expect(bar.offset, body.offset);
    });

    testWidgets('notches of 60 from 68 short of the end stop at the end', (
      tester,
    ) async {
      final body = SmoothScrollController(motion: spring);
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(tester, _Rig(body: body, bar: bar, barExtra: 8));
      final end = body.position.maxScrollExtent;
      body.jumpTo(end - 68);
      await tester.pump();

      await _wheel(tester, _overBar, 60);
      await tester.pump(const Duration(seconds: 2));
      expect(body.offset, end - 8);
      await _wheel(tester, _overBar, 60);
      await tester.pump(const Duration(seconds: 2));

      expect(body.offset, end);
      expect(bar.offset, end);
    });
  });

  group('a body whose physics refuse the wheel', () {
    testWidgets('a wheel over the vertical scrollbar moves nothing', (
      tester,
    ) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(
        tester,
        _Rig(body: body, bar: bar, physics: const _RefusingPhysics()),
      );

      await _wheel(tester, _overBar, 120);
      await tester.pump(const Duration(seconds: 1));

      expect(body.offset, 0);
      expect(bar.offset, 0);
    });

    testWidgets('a wheel over the vertical scrollbar leaves the platform '
        'default allowed', (tester) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(
        tester,
        _Rig(body: body, bar: bar, physics: const _RefusingPhysics()),
      );

      final responses = <bool>[];
      await _wheel(tester, _overBar, 120, responses: responses);

      expect(responses, contains(true));
    });

    testWidgets('a wheel over the horizontal scrollbar leaves the platform '
        'default allowed', (tester) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mountHorizontal(
        tester,
        body,
        bar,
        bodyPhysics: const _RefusingPhysics(),
      );

      final responses = <bool>[];
      await _wheel(
        tester,
        const Offset(_width / 2, _height - _barWidth / 2),
        0,
        dx: 120,
        responses: responses,
      );

      expect(responses, contains(true));
    });

    testWidgets('a body that takes the wheel is not told to allow the '
        'platform default', (tester) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mount(tester, _Rig(body: body, bar: bar));

      final responses = <bool>[];
      await _wheel(tester, _overBar, 120, responses: responses);

      expect(responses, isNot(contains(true)));
    });

    testWidgets('a wheel over the horizontal scrollbar moves nothing', (
      tester,
    ) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mountHorizontal(
        tester,
        body,
        bar,
        bodyPhysics: const _RefusingPhysics(),
      );

      await _wheel(
        tester,
        const Offset(_width / 2, _height - _barWidth / 2),
        0,
        dx: 120,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(body.offset, 0);
      expect(bar.offset, 0);
    });
  });

  group('a tilt wheel over a horizontal scrollbar', () {
    testWidgets('moves the body', (tester) async {
      final body = SmoothScrollController();
      final bar = ScrollbarController(body: body);
      addTearDown(body.dispose);
      addTearDown(bar.dispose);
      await _mountHorizontal(tester, body, bar);

      await _wheel(
        tester,
        const Offset(_width / 2, _height - _barWidth / 2),
        0,
        dx: 60,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(body.offset, 60);
    });
  });

  testWidgets('a body with no client leaves the wheel to the scrollbar\'s own '
      'position', (tester) async {
    final body = SmoothScrollController();
    final bar = ScrollbarController(body: body);
    addTearDown(body.dispose);
    addTearDown(bar.dispose);
    await tester.pumpWidget(_barOnly(bar));
    await tester.pump(const Duration(seconds: 1));
    expect(body.hasClients, isFalse);

    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(_width / 2, _height / 2),
        scrollDelta: Offset(0, 60),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(bar.offset, 60);
  });

  testWidgets('a body whose position has no content dimensions leaves the '
      'wheel to the scrollbar\'s own position', (tester) async {
    final body = SmoothScrollController();
    final bar = ScrollbarController(body: body);
    addTearDown(body.dispose);
    addTearDown(bar.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            children: [
              SizedBox(
                width: _width,
                height: _height,
                child: _Unlaid(
                  child: SingleChildScrollView(
                    controller: body,
                    child: const SizedBox(height: 5000),
                  ),
                ),
              ),
              SizedBox(
                width: _width,
                height: _height,
                child: SingleChildScrollView(
                  controller: bar,
                  child: const SizedBox(height: 5000),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(body.hasClients, isTrue);
    expect(body.position.hasContentDimensions, isFalse);

    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(_width / 2, _height + 100),
        scrollDelta: Offset(0, 60),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(bar.offset, 60);
  });

  testWidgets('a wheel after the scroll views\' controllers were replaced '
      'reaches the new body', (tester) async {
    final bodyA = SmoothScrollController();
    final barA = ScrollbarController(body: bodyA);
    final bodyB = SmoothScrollController();
    final barB = ScrollbarController(body: bodyB);
    addTearDown(bodyA.dispose);
    addTearDown(barA.dispose);
    addTearDown(bodyB.dispose);
    addTearDown(barB.dispose);
    await _mount(tester, _Rig(body: bodyA, bar: barA));
    await _mount(tester, _Rig(body: bodyB, bar: barB));
    expect(bodyA.hasClients, isFalse);
    expect(bodyB.hasClients, isTrue);

    await _wheel(tester, _overBar, 60);
    await tester.pump(_frame);
    await tester.pump(_frame);
    expect(bodyB.offset, inExclusiveRange(0, 60), reason: 'it animates');
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(bodyB.offset, 60);
    expect(barB.offset, 60);
  });

  testWidgets('a notch during a fling on the scrollbar moves on from where the '
      'fling had got to, and the fling does not carry on', (tester) async {
    final body = SmoothScrollController(
      motion: const WheelMotion.spring(duration: Duration(milliseconds: 400)),
    );
    final bar = ScrollbarController(body: body);
    addTearDown(body.dispose);
    addTearDown(bar.dispose);
    await _mount(tester, _Rig(body: body, bar: bar));

    (bar.position as ScrollPositionWithSingleContext).goBallistic(2000);
    await tester.pump();
    await tester.pump(_frame);
    await tester.pump(_frame);
    final before = body.offset;
    expect(before, greaterThan(0), reason: 'fling running');
    await _wheel(tester, _overBar, 60);
    await tester.pump(const Duration(seconds: 3));

    expect(body.offset, closeTo(before + 60, 1e-9));
    expect(bar.offset, body.offset);
  });

  testWidgets('a scrollbar position and a smooth position share one global '
      'pointer route, and leave none when disposed', (tester) async {
    final router = tester.binding.pointerRouter;
    final baseline = router.debugGlobalRouteCount;
    final body = SmoothScrollController();
    final bar = ScrollbarController(body: body);
    addTearDown(body.dispose);
    addTearDown(bar.dispose);

    await tester.pumpWidget(_barOnly(bar));
    expect(router.debugGlobalRouteCount, baseline + 1);

    await tester.pumpWidget(_Rig(body: body, bar: bar));
    expect(router.debugGlobalRouteCount, baseline + 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(router.debugGlobalRouteCount, baseline);
  });
}
