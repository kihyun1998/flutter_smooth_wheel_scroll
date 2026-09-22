import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'wheel_scale.dart';

/// Scales every mouse wheel [PointerScrollEvent] by [wheelScale] before any
/// [Scrollable] receives it.
///
/// Mix into an app's own binding subclass when it already has one; otherwise
/// use [SmoothWheelBinding].
mixin SmoothWheelBindingMixin on GestureBinding {
  double _wheelScale = 1.0;

  /// The factor applied to mouse wheel scroll deltas. `1.0` leaves them as is.
  ///
  /// Handlers that read the magnitude of [PointerScrollEvent.scrollDelta]
  /// see the scaled value; handlers that read only its sign do not change.
  double get wheelScale => _wheelScale;
  set wheelScale(double value) {
    assert(value > 0 && value.isFinite, 'wheelScale must be positive: $value');
    _wheelScale = value;
  }

  @override
  void handlePointerEvent(PointerEvent event) {
    super.handlePointerEvent(scaleWheelEvent(event, _wheelScale));
  }
}

/// A [WidgetsFlutterBinding] that scales mouse wheel scrolling app-wide.
///
/// Importing this package installs nothing. The app installs it explicitly,
/// at the top of `main()`:
///
/// ```dart
/// void main() {
///   SmoothWheelBinding.ensureInitialized(scale: 0.4);
///   runApp(const MyApp());
/// }
/// ```
///
/// This must run **before** [WidgetsFlutterBinding.ensureInitialized] or
/// [runApp]: once any binding is installed, those return it and this one can
/// no longer be installed.
class SmoothWheelBinding extends WidgetsFlutterBinding
    with SmoothWheelBindingMixin {
  SmoothWheelBinding._();

  static SmoothWheelBinding? _instance;

  /// The installed binding, or `null` when [ensureInitialized] has not run.
  static SmoothWheelBinding? get instance => _instance;

  /// Installs this binding if it is not installed yet and returns it.
  ///
  /// [scale] sets [wheelScale] when given; change it later through
  /// [instance].
  static SmoothWheelBinding ensureInitialized({double? scale}) {
    final binding = _instance ??= SmoothWheelBinding._();
    if (scale != null) {
      binding.wheelScale = scale;
    }
    return binding;
  }
}
