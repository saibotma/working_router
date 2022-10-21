import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class RenderInsetAwareContent extends RenderShiftedBox {
  RenderInsetAwareContent({
    required EdgeInsets viewInsets,
    BoxConstraints? childConstraints,
    EdgeInsets? padding,
    RenderBox? child,
  })  : _viewInsets = viewInsets,
        _childConstraints = childConstraints,
        _padding = padding,
        super(child);

  EdgeInsets _viewInsets;

  EdgeInsets get viewInsets => _viewInsets;

  set viewInsets(EdgeInsets value) {
    if (value == _viewInsets) {
      return;
    }
    _viewInsets = value;
    markNeedsLayout();
  }

  BoxConstraints? _childConstraints;

  BoxConstraints? get childConstraints => _childConstraints;

  set childConstraints(BoxConstraints? value) {
    if (value == _childConstraints) {
      return;
    }
    _childConstraints = value;
    markNeedsLayout();
  }

  EdgeInsets? _padding;

  EdgeInsets? get padding => _padding;

  set padding(EdgeInsets? value) {
    if (value == _padding) {
      return;
    }
    _padding = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final height = constraints.maxHeight;
    final width = constraints.maxWidth;

    final safeChildConstraints = childConstraints ?? constraints;
    final safePadding = padding ?? EdgeInsets.zero;
    // To calculate the bottom insets inside the child, it's size is required.
    final dryChildConstraints =
        safeChildConstraints.enforce(constraints.copyWith(
      maxWidth: constraints.maxWidth - safePadding.horizontal,
      maxHeight: constraints.maxHeight - safePadding.vertical,
    ));
    child!.layout(
      dryChildConstraints,
      parentUsesSize: true,
    );

    final childWidth = child!.size.width;
    final childHeight = child!.size.height;

    final visibleHeight = height - viewInsets.bottom;
    assert(visibleHeight >= 0);
    final contentHeight = safePadding.vertical + childHeight;
    final contentWidth = safePadding.horizontal + childWidth;
    final bottomViewInsets =
        max(0, childHeight + safePadding.bottom - visibleHeight);

    // Layout the child again to now be able to pass down the inner
    // view insets to the child.
    // Pass down the dryChildConstraints in order to have as loose constraints
    // as possible to allow the child change size.
    child!.layout(
      RenderInsetAwareContentBodyConstraints(
        bottomViewInsets: bottomViewInsets.toDouble(),
        minWidth: dryChildConstraints.minWidth,
        maxWidth: dryChildConstraints.maxWidth,
        minHeight: dryChildConstraints.minHeight,
        maxHeight: dryChildConstraints.maxHeight,
      ),
      // Is required, because otherwise will not re-layout when child size
      // changes.
      parentUsesSize: true,
    );
    final BoxParentData childParentData = child!.parentData! as BoxParentData;

    // Position the child to be centered horizontally and vertically inside
    // the padded box with bottom view insets additionally restraining the
    // size. If the child does not fit in the remaining visible space, then
    // it aligns to the top (with top padding). Content inside the child can
    // then use the provided inner bottom view insets to make content covered
    // by the view insets visible through a scrolling view for example.
    childParentData.offset = Offset(
      (width - contentWidth) / 2 + safePadding.left,
      max(0, visibleHeight - contentHeight) / 2 + safePadding.top,
    );
    size = Size(width, height);
  }
}

class RenderInsetAwareContentBodyConstraints extends BoxConstraints {
  final double bottomViewInsets;

  const RenderInsetAwareContentBodyConstraints({
    required this.bottomViewInsets,
    required double minWidth,
    required double maxWidth,
    required double minHeight,
    required double maxHeight,
  }) : super(
          minWidth: minWidth,
          maxWidth: maxWidth,
          minHeight: minHeight,
          maxHeight: maxHeight,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is RenderInsetAwareContentBodyConstraints &&
          runtimeType == other.runtimeType &&
          bottomViewInsets == other.bottomViewInsets;

  @override
  int get hashCode => super.hashCode ^ bottomViewInsets.hashCode;
}

class _InsetAwareContent extends SingleChildRenderObjectWidget {
  final BoxConstraints? childConstraints;
  final EdgeInsets? padding;

  const _InsetAwareContent({
    required Widget child,
    this.childConstraints,
    this.padding,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return RenderInsetAwareContent(
      viewInsets: mediaQuery.viewInsets,
      childConstraints: childConstraints,
      padding: padding,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderInsetAwareContent renderObject) {
    final mediaQuery = MediaQuery.of(context);
    renderObject
      ..viewInsets = mediaQuery.viewInsets
      ..childConstraints = childConstraints;
    super.updateRenderObject(context, renderObject);
  }
}

class InsetAwareContent extends StatelessWidget {
  final Widget child;
  final BoxConstraints? childConstraints;
  final EdgeInsets? padding;

  const InsetAwareContent({
    required this.child,
    this.childConstraints,
    this.padding,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _InsetAwareContent(
      childConstraints: childConstraints,
      padding: padding,
      child: LayoutBuilder(builder: (context, constraints) {
        // Layout gets called twice. The first time without custom constraints,
        // in order to calculate the size of the child. The second time
        // with custom constraints, which pass down bottom insets.
        if (constraints is RenderInsetAwareContentBodyConstraints) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
                viewInsets: mediaQuery.viewInsets
                    .copyWith(bottom: constraints.bottomViewInsets)),
            child: child,
          );
        }

        // Remove all media query data, because this is just used to
        // calculate the bare size of the child.
        return MediaQuery(data: const MediaQueryData(), child: child);
      }),
    );
  }
}
