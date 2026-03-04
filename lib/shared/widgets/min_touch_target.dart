import 'package:flutter/widgets.dart';

import 'package:android_app_template/core/design_tokens.dart';

class MinTouchTarget extends StatelessWidget {
  const MinTouchTarget({
    super.key,
    required this.child,
    this.minWidth = AppTouchTargets.minSize,
    this.minHeight = AppTouchTargets.minSize,
  });

  final Widget child;
  final double minWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      child: child,
    );
  }
}
