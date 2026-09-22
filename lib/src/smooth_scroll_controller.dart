import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [ScrollController] whose positions animate mouse wheel scrolling instead
/// of jumping.
///
/// Wheel input that arrives during the animation is added to the previous
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
    this.duration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOutCubic,
  });

  /// How long one wheel animation takes. Read on every wheel input, so a
  /// change applies from the next one. [Duration.zero] jumps as
  /// [ScrollController] does.
  Duration duration;

  /// The curve of one wheel animation. Read on every wheel input.
  Curve curve;

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

  /// The activity this position started for wheel input, and its target.
  /// The target is only meaningful while [activity] is still that activity.
  ScrollActivity? _wheelActivity;
  double _wheelTarget = 0.0;

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0 || controller.duration == Duration.zero) {
      super.pointerScroll(delta);
      return;
    }

    final animating =
        _wheelActivity != null && identical(activity, _wheelActivity);
    final base = animating ? _wheelTarget : pixels;
    final target = (base + delta).clamp(minScrollExtent, maxScrollExtent);
    if (animating ? target == _wheelTarget : target == pixels) {
      return;
    }

    _wheelTarget = target;
    animateTo(target, duration: controller.duration, curve: controller.curve);
    _wheelActivity = activity;
    if (activity is DrivenScrollActivity) {
      updateUserScrollDirection(
        delta > 0.0 ? ScrollDirection.reverse : ScrollDirection.forward,
      );
    }
  }
}
