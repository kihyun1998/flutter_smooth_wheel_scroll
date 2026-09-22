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
final controller = SmoothScrollController(
  duration: const Duration(milliseconds: 160),
  curve: Curves.easeOutCubic,
);

ListView(controller: controller, children: [...]);
```

- Wheel input during an animation adds to the previous target, so fast
  consecutive notches travel the full distance.
- Scrolling never passes the start or end of the list.
- Drag, scrollbar, keyboard and direct `jumpTo`/`animateTo` calls behave as
  with `ScrollController`. Wheel input during an `animateTo` of your own starts
  from the current position.
- `duration` and `curve` can be changed while attached; the next wheel input
  uses them. `Duration.zero` jumps as `ScrollController` does.
- In nested scroll views the outer view takes the wheel once the inner one
  reaches its end, as in Flutter by default.

### Limitations

- `NestedScrollView` routes wheel input through its own coordinator, so it is
  not smoothed.
- A scroll view whose scrollbar has a separate controller is smoothed only
  over its content, not over the scrollbar.

## Example

`example/` shows a default list and a smooth list side by side, with sliders
for the wheel scale and the duration.
