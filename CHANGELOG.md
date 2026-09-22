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
