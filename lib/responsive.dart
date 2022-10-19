import 'package:flutter/material.dart';

enum ScreenSize { Small, Medium, Large }

const smallToMediumBreakpoint = 600;
const mediumToLargeBreakpoint = 900;

class Responsive extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize size) builder;

  const Responsive({required this.builder, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      ScreenSize size = ScreenSize.Small;
      if (width > smallToMediumBreakpoint && width <= mediumToLargeBreakpoint) {
        size = ScreenSize.Medium;
      } else if (width > mediumToLargeBreakpoint) {
        size = ScreenSize.Large;
      }

      return builder(context, size);
    });
  }
}
