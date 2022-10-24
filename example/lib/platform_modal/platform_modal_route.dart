import 'package:flutter/material.dart';
import 'platform_modal.dart';
import 'platform_modal_page.dart';

class PlatformModalRoute<T> extends PopupRoute<T> {
  AnimationController? _animationController;

  final bool isScrollControlled;
  final bool isDragEnabled;
  final BoxConstraints? bottomSheetConstraints;
  final BoxConstraints? dialogConstraints;
  final void Function(BuildContext)? handleDismiss;

  @override
  final String? barrierLabel;

  PlatformModalRoute({
    required this.isScrollControlled,
    required this.isDragEnabled,
    required PlatformModalPage<T> page,
    this.bottomSheetConstraints,
    this.dialogConstraints,
    this.barrierLabel,
    this.handleDismiss,
  }) : super(settings: page);

  @override
  Color? get barrierColor => Colors.black54;

  @override
  // Is handled custom, because the default behaviour does just
  // pop, however in some cases this is not desired.
  bool get barrierDismissible => false;

  PlatformModalPage<T> get _page => settings as PlatformModalPage<T>;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // By definition, the bottom sheet is aligned to the bottom of the page
    // and isn't exposed to the top padding of the MediaQuery.
    // TODO(saibotma): https://gitlab.com/appella/appella_app/-/issues/439
    return Stack(
      children: [
        GestureDetector(onTap: () => _handleDismiss(context)),
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Builder(builder: (context) {
            // TODO(saibotma): Use Appella theme?
            final BottomSheetThemeData sheetTheme =
                Theme.of(context).bottomSheetTheme;

            return PlatformModal<T>(
              animation: animation,
              animationController: _animationController,
              isScrollControlled: isScrollControlled,
              isDragEnabled: isDragEnabled,
              backgroundColor:
                  sheetTheme.modalBackgroundColor ?? sheetTheme.backgroundColor,
              bottomSheetConstraints: bottomSheetConstraints,
              dialogConstraints: dialogConstraints,
              child: _page.child,
            );
          }),
        ),
      ],
    );
  }

  @override
  AnimationController createAnimationController() {
    assert(_animationController == null);
    _animationController = BottomSheet.createAnimationController(navigator!);
    return _animationController!;
  }

  void _handleDismiss(BuildContext context) {
    handleDismiss != null
        ? handleDismiss!(context)
        : Navigator.of(context).maybePop();
  }
}
