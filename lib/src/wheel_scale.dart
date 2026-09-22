import 'package:flutter/gestures.dart';

/// Returns [event] with its scroll delta multiplied by [scale] when it is a
/// mouse wheel [PointerScrollEvent], and [event] itself otherwise.
///
/// Trackpad scrolling arrives as [PointerPanZoomUpdateEvent]s or as
/// [PointerScrollEvent]s of another [PointerDeviceKind], so it is never
/// scaled.
PointerEvent scaleWheelEvent(PointerEvent event, double scale) {
  if (event is! PointerScrollEvent ||
      event.kind != PointerDeviceKind.mouse ||
      scale == 1.0) {
    return event;
  }
  return PointerScrollEvent(
    viewId: event.viewId,
    timeStamp: event.timeStamp,
    kind: event.kind,
    device: event.device,
    position: event.position,
    scrollDelta: event.scrollDelta * scale,
    embedderId: event.embedderId,
    onRespond: event.respond,
  );
}
