import 'package:flutter/material.dart';

enum ScreenSize { small, medium, large }

const smallToMediumBreakpoint = 600;
const mediumToLargeBreakpoint = 900;

class Responsive extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize size) builder;

  const Responsive({required this.builder, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      ScreenSize size = ScreenSize.small;
      if (width > smallToMediumBreakpoint && width <= mediumToLargeBreakpoint) {
        size = ScreenSize.medium;
      } else if (width > mediumToLargeBreakpoint) {
        size = ScreenSize.large;
      }

      return builder(context, size);
    });
  }
}
