# flutter_smooth_wheel_scroll example

A default list next to a smooth one. Every option is adjustable with an
explanation, and the code for the current settings is shown ready to copy.

```sh
flutter run -d windows
```

The smallest setup:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_smooth_wheel_scroll/flutter_smooth_wheel_scroll.dart';

void main() {
  SmoothWheelBinding.ensureInitialized(scale: 0.5); // optional
  runApp(const MaterialApp(home: SmoothList()));
}

class SmoothList extends StatefulWidget {
  const SmoothList({super.key});

  @override
  State<SmoothList> createState() => _SmoothListState();
}

class _SmoothListState extends State<SmoothList> {
  final _controller = SmoothScrollController(
    motion: const WheelMotion.spring(duration: Duration(milliseconds: 400)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        controller: _controller,
        itemCount: 500,
        itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
      ),
    );
  }
}
```

The full comparison app is in [`lib/main.dart`](lib/main.dart).
