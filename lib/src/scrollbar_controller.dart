import 'package:flutter/widgets.dart';

import 'pointer_scroll_record.dart';

/// A [ScrollController] for a scrollbar that sits on its own [Scrollable]
/// beside the scroll view it stands for, whose wheel input goes to [body].
///
/// A wheel over the scrollbar is given to [body]'s position, so it joins that
/// position's wheel motion when [body] is a [SmoothScrollController]; with
/// any other [ScrollController] it jumps, as it does without this class.
///
/// A wheel [body]'s physics refuse moves nothing and leaves the platform's
/// default action for the event allowed.
///
/// The scrollbar's offset still follows [body] only through whatever the
/// caller uses to mirror the two controllers.
class ScrollbarController extends ScrollController {
  ScrollbarController({required this.body, super.initialScrollOffset});

  /// The controller of the scroll view this scrollbar stands for.
  final ScrollController body;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    if (position is _ScrollbarPosition) position.controller = this;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ScrollbarPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      oldPosition: oldPosition,
    );
  }
}

class _ScrollbarPosition extends ScrollPositionWithSingleContext {
  _ScrollbarPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.oldPosition,
  }) {
    PointerScrollRecord.attach();
  }

  ScrollbarController controller;

  /// The body's one position, or `null` while it has none or more than one.
  ScrollPosition? get _bodyPosition {
    final positions = controller.body.positions;
    return positions.length == 1 ? positions.single : null;
  }

  /// The body's one position, or `null` while it has none, more than one, or
  /// no content dimensions.
  ScrollPosition? get _body {
    final position = _bodyPosition;
    return position != null && position.hasContentDimensions ? position : null;
  }

  @override
  double get maxScrollExtent => _body?.maxScrollExtent ?? super.maxScrollExtent;

  @override
  void pointerScroll(double delta) {
    final body = _body;
    if (body == null) {
      super.pointerScroll(delta);
      return;
    }
    if (!body.physics.shouldAcceptUserOffset(body)) {
      PointerScrollRecord.event?.respond(allowPlatformDefault: true);
      return;
    }
    goIdle();
    body.pointerScroll(delta);
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    _stopBody();
    return super.hold(holdCancelCallback);
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    _stopBody();
    return super.animateTo(to, duration: duration, curve: curve);
  }

  @override
  void dispose() {
    PointerScrollRecord.detach();
    super.dispose();
  }

  void _stopBody() {
    final body = _bodyPosition;
    body?.jumpTo(body.pixels);
  }
}
