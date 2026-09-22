// PROTOTYPE — throwaway, for issue #3. Not part of the package.
//
// Question: which wheel motion feels best — the current curve restart, an
// exponential lerp toward the target, or a spring that keeps its velocity?
//
// Run: cd example && flutter run -d windows -t lib/prototype_wheel_motion.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';

void main() {
  SmoothWheelBinding.ensureInitialized(scale: 1.0);
  runApp(const MaterialApp(home: _ProtoPage()));
}

enum _Mode { jump, curve, lerp, spring }

/// Every tunable, shared by all columns and read on every wheel input/frame.
class _Params {
  double curveMs = 160;
  int curveIndex = 0;
  double lerpTauMs = 60;
  double springDurationMs = 350;
  double springBounce = 0.0;
}

const _curves = <String, Curve>{
  'easeOutCubic': Curves.easeOutCubic,
  'easeOut': Curves.easeOut,
  'decelerate': Curves.decelerate,
  'linear': Curves.linear,
  'easeInOut': Curves.easeInOut,
};

final _params = _Params();

// ---------------------------------------------------------------------------
// Controller / position

class _ProtoController extends ScrollController {
  _ProtoController(this.mode);
  final _Mode mode;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _ProtoPosition(
    mode: mode,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

class _ProtoPosition extends ScrollPositionWithSingleContext {
  _ProtoPosition({
    required this.mode,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final _Mode mode;
  ScrollActivity? _wheelActivity;
  double _curveTarget = 0;

  /// For the on-screen readout.
  double get wheelVelocity => activity?.velocity ?? 0;

  double get wheelTarget => switch (_wheelActivity) {
    final _MotionActivity a when identical(activity, a) => a.target,
    _ when identical(activity, _wheelActivity) => _curveTarget,
    _ => pixels,
  };

  @override
  void pointerScroll(double delta) {
    if (mode == _Mode.jump || delta == 0.0) {
      super.pointerScroll(delta);
      return;
    }
    final animating =
        _wheelActivity != null && identical(activity, _wheelActivity);
    final direction = delta > 0
        ? ScrollDirection.reverse
        : ScrollDirection.forward;

    if (mode == _Mode.curve) {
      final base = animating ? _curveTarget : pixels;
      final target = (base + delta).clamp(minScrollExtent, maxScrollExtent);
      if (animating ? target == _curveTarget : target == pixels) return;
      _curveTarget = target;
      animateTo(
        target,
        duration: Duration(milliseconds: _params.curveMs.round()),
        curve: _curves.values.elementAt(_params.curveIndex),
      );
      _wheelActivity = activity;
      updateUserScrollDirection(direction);
      return;
    }

    if (animating) {
      final a = _wheelActivity! as _MotionActivity;
      a.retarget((a.target + delta).clamp(minScrollExtent, maxScrollExtent));
      return;
    }
    final target = (pixels + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == pixels) return;
    final a = _MotionActivity(
      this,
      mode: mode,
      from: pixels,
      target: target,
      vsync: context.vsync,
    );
    beginActivity(a);
    _wheelActivity = a;
    updateUserScrollDirection(direction);
  }
}

/// Moves toward [target] every frame, keeping position and velocity continuous
/// when the target changes.
class _MotionActivity extends ScrollActivity {
  _MotionActivity(
    super.delegate, {
    required this.mode,
    required double from,
    required this.target,
    required TickerProvider vsync,
  }) : _x = from {
    _startSpring(Duration.zero);
    _ticker = vsync.createTicker(_tick)..start();
  }

  final _Mode mode;
  double target;
  double _x;
  double _v = 0;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  // Spring state: a fresh simulation from (x, v) at every retarget.
  SpringSimulation? _spring;
  Duration _springStart = Duration.zero;

  void retarget(double newTarget) {
    target = newTarget;
    if (mode == _Mode.spring) _startSpring(_last);
  }

  void _startSpring(Duration now) {
    if (mode != _Mode.spring) return;
    _spring = SpringSimulation(
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: _params.springDurationMs.round()),
        bounce: _params.springBounce,
      ),
      _x,
      target,
      _v,
      tolerance: const Tolerance(distance: 0.5, velocity: 5),
    );
    _springStart = now;
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    bool done;

    if (mode == _Mode.lerp) {
      final k = 1 - math.exp(-dt / (_params.lerpTauMs / 1000));
      final next = _x + (target - _x) * k;
      _v = dt > 0 ? (next - _x) / dt : 0;
      _x = next;
      done = (target - _x).abs() < 0.5;
    } else {
      final t = (elapsed - _springStart).inMicroseconds / 1e6;
      _x = _spring!.x(t);
      _v = _spring!.dx(t);
      done = _spring!.isDone(t);
    }
    if (done) _x = target;

    if (delegate.setPixels(_x).abs() > 0.01) {
      delegate.goIdle();
      return;
    }
    if (done) delegate.goBallistic(0);
  }

  @override
  bool get shouldIgnorePointer => false;
  @override
  bool get isScrolling => true;
  @override
  double get velocity => _v;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// UI

class _ProtoPage extends StatefulWidget {
  const _ProtoPage();
  @override
  State<_ProtoPage> createState() => _ProtoPageState();
}

class _ProtoPageState extends State<_ProtoPage> {
  final _controllers = {for (final m in _Mode.values) m: _ProtoController(m)};
  final _visible = {for (final m in _Mode.values) m: true};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String shown,
    ValueChanged<double> onChanged,
  ) => Row(
    children: [
      SizedBox(width: 150, child: Text(label)),
      Expanded(
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
      SizedBox(width: 70, child: Text(shown, textAlign: TextAlign.end)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final binding = SmoothWheelBinding.instance!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROTOTYPE #3 — wheel motion'),
        actions: [
          for (final m in _Mode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(m.name),
                selected: _visible[m]!,
                onSelected: (v) => setState(() => _visible[m] = v),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              children: [
                for (final w in [
                  _slider(
                    'wheel scale',
                    binding.wheelScale,
                    0.1,
                    1.5,
                    binding.wheelScale.toStringAsFixed(2),
                    (v) => setState(() => binding.wheelScale = v),
                  ),
                  _slider(
                    'curve: duration',
                    _params.curveMs,
                    40,
                    500,
                    '${_params.curveMs.round()} ms',
                    (v) => setState(() => _params.curveMs = v),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 150, child: Text('curve: type')),
                      DropdownButton<int>(
                        value: _params.curveIndex,
                        items: [
                          for (var i = 0; i < _curves.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(_curves.keys.elementAt(i)),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _params.curveIndex = v!),
                      ),
                    ],
                  ),
                  _slider(
                    'lerp: τ (time constant)',
                    _params.lerpTauMs,
                    10,
                    200,
                    '${_params.lerpTauMs.round()} ms',
                    (v) => setState(() => _params.lerpTauMs = v),
                  ),
                  _slider(
                    'spring: duration',
                    _params.springDurationMs,
                    100,
                    800,
                    '${_params.springDurationMs.round()} ms',
                    (v) => setState(() => _params.springDurationMs = v),
                  ),
                  _slider(
                    'spring: bounce',
                    _params.springBounce,
                    -0.5,
                    0.5,
                    _params.springBounce.toStringAsFixed(2),
                    (v) => setState(() => _params.springBounce = v),
                  ),
                ])
                  SizedBox(width: 520, child: w),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                for (final m in _Mode.values)
                  if (_visible[m]!)
                    Expanded(
                      child: _Column(mode: m, controller: _controllers[m]!),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.mode, required this.controller});
  final _Mode mode;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              mode.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // Live state: pixels, target, velocity.
          ListenableBuilder(
            listenable: controller,
            builder: (_, _) {
              if (!controller.hasClients) return const SizedBox(height: 20);
              final p = controller.position as _ProtoPosition;
              return Text(
                'px ${p.pixels.toStringAsFixed(0)}  '
                'target ${p.wheelTarget.toStringAsFixed(0)}  '
                'v ${p.wheelVelocity.toStringAsFixed(0)}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              );
            },
          ),
          Expanded(
            child: Scrollbar(
              controller: controller,
              child: ListView.builder(
                controller: controller,
                itemCount: 1000,
                itemExtent: 48,
                itemBuilder: (_, i) => ColoredBox(
                  color: i.isEven ? Colors.white : Colors.grey.shade100,
                  child: Center(child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
