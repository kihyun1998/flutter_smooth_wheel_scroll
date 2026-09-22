import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'wheel_motion.dart';

/// A [ScrollController] whose positions animate mouse wheel scrolling instead
/// of jumping.
///
/// Wheel input that arrives during the motion is added to the previous
/// target, not to the current position. Every other input — drag, scrollbar,
/// keyboard, [jumpTo], [animateTo] — behaves as with [ScrollController].
///
/// A [NestedScrollView] routes wheel input through its own coordinator, so
/// this controller does not smooth it.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    this.motion = const WheelMotion.spring(),
  });

  /// How wheel scrolling moves. Read on every wheel input, so a change applies
  /// from the next one.
  WheelMotion motion;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final SmoothScrollController controller;

  @override
  void pointerScroll(double delta) {
    final motion = controller.motion;
    if (delta == 0.0 || _isInstant(motion)) {
      super.pointerScroll(delta);
      return;
    }

    final current = activity;
    final animating = current is _WheelMotionActivity;
    final base = animating ? current.target : pixels;
    final target = (base + delta).clamp(minScrollExtent, maxScrollExtent);
    if (animating ? target == current.target : target == pixels) {
      if (animating) _passToAncestor(delta);
      return;
    }

    if (animating) {
      current.retarget(target, motion);
    } else {
      beginActivity(
        _WheelMotionActivity(
          this,
          metrics: this,
          motion: motion,
          target: target,
          vsync: context.vsync,
        ),
      );
    }
    updateUserScrollDirection(
      delta > 0.0 ? ScrollDirection.reverse : ScrollDirection.forward,
    );
  }

  /// Gives [delta] to the nearest enclosing scroll view that [Scrollable]
  /// would have let take a wheel event of that size: under the pointer, on the
  /// same axis, and able to move.
  void _passToAncestor(double delta) {
    final origin = context.notificationContext;
    final originBox = origin?.findRenderObject();
    if (origin == null || originBox == null) return;
    final raw = axisDirectionIsReversed(axisDirection) ? -delta : delta;

    for (
      var scrollable = origin.findAncestorStateOfType<ScrollableState>();
      scrollable != null;
      scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>()
    ) {
      final position = scrollable.position;
      if (position == this ||
          position.axis != axis ||
          !_isRenderAncestor(
            scrollable.context.findRenderObject(),
            originBox,
          ) ||
          !position.physics.shouldAcceptUserOffset(position)) {
        continue;
      }
      final ancestorDelta = axisDirectionIsReversed(position.axisDirection)
          ? -raw
          : raw;
      final ancestorTarget = (position.pixels + ancestorDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (ancestorTarget != position.pixels) {
        position.pointerScroll(ancestorDelta);
        return;
      }
    }
  }

  /// Whether [ancestor] is [node] or one of its parents in the render tree.
  static bool _isRenderAncestor(RenderObject? ancestor, RenderObject node) {
    for (RenderObject? n = node; n != null; n = n.parent) {
      if (n == ancestor) return true;
    }
    return false;
  }

  static bool _isInstant(WheelMotion motion) => switch (motion) {
    SpringWheelMotion(:final duration) => duration == Duration.zero,
    CurveWheelMotion(:final duration) => duration == Duration.zero,
    LerpWheelMotion(:final timeConstant) => timeConstant == Duration.zero,
  };
}

/// Drives a position toward a wheel target that can move, one [_Follower] at a
/// time, and never past the scroll extents.
class _WheelMotionActivity extends ScrollActivity {
  _WheelMotionActivity(
    super.delegate, {
    required this.metrics,
    required WheelMotion motion,
    required double target,
    required TickerProvider vsync,
  }) : _follower = _Follower.of(
         motion,
         x: metrics.pixels,
         v: 0.0,
         target: target,
       ) {
    _ticker = vsync.createTicker(_tick)..start();
  }

  /// The position being driven, read for its extents.
  final ScrollMetrics metrics;

  late final Ticker _ticker;
  _Follower _follower;
  Duration _last = Duration.zero;

  double get target => _follower.target;

  /// Heads for [target] with [motion] from the current position and velocity.
  void retarget(double target, WheelMotion motion) {
    _follower = _Follower.of(
      motion,
      x: _follower.x,
      v: _follower.v,
      target: target,
    );
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;

    final done = _follower.advance(dt);
    final x = _follower.x;
    final clamped = x.clamp(metrics.minScrollExtent, metrics.maxScrollExtent);
    final overscroll = delegate.setPixels(clamped);

    if (clamped != x || overscroll != 0.0) {
      delegate.goIdle();
    } else if (done) {
      delegate.goBallistic(0.0);
    }
  }

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _follower.v;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// The path from a position and velocity to [target] under one [WheelMotion].
/// A new target means a new follower, started where the old one was.
sealed class _Follower {
  _Follower({required this.x, required this.v, required this.target});

  factory _Follower.of(
    WheelMotion motion, {
    required double x,
    required double v,
    required double target,
  }) => switch (motion) {
    SpringWheelMotion() => _SpringFollower(motion, x: x, v: v, target: target),
    CurveWheelMotion() => _CurveFollower(motion, x: x, v: v, target: target),
    LerpWheelMotion() => _LerpFollower(motion, x: x, v: v, target: target),
  };

  /// Settling within these counts as arriving; the follower then snaps to
  /// [target].
  static const tolerance = Tolerance(distance: 0.5, velocity: 10.0);

  double x;
  double v;
  final double target;

  /// Moves [dt] seconds forward, updating [x] and [v]. Returns whether the
  /// follower has arrived, in which case [x] is [target] and [v] is `0`.
  bool advance(double dt) {
    final done = step(dt);
    if (done) {
      x = target;
      v = 0.0;
    }
    return done;
  }

  bool step(double dt);
}

class _SpringFollower extends _Follower {
  _SpringFollower(
    SpringWheelMotion motion, {
    required super.x,
    required super.v,
    required super.target,
  }) : _simulation = SpringSimulation(
         SpringDescription.withDurationAndBounce(
           duration: motion.duration,
           bounce: motion.bounce,
         ),
         x,
         target,
         v,
         tolerance: _Follower.tolerance,
       );

  final SpringSimulation _simulation;
  double _t = 0.0;

  @override
  bool step(double dt) {
    _t += dt;
    x = _simulation.x(_t);
    v = _simulation.dx(_t);
    return _simulation.isDone(_t);
  }
}

/// Restarts [CurveWheelMotion.curve] from the current position; the velocity
/// it was handed is not carried over.
class _CurveFollower extends _Follower {
  _CurveFollower(
    this.motion, {
    required super.x,
    required super.v,
    required super.target,
  }) : _from = x;

  final CurveWheelMotion motion;
  final double _from;
  double _t = 0.0;

  @override
  bool step(double dt) {
    _t += dt;
    final seconds =
        motion.duration.inMicroseconds / Duration.microsecondsPerSecond;
    final progress = (_t / seconds).clamp(0.0, 1.0);
    final next = _from + (target - _from) * motion.curve.transform(progress);
    v = dt > 0.0 ? (next - x) / dt : v;
    x = next;
    return progress == 1.0;
  }
}

class _LerpFollower extends _Follower {
  _LerpFollower(
    this.motion, {
    required super.x,
    required super.v,
    required super.target,
  });

  final LerpWheelMotion motion;

  @override
  bool step(double dt) {
    final tau =
        motion.timeConstant.inMicroseconds / Duration.microsecondsPerSecond;
    final next = x + (target - x) * (1 - math.exp(-dt / tau));
    v = dt > 0.0 ? (next - x) / dt : v;
    x = next;
    return (target - x).abs() < _Follower.tolerance.distance;
  }
}
