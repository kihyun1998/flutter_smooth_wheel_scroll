# flutter_smooth_wheel_scroll

On Flutter desktop, one mouse wheel notch on Windows moves about 60 px
(the system's "lines to scroll", 3 by default, × 20 px), and `Scrollable`
applies it as an instant jump. Flutter has no setting for either:
`ScrollBehavior` and `ScrollPhysics` cover drag and fling, not wheel input.

This package fixes the two separately.

| Feature | Fixes | Scope | Turned on by |
|---|---|---|---|
| `SmoothWheelBinding` | too fast | the whole app | the app, once in `main()` |
| `SmoothScrollController` | stepped | scroll views that use it | the app or a widget package |

Use either alone or both together. Together, the scaled distance is animated.

## Wheel scale — `SmoothWheelBinding`

```dart
void main() {
  SmoothWheelBinding.ensureInitialized(scale: 0.4);
  runApp(const MyApp());
}
```

Call it **before** `WidgetsFlutterBinding.ensureInitialized()` or `runApp()`.
Once any binding is installed those return it, and this one can no longer be
installed. Importing the package installs nothing, so a widget package that
depends on it never replaces the app's binding.

Change the scale at runtime, for example from a settings screen:

```dart
SmoothWheelBinding.instance!.wheelScale = 0.6;
```

If the app already has its own binding subclass, mix in
`SmoothWheelBindingMixin` instead.

- Only mouse wheel events are scaled. Precision touchpad scrolling arrives as
  `PointerPanZoom` events and is not affected.
- Handlers that read the **magnitude** of `PointerScrollEvent.scrollDelta` see
  the scaled value. Handlers that read only its sign, such as Ctrl+wheel zoom
  steps, behave as before.

## Smooth scrolling — `SmoothScrollController`

```dart
final controller = SmoothScrollController(); // spring, 400 ms, no bounce

ListView(controller: controller, children: [...]);
```

Choose how wheel scrolling moves with `motion`:

| Motion | Options | Defaults | When the target moves |
|---|---|---|---|
| `WheelMotion.spring` | `duration`, `bounce` | 400 ms, `0` | keeps its velocity |
| `WheelMotion.curve` | `duration`, `curve` (any `Curve`) | 400 ms, `Curves.easeOutCubic` | starts a new curve from rest |
| `WheelMotion.lerp` | `timeConstant` | 60 ms | speed follows the remaining distance |

```dart
SmoothScrollController(
  motion: const WheelMotion.spring(duration: Duration(milliseconds: 300), bounce: 0.1),
);
SmoothScrollController(
  motion: const WheelMotion.curve(curve: Curves.easeOut),
);
```

- **spring** `duration` is how long it takes to settle (about 99% of the
  distance is covered by then). `bounce` `0` stops at the target without
  passing it; above `0` passes it and comes back; below `0` settles more
  slowly. Same parameters as SwiftUI's `spring(duration:bounce:)`.
- **lerp** covers about 63% of the remaining distance per `timeConstant`.
- A zero duration or time constant jumps as `ScrollController` does.
- `motion` can be replaced while attached; the next wheel input uses it.

Behaviour shared by every motion:

- Wheel input during the motion adds to the previous target, so fast
  consecutive notches travel the full distance.
- Scrolling never passes the start or end of the list, even with `bounce`.
- Items stay tappable while a wheel motion settles.
- Drag, scrollbar, keyboard and direct `jumpTo`/`animateTo` calls behave as
  with `ScrollController`. Wheel input during an `animateTo` of your own starts
  from the current position.
- In nested scroll views the outer view takes the wheel once the inner one
  reaches its end, as in Flutter by default.

### Limitations

- `NestedScrollView` routes wheel input through its own coordinator, so it is
  not smoothed.
- A scroll view whose scrollbar has a separate controller is smoothed only
  over its content, not over the scrollbar.

## Example

`example/` shows a default list and a smooth list side by side, with every
motion and option adjustable.
