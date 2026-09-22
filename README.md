# flutter_smooth_wheel_scroll

[![pub package](https://img.shields.io/pub/v/flutter_smooth_wheel_scroll.svg)](https://pub.dev/packages/flutter_smooth_wheel_scroll)

Smooth, adjustable mouse wheel scrolling for Flutter desktop.

On Flutter desktop a mouse wheel notch jumps the list instantly, and on
Windows it moves about 60 px at once (the system's "lines to scroll", 3 by
default, × 20 px). Flutter has no setting for either: `ScrollBehavior` and
`ScrollPhysics` cover dragging and flinging, not wheel input.

This package fixes the two separately.

| | Fixes | Applies to | Set up by |
|---|---|---|---|
| [`SmoothScrollController`](#smooth-scrolling) | the instant jump | scroll views that use it | the app or a widget package |
| [`SmoothWheelBinding`](#wheel-distance) | the distance per notch | the whole app | the app, once in `main()` |

Use either one alone or both together.

## Getting started

```sh
flutter pub add flutter_smooth_wheel_scroll
```

```dart
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';

void main() {
  SmoothWheelBinding.ensureInitialized(scale: 0.5); // optional: half the distance
  runApp(const MyApp());
}

// In a State:
final _controller = SmoothScrollController();

@override
Widget build(BuildContext context) {
  return ListView.builder(controller: _controller, ...);
}

@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

## Smooth scrolling

`SmoothScrollController` is a drop-in `ScrollController`. Wheel input animates
instead of jumping; everything else behaves exactly as before.

### Choosing a motion

```dart
SmoothScrollController(); // spring, 400 ms, no bounce

SmoothScrollController(
  motion: const WheelMotion.spring(
    duration: Duration(milliseconds: 300),
    bounce: 0.1,
  ),
);

SmoothScrollController(
  motion: const WheelMotion.curve(curve: Curves.easeOut),
);

SmoothScrollController(
  motion: const WheelMotion.lerp(timeConstant: Duration(milliseconds: 80)),
);
```

| Motion | Options | Defaults | Feel |
|---|---|---|---|
| `WheelMotion.spring` | `duration`, `bounce` | 400 ms, `0` | Keeps its speed when you keep scrolling. The smoothest for fast consecutive notches. |
| `WheelMotion.curve` | `duration`, `curve` | 400 ms, `Curves.easeOutCubic` | Plays the curve to the target, starting over on every notch. Any `Curve` works, including your own. |
| `WheelMotion.lerp` | `timeConstant` | 60 ms | Fast at first, slowing as it arrives. Speeds up when the target moves further away. |

- **`spring.duration`**: how long the spring takes to settle; about 99% of the
  distance is covered by then.
- **`spring.bounce`**: `0` stops at the target without passing it. Above `0`
  passes it and comes back; below `0` settles more slowly. Same parameters as
  SwiftUI's `spring(duration:bounce:)`.
- **`lerp.timeConstant`**: about 63% of the remaining distance is covered per
  time constant. Smaller is snappier.
- A zero duration or time constant turns the animation off.

`motion` can be changed at any time, for example from a settings screen; the
next wheel input uses it.

```dart
_controller.motion = const WheelMotion.spring(duration: Duration(milliseconds: 250));
```

### Behaviour

With every motion:

- Wheel input during a motion adds to the previous target, so fast consecutive
  notches travel the full distance.
- Scrolling never passes the start or end of the list, even with `bounce`, on
  both clamping and bouncing scroll physics.
- Items stay tappable while a motion settles.
- `userScrollDirection` is reported during the motion, so widgets that hide on
  scroll keep working.
- Dragging, the scrollbar, the keyboard and your own `jumpTo`/`animateTo` calls
  behave as with `ScrollController`. Wheel input during your own `animateTo`
  starts from the current position.
- In nested scroll views, the outer view takes the wheel once the inner one
  reaches its end, as in Flutter by default.

## Wheel distance

`SmoothWheelBinding` multiplies the distance of every mouse wheel notch,
app-wide, before any scroll view sees it. No scroll view or controller needs
to change.

```dart
void main() {
  SmoothWheelBinding.ensureInitialized(scale: 0.5);
  runApp(const MyApp());
}
```

- Call it **first** in `main()`, before `WidgetsFlutterBinding.ensureInitialized()`
  or `runApp()`. Once any binding is installed, this one can no longer be.
- `scale` `1.0` (the default) leaves wheel scrolling unchanged. Below `1` is
  slower, above `1` faster.
- Change it at runtime:

  ```dart
  SmoothWheelBinding.instance!.wheelScale = 0.6;
  ```

- If your app already has its own binding class, mix in
  `SmoothWheelBindingMixin` instead.
- Importing the package installs nothing. A widget package can depend on this
  one for `SmoothScrollController` without replacing the app's binding.

Only mouse wheels are scaled. Precision touchpad scrolling arrives as
`PointerPanZoom` events and is left alone. Handlers that read the size of
`PointerScrollEvent.scrollDelta` see the scaled value; handlers that read only
its sign, such as Ctrl+wheel zoom steps, behave as before.

## Limitations

- `NestedScrollView` routes wheel input through its own coordinator and is not
  smoothed.
- A scrollbar with its own controller is not smoothed when the wheel is used
  over the scrollbar itself.
- Developed and checked on Windows. Other desktop platforms use the same
  Flutter code path but have not been tried by hand.

## Example

[`example/`](example/) puts a default list next to a smooth one. Every option
is adjustable with an explanation, and the code for the current settings is
shown ready to copy.

```sh
cd example
flutter run -d windows
```

## License

MIT
