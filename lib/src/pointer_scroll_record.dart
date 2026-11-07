import 'dart:async';

import 'package:flutter/gestures.dart';

/// The last [PointerScrollEvent] the [GestureBinding] routed, recorded by one
/// global [PointerRouter] route shared by every position that reads it.
abstract final class PointerScrollRecord {
  static int _positions = 0;

  /// The last routed [PointerScrollEvent], or `null` once the microtasks after
  /// its dispatch have run.
  static PointerScrollEvent? event;

  /// Registers the route for the first position.
  static void attach() {
    if (_positions++ == 0) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_record);
    }
  }

  /// Removes the route with the last position.
  static void detach() {
    if (--_positions == 0) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_record);
      event = null;
    }
  }

  static void _record(PointerEvent routed) {
    if (routed is! PointerScrollEvent) return;
    event = routed;
    scheduleMicrotask(() => event = null);
  }
}
