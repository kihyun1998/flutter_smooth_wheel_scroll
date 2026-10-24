import 'package:flutter/animation.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runtime values, so that no instance below is canonicalized as a constant.
final _ms = int.parse('200');
Duration _d([int extra = 0]) => Duration(milliseconds: _ms + extra);

void main() {
  void expectEqual(WheelMotion a, WheelMotion b) {
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  }

  group('equal field values are equal motions', () {
    test('spring', () {
      expectEqual(
        WheelMotion.spring(duration: _d(), bounce: _ms / 1000),
        WheelMotion.spring(duration: _d(), bounce: _ms / 1000),
      );
    });

    test('curve', () {
      expectEqual(
        WheelMotion.curve(duration: _d(), curve: Curves.easeOut),
        WheelMotion.curve(duration: _d(), curve: Curves.easeOut),
      );
    });

    test('lerp', () {
      expectEqual(
        WheelMotion.lerp(timeConstant: _d()),
        WheelMotion.lerp(timeConstant: _d()),
      );
    });
  });

  group('one different field is a different motion', () {
    test('spring duration', () {
      expect(
        WheelMotion.spring(duration: _d()),
        isNot(WheelMotion.spring(duration: _d(1))),
      );
    });

    test('spring bounce', () {
      expect(
        WheelMotion.spring(duration: _d(), bounce: 0.1),
        isNot(WheelMotion.spring(duration: _d(), bounce: 0.2)),
      );
    });

    test('curve duration', () {
      expect(
        WheelMotion.curve(duration: _d()),
        isNot(WheelMotion.curve(duration: _d(1))),
      );
    });

    test('curve curve', () {
      expect(
        WheelMotion.curve(duration: _d(), curve: Curves.easeOut),
        isNot(WheelMotion.curve(duration: _d(), curve: Curves.linear)),
      );
    });

    test('lerp time constant', () {
      expect(
        WheelMotion.lerp(timeConstant: _d()),
        isNot(WheelMotion.lerp(timeConstant: _d(1))),
      );
    });
  });

  test('motions of different kinds with the same duration differ', () {
    final spring = WheelMotion.spring(duration: _d());
    final curve = WheelMotion.curve(duration: _d());
    expect(spring, isNot(curve));
    expect(curve, isNot(spring));
  });
}
