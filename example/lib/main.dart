import 'package:flutter/material.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';

void main() {
  SmoothWheelBinding.ensureInitialized(scale: 0.4);
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

/// A default list and a [SmoothScrollController] list side by side, with
/// sliders for the app-wide wheel scale and the smooth animation duration.
class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  final _defaultController = ScrollController();
  final _smoothController = SmoothScrollController();

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
      body: Column(
        children: [
          _LabeledSlider(
            label: 'Wheel scale',
            value: binding.wheelScale,
            min: 0.1,
            max: 1.0,
            display: binding.wheelScale.toStringAsFixed(2),
            onChanged: (v) => setState(() => binding.wheelScale = v),
          ),
          _LabeledSlider(
            label: 'Duration',
            value: _smoothController.duration.inMilliseconds.toDouble(),
            min: 0,
            max: 500,
            display: '${_smoothController.duration.inMilliseconds} ms',
            onChanged: (v) => setState(
              () => _smoothController.duration = Duration(
                milliseconds: v.round(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
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
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 64, child: Text(display, textAlign: TextAlign.end)),
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
