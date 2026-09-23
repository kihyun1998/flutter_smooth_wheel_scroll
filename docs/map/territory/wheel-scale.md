# Wheel scale

## What it is

Scales the delta of every mouse wheel `PointerScrollEvent` app-wide, before any
`Scrollable` sees it, by overriding `GestureBinding.handlePointerEvent`.

## Governing decisions

**None.** Issue #1 specifies it; no decision record exists.

## Design model

- The transform is a pure function, separate from the binding, because a test
  runs under `TestWidgetsFlutterBinding` and cannot install a custom binding.
- Importing the package installs nothing. A binding is app-wide and single, so
  only the app may install it, and it must do so before any other binding.
- Only `PointerDeviceKind.mouse` is scaled. On desktop, precision touchpads
  send `PointerPanZoom*` events; on the web, trackpads send
  `PointerScrollEvent`s of kind `trackpad`. Neither reaches the scaling
  branch.
- The rebuilt event forwards `respond` to the original. Without it,
  `Scrollable`'s `respond(allowPlatformDefault:)` would reach nothing.

## Code

- `lib/src/wheel_scale.dart` — `scaleWheelEvent`
- `lib/src/smooth_wheel_binding.dart` — `SmoothWheelBindingMixin`, `SmoothWheelBinding`

## Reference behaviour

Checked against Flutter `00b0c91f06` (the revision in `.metadata`):

- `packages/flutter/lib/src/gestures/events.dart` — `PointerScrollEvent`
  constructor: settles which fields a rebuilt event must carry.

## Cross-cutting invariants

- [SDK floor](../invariant/sdk-floor.md) — the Flutter version this code may
  assume.

## Blast radius

- [Smooth wheel scroll](smooth-wheel-scroll.md) — it animates whatever delta
  arrives, so a scale change changes its travel distance per notch.

## Known holes / open

- Handlers that read the delta's magnitude (not only its sign) see the scaled
  value. Known consumers are `flutter_table_plus` and `flutter_folderview`
  Ctrl+wheel zoom, which read the sign only.
- In Firefox the web engine reports trackpad scrolling as kind `mouse`, so it
  is scaled.
- On Windows and Linux, a touchpad the driver reports as wheel messages rather
  than as a precision touchpad arrives as kind `mouse`, so it is scaled. Read
  from the embedders' source, not tried.
- The binding itself has no test; only the transform does.
