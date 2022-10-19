import 'package:flutter/material.dart';

import 'platform_modal_route.dart';

class PlatformModalPage<T> extends Page<T> {
  final Widget child;
  final bool isScrollControlled;
  final bool isDragEnabled;
  final BoxConstraints? bottomSheetConstraints;
  final BoxConstraints? dialogConstraints;
  final void Function(BuildContext context)? handleDismiss;

  const PlatformModalPage({
    required this.child,
    this.isScrollControlled = true,
    this.isDragEnabled = true,
    this.bottomSheetConstraints,
    this.dialogConstraints,
    this.handleDismiss,
    LocalKey? key,
    String? name,
  }) : super(key: key, name: name);

  @override
  Route<T> createRoute(BuildContext context) {
    return PlatformModalRoute<T>(
      isScrollControlled: isScrollControlled,
      isDragEnabled: isDragEnabled,
      page: this,
      bottomSheetConstraints: bottomSheetConstraints,
      dialogConstraints: dialogConstraints,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      handleDismiss: handleDismiss,
    );
  }
}
