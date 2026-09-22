import 'package:flutter/animation.dart';

/// How a [SmoothScrollController] moves to its wheel target.
///
/// [WheelMotion.spring] and [WheelMotion.lerp] follow a moving target, so
/// wheel input during the motion changes where it goes without starting over.
/// [WheelMotion.curve] starts a new curve from the current position on every
/// wheel input.
sealed class WheelMotion {
  const WheelMotion();

  /// A critically damped spring when [bounce] is `0`, which arrives as fast as
  /// possible without passing the target.
  ///
  /// [duration] is how long the spring takes to settle; after it, about 99% of
  /// the distance is covered. [bounce] above `0` passes the target and comes
  /// back; below `0` approaches it more slowly. See
  /// `SpringDescription.withDurationAndBounce`.
  const factory WheelMotion.spring({Duration duration, double bounce}) =
      SpringWheelMotion;

  /// A [curve] over [duration], restarted from the current position on every
  /// wheel input.
  const factory WheelMotion.curve({Duration duration, Curve curve}) =
      CurveWheelMotion;

  /// Covers a fixed fraction of the remaining distance per unit of time: after
  /// [timeConstant], about 63% of it.
  const factory WheelMotion.lerp({Duration timeConstant}) = LerpWheelMotion;
}

/// See [WheelMotion.spring].
final class SpringWheelMotion extends WheelMotion {
  const SpringWheelMotion({
    this.duration = const Duration(milliseconds: 400),
    this.bounce = 0.0,
  }) : assert(bounce > -1.0 && bounce < 1.0);

  /// [Duration.zero] jumps as [ScrollController] does.
  final Duration duration;
  final double bounce;
}

/// See [WheelMotion.curve].
final class CurveWheelMotion extends WheelMotion {
  const CurveWheelMotion({
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  /// [Duration.zero] jumps as [ScrollController] does.
  final Duration duration;
  final Curve curve;
}

/// See [WheelMotion.lerp].
final class LerpWheelMotion extends WheelMotion {
  const LerpWheelMotion({this.timeConstant = const Duration(milliseconds: 60)});

  /// [Duration.zero] jumps as [ScrollController] does.
  final Duration timeConstant;
}
