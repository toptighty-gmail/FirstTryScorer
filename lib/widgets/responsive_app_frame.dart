import 'package:flutter/material.dart';

class ResponsiveAppFrame extends StatelessWidget {
  final Widget child;
  final Widget footer;

  const ResponsiveAppFrame({
    super.key,
    required this.child,
    required this.footer,
  });

  static double maxWidthFor(double viewportWidth) {
    if (viewportWidth < 600) return viewportWidth;
    if (viewportWidth < 1024) return 800;
    if (viewportWidth < 1440) return 1120;
    return 1280;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = maxWidthFor(constraints.maxWidth);
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: SizedBox(width: double.infinity, child: child),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: SizedBox(width: double.infinity, child: footer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
