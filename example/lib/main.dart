import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';

void main() {
  SmoothWheelBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Smooth wheel scroll',
      home: ComparisonPage(),
    );
  }
}

/// A default list and a [SmoothScrollController] list side by side, with the
/// app-wide wheel scale and every [WheelMotion] option adjustable, and the
/// code for the current settings.
class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

enum _Kind { spring, curve, lerp }

const _curves = <String, Curve>{
  'easeOutCubic': Curves.easeOutCubic,
  'linear': Curves.linear,
  'decelerate': Curves.decelerate,
  'fastLinearToSlowEaseIn': Curves.fastLinearToSlowEaseIn,
  'fastEaseInToSlowEaseOut': Curves.fastEaseInToSlowEaseOut,
  'ease': Curves.ease,
  'easeIn': Curves.easeIn,
  'easeInToLinear': Curves.easeInToLinear,
  'easeInSine': Curves.easeInSine,
  'easeInQuad': Curves.easeInQuad,
  'easeInCubic': Curves.easeInCubic,
  'easeInQuart': Curves.easeInQuart,
  'easeInQuint': Curves.easeInQuint,
  'easeInExpo': Curves.easeInExpo,
  'easeInCirc': Curves.easeInCirc,
  'easeInBack': Curves.easeInBack,
  'easeOut': Curves.easeOut,
  'linearToEaseOut': Curves.linearToEaseOut,
  'easeOutSine': Curves.easeOutSine,
  'easeOutQuad': Curves.easeOutQuad,
  'easeOutQuart': Curves.easeOutQuart,
  'easeOutQuint': Curves.easeOutQuint,
  'easeOutExpo': Curves.easeOutExpo,
  'easeOutCirc': Curves.easeOutCirc,
  'easeOutBack': Curves.easeOutBack,
  'easeInOut': Curves.easeInOut,
  'easeInOutSine': Curves.easeInOutSine,
  'easeInOutQuad': Curves.easeInOutQuad,
  'easeInOutCubic': Curves.easeInOutCubic,
  'easeInOutCubicEmphasized': Curves.easeInOutCubicEmphasized,
  'easeInOutQuart': Curves.easeInOutQuart,
  'easeInOutQuint': Curves.easeInOutQuint,
  'easeInOutExpo': Curves.easeInOutExpo,
  'easeInOutCirc': Curves.easeInOutCirc,
  'easeInOutBack': Curves.easeInOutBack,
  'fastOutSlowIn': Curves.fastOutSlowIn,
  'slowMiddle': Curves.slowMiddle,
  'bounceIn': Curves.bounceIn,
  'bounceOut': Curves.bounceOut,
  'bounceInOut': Curves.bounceInOut,
  'elasticIn': Curves.elasticIn,
  'elasticOut': Curves.elasticOut,
  'elasticInOut': Curves.elasticInOut,
};

class _ComparisonPageState extends State<ComparisonPage> {
  final _defaultController = ScrollController();
  final _smoothController = SmoothScrollController();

  _Kind _kind = _Kind.spring;
  double _springMs = 400;
  double _bounce = 0;
  double _curveMs = 400;
  String _curveName = 'easeOutCubic';
  double _lerpMs = 60;

  void _update(VoidCallback change) {
    setState(change);
    _smoothController.motion = switch (_kind) {
      _Kind.spring => WheelMotion.spring(
        duration: Duration(milliseconds: _springMs.round()),
        bounce: _bounce,
      ),
      _Kind.curve => WheelMotion.curve(
        duration: Duration(milliseconds: _curveMs.round()),
        curve: _curves[_curveName]!,
      ),
      _Kind.lerp => WheelMotion.lerp(
        timeConstant: Duration(milliseconds: _lerpMs.round()),
      ),
    };
  }

  String _code(double scale) {
    final motion = switch (_kind) {
      _Kind.spring =>
        'WheelMotion.spring(\n'
            '    duration: Duration(milliseconds: ${_springMs.round()}),\n'
            '    bounce: ${_bounce.toStringAsFixed(2)},\n'
            '  )',
      _Kind.curve =>
        'WheelMotion.curve(\n'
            '    duration: Duration(milliseconds: ${_curveMs.round()}),\n'
            '    curve: Curves.$_curveName,\n'
            '  )',
      _Kind.lerp =>
        'WheelMotion.lerp(\n'
            '    timeConstant: Duration(milliseconds: ${_lerpMs.round()}),\n'
            '  )',
    };
    return '// main()\n'
        'SmoothWheelBinding.ensureInitialized(scale: ${scale.toStringAsFixed(2)});\n'
        '\n'
        'final controller = SmoothScrollController(\n'
        '  motion: const $motion,\n'
        ');';
  }

  @override
  void dispose() {
    _defaultController.dispose();
    _smoothController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final binding = SmoothWheelBinding.instance!;
    return Scaffold(
      appBar: AppBar(title: const Text('Smooth wheel scroll')),
      body: Row(
        children: [
          SizedBox(
            width: 380,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Option(
                  label: 'Wheel scale',
                  help:
                      'App-wide. Multiplies the distance of one wheel notch '
                      '(about 60 px on Windows). Below 1 is slower, above 1 '
                      'faster.',
                  value: binding.wheelScale,
                  min: 0.1,
                  max: 2.0,
                  display: binding.wheelScale.toStringAsFixed(2),
                  onChanged: (v) => setState(() => binding.wheelScale = v),
                ),
                const SizedBox(height: 16),
                SegmentedButton<_Kind>(
                  segments: [
                    for (final kind in _Kind.values)
                      ButtonSegment(value: kind, label: Text(kind.name)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => _update(() => _kind = s.single),
                ),
                const SizedBox(height: 8),
                _Help(switch (_kind) {
                  _Kind.spring =>
                    'Follows the target like a spring and keeps its speed '
                        'when you keep scrolling. The default.',
                  _Kind.curve =>
                    'Plays a curve to the target, and starts it over on every '
                        'notch.',
                  _Kind.lerp =>
                    'Covers a fixed share of the remaining distance per unit '
                        'of time: fast at first, slowing as it arrives.',
                }),
                const SizedBox(height: 16),
                ..._motionOptions(),
                const SizedBox(height: 24),
                _CodeView(_code(binding.wheelScale)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _ItemList(
              title: 'ScrollController',
              controller: _defaultController,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _ItemList(
              title: 'SmoothScrollController',
              controller: _smoothController,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _motionOptions() => switch (_kind) {
    _Kind.spring => [
      _Option(
        label: 'Duration',
        help:
            'How long it takes to settle; about 99% of the way is covered by '
            'then. 0 jumps.',
        value: _springMs,
        min: 0,
        max: 1000,
        display: '${_springMs.round()} ms',
        onChanged: (v) => _update(() => _springMs = v),
      ),
      _Option(
        label: 'Bounce',
        help:
            '0 stops at the target. Above 0 passes it and comes back; below '
            '0 settles more slowly. Never passes the list ends.',
        value: _bounce,
        min: -0.9,
        max: 0.9,
        display: _bounce.toStringAsFixed(2),
        onChanged: (v) => _update(() => _bounce = v),
      ),
    ],
    _Kind.curve => [
      _Option(
        label: 'Duration',
        help: 'How long one curve takes. 0 jumps.',
        value: _curveMs,
        min: 0,
        max: 1000,
        display: '${_curveMs.round()} ms',
        onChanged: (v) => _update(() => _curveMs = v),
      ),
      const Text('Curve'),
      DropdownButton<String>(
        isExpanded: true,
        value: _curveName,
        items: [
          for (final name in _curves.keys)
            DropdownMenuItem(value: name, child: Text(name)),
        ],
        onChanged: (v) => _update(() => _curveName = v!),
      ),
      const _Help(
        'Any Curve works, including your own. These are the named ones in '
        'Curves.',
      ),
    ],
    _Kind.lerp => [
      _Option(
        label: 'Time constant',
        help:
            'About 63% of the remaining distance is covered per time '
            'constant. Smaller is snappier. 0 jumps.',
        value: _lerpMs,
        min: 0,
        max: 300,
        display: '${_lerpMs.round()} ms',
        onChanged: (v) => _update(() => _lerpMs = v),
      ),
    ],
  };
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.help,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final String help;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(display),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
        _Help(help),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Help extends StatelessWidget {
  const _Help(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.title, required this.controller});

  final String title;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: Scrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 500,
              itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
            ),
          ),
        ),
      ],
    );
  }
}
