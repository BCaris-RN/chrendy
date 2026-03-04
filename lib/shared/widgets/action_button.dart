import 'package:flutter/material.dart';

import 'package:android_app_template/shared/widgets/min_touch_target.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final button = primary
        ? ElevatedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));

    return MinTouchTarget(child: button);
  }
}
