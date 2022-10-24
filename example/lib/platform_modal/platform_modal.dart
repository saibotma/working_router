import 'dart:math';

import 'package:flutter/material.dart';

import '../platform.dart';
import '../responsive.dart';
import 'bottom_sheet_suspended_curve.dart';
import 'render_inset_aware_content.dart';

const Curve _modalBottomSheetCurve = decelerateEasing;

class PlatformModal<T> extends StatefulWidget {
  final Widget child;
  final Animation<double> animation;
  final AnimationController? animationController;
  final bool isScrollControlled;
  final bool isDragEnabled;
  final Color? backgroundColor;
  final BoxConstraints? bottomSheetConstraints;
  final BoxConstraints? dialogConstraints;
  final bool isInsetAware;

  const PlatformModal({
    required this.child,
    required this.animation,
    required this.animationController,
    required this.isScrollControlled,
    required this.isDragEnabled,
    this.backgroundColor,
    this.bottomSheetConstraints,
    this.dialogConstraints,
    this.isInsetAware = false,
    Key? key,
  }) : super(key: key);

  @override
  _PlatformModalState<T> createState() => _PlatformModalState<T>();
}

class _PlatformModalState<T> extends State<PlatformModal<T>> {
  ParametricCurve<double> animationCurve = _modalBottomSheetCurve;

  String _getRouteLabel(MaterialLocalizations localizations) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // TODO(saibotma): Why is this an empty string?
        return '';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return localizations.dialogLabel;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    // Allow the bottom sheet to track the user's finger accurately.
    animationCurve = Curves.linear;
  }

  void _handleDragEnd(DragEndDetails details, {bool? isClosing}) {
    // Allow the bottom sheet to animate smoothly from its current position.
    animationCurve = BottomSheetSuspendedCurve(
      widget.animation.value,
      curve: _modalBottomSheetCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final String routeLabel = _getRouteLabel(localizations);

    return Responsive(
      builder: (context, size) {
        if (isMobile && size == ScreenSize.small) {
          return AnimatedBuilder(
            animation: widget.animation,
            child: BottomSheet(
              animationController: widget.animationController,
              onClosing: () => Navigator.pop(context),
              builder: (_) => widget.child,
              backgroundColor: widget.backgroundColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              constraints: widget.bottomSheetConstraints ??
                  BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.85,
                    maxWidth: 600,
                  ),
              enableDrag: widget.isDragEnabled,
              onDragStart: _handleDragStart,
              onDragEnd: _handleDragEnd,
            ),
            builder: (BuildContext context, Widget? child) {
              // Disable the initial animation when accessible navigation is on so
              // that the semantics are added to the tree at the correct time.
              final double animationValue = animationCurve.transform(
                mediaQuery.accessibleNavigation ? 1.0 : widget.animation.value,
              );
              return Semantics(
                scopesRoute: true,
                namesRoute: true,
                label: routeLabel,
                explicitChildNodes: true,
                child: ClipRect(
                  child: CustomSingleChildLayout(
                    delegate: _ModalBottomSheetLayout(
                      animationValue,
                      widget.isScrollControlled,
                    ),
                    child: child,
                  ),
                ),
              );
            },
          );
        }

        final curvedAnimation =
            widget.animation.drive(CurveTween(curve: Curves.easeOut));

        final borderRadius = BorderRadius.circular(12);
        return ScaleTransition(
          scale: curvedAnimation.drive(Tween(begin: 0.9, end: 1.0)),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: LayoutBuilder(builder: (context, constraints) {
              // Got those values by playing around.
              final double widthHeightMin =
                  min(constraints.maxWidth, constraints.maxHeight);
              double width = widthHeightMin * 0.75;
              double height = widthHeightMin * 0.85;
              if (constraints.maxWidth <= smallToMediumBreakpoint) {
                width = constraints.maxWidth;
                height = constraints.maxHeight * 0.8;
              }
              return InsetAwareContent(
                childConstraints: widget.dialogConstraints ??
                    BoxConstraints(
                      maxWidth: width,
                      maxHeight: height,
                    ),
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Container(
                    color: Colors.white,
                    child: widget.child,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// Copy from https://api.flutter.dev/flutter/material/showModalBottomSheet.html
class _ModalBottomSheetLayout extends SingleChildLayoutDelegate {
  _ModalBottomSheetLayout(this.progress, this.isScrollControlled);

  final double progress;
  final bool isScrollControlled;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      maxHeight: isScrollControlled
          ? constraints.maxHeight
          : constraints.maxHeight * 9.0 / 16.0,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset(0.0, size.height - childSize.height * progress);
  }

  @override
  bool shouldRelayout(_ModalBottomSheetLayout oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
