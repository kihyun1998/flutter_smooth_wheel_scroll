## 0.1.2

* Fix: in nested scroll views, wheel input that arrives while the inner
  view's motion is already heading for its end now scrolls the outer view, as
  with `ScrollController`. It was dropped until the motion settled.

## 0.1.1

* Lower the minimum Flutter version to 3.32.0 and Dart to 3.8.0, from 3.41.0
  and 3.11.5. No API or behavior change.

## 0.1.0

Initial release.

* `SmoothScrollController`: animates mouse wheel scrolling per scroll view.
  Wheel input during a motion adds to the previous target, scrolling never
  passes the list ends, and items stay tappable while a motion settles.
* `WheelMotion`: how the controller moves.
  * `WheelMotion.spring` (default: 400 ms, no bounce) keeps its velocity when
    the target moves.
  * `WheelMotion.curve` (default: 400 ms, `Curves.easeOutCubic`) plays any
    `Curve`.
  * `WheelMotion.lerp` (default: 60 ms time constant) eases toward the target.
* `SmoothWheelBinding` and `SmoothWheelBindingMixin`: scale mouse wheel
  distance app-wide, adjustable at runtime.
* `scaleWheelEvent`: the event transform behind the binding.
