# SDK floor

## The fact

The package requires Flutter 3.32.0 and Dart 3.8.0 (`pubspec.yaml` —
`environment`). The floor is the first stable release carrying every framework
API the code calls; Dart 3.8 is the SDK that Flutter 3.32 ships.

## Where it holds

| API | Code | First stable |
|---|---|---|
| `SpringDescription.withDurationAndBounce` | `lib/src/smooth_scroll_controller.dart` — `_SpringFollower` | **3.32.0** |
| `PointerScrollEvent(onRespond:)` | `lib/src/wheel_scale.dart` — `scaleWheelEvent` | 3.24.0 |
| `PointerScrollEvent(viewId:)` | `lib/src/wheel_scale.dart` — `scaleWheelEvent` | 3.13.0 |
| `ScrollController(onAttach:, onDetach:)` | `lib/src/smooth_scroll_controller.dart` — `SmoothScrollController` | 3.13.0 |
| sealed classes, switch expressions, patterns | `lib/src/wheel_motion.dart`, `_Follower` | Dart 3.0 (Flutter 3.10) |

Found with `git log -S<symbol>` in the Flutter SDK checkout, then
`git tag --contains` for the first `x.y.0` tag. Between 3.32.0 and 3.41.9 the
body of `withDurationAndBounce` changed only in formatting, so the spring moves
the same across the supported range.

## Why not lower

- **3.32 → 3.24:** copy the duration/bounce mapping into the package. Chosen
  against: it duplicates framework math to maintain, for SDKs over a year old
  on a desktop audience that tracks stable.
- **3.24 → 3.13:** drop `onRespond`. This changes behaviour: `Scrollable`'s
  `respond(allowPlatformDefault:)` would reach nothing, so the web's platform
  default scroll breaks (see [Wheel scale](../territory/wheel-scale.md)).
- **3.13 → 3.10:** drop `viewId`. A rebuilt event would target view 0 in a
  multi-view app.
- **Below 3.10:** Dart 3.0 is needed by `WheelMotion`'s sealed hierarchy.

## How it is checked

- The analyzer takes the language version from the `sdk:` lower bound, so
  `flutter analyze` rejects syntax newer than Dart 3.8 on any current SDK.
- Framework APIs newer than 3.32 are **not** caught by any gate: CI and local
  runs use the SDK in `.metadata`. A new framework call means re-running the
  search above, or raising the floor.

## Territories

- [Smooth wheel scroll](../territory/smooth-wheel-scroll.md)
- [Wheel scale](../territory/wheel-scale.md)
