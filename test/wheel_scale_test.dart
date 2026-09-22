import 'package:flutter/gestures.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scaleWheelEvent', () {
    test('scales the scroll delta of a mouse wheel event', () {
      const event = PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        scrollDelta: Offset(10, 60),
      );

      final scaled = scaleWheelEvent(event, 0.5) as PointerScrollEvent;

      expect(scaled.scrollDelta, const Offset(5, 30));
    });

    test('passes non-mouse scroll events through unchanged', () {
      const event = PointerScrollEvent(
        kind: PointerDeviceKind.trackpad,
        scrollDelta: Offset(0, 60),
      );

      expect(scaleWheelEvent(event, 0.5), same(event));
    });

    test('passes non-scroll events through unchanged', () {
      const event = PointerDownEvent(kind: PointerDeviceKind.mouse);

      expect(scaleWheelEvent(event, 0.5), same(event));
    });

    test('preserves every other field', () {
      const event = PointerScrollEvent(
        viewId: 3,
        timeStamp: Duration(milliseconds: 42),
        kind: PointerDeviceKind.mouse,
        device: 7,
        position: Offset(100, 200),
        scrollDelta: Offset(0, 60),
        embedderId: 9,
      );

      final scaled = scaleWheelEvent(event, 0.5) as PointerScrollEvent;

      expect(scaled.viewId, 3);
      expect(scaled.timeStamp, const Duration(milliseconds: 42));
      expect(scaled.kind, PointerDeviceKind.mouse);
      expect(scaled.device, 7);
      expect(scaled.position, const Offset(100, 200));
      expect(scaled.embedderId, 9);
    });

    test('forwards respond to the original event', () {
      bool? allowed;
      final event = PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, 60),
        onRespond: ({required bool allowPlatformDefault}) {
          allowed = allowPlatformDefault;
        },
      );

      (scaleWheelEvent(event, 0.5) as PointerScrollEvent).respond(
        allowPlatformDefault: true,
      );

      expect(allowed, isTrue);
    });
  });
}
