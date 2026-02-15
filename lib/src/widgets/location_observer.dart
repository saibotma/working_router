import 'package:flutter/material.dart';

class LocationObserver extends StatefulWidget {
  final Widget child;

  /// Called after the location of this observer got added to the location list.
  final void Function()? afterEnter;

  /// Called after the location list changed, but the location of this observer
  /// already was and still is in the location list.
  final void Function()? afterUpdate;

  /// Called before the location of this observer will be removed
  /// from the location list.
  ///
  /// Keep this callback short. Routing is paused until it completes.
  /// Use it for quick UI decisions like confirmation dialogs, not for
  /// long-running work like network requests or expensive I/O.
  final Future<bool> Function()? beforeLeave;

  const LocationObserver({
    required this.child,
    this.afterEnter,
    this.afterUpdate,
    this.beforeLeave,
    super.key,
  });

  @override
  State<LocationObserver> createState() => LocationObserverState();
}

class LocationObserverState extends State<LocationObserver> {
  @override
  void initState() {
    super.initState();
    AddLocationObserverMessage(state: this).dispatch(context);
  }

  @override
  void activate() {
    super.activate();
    AddLocationObserverMessage(state: this).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void deactivate() {
    // Need to call this in deactivate, because then the context
    // may not be used anymore.
    RemoveLocationObserverMessage(state: this).dispatch(context);
    super.deactivate();
  }
}

class AddLocationObserverMessage extends Notification {
  final LocationObserverState state;

  AddLocationObserverMessage({required this.state});
}

class RemoveLocationObserverMessage extends Notification {
  final LocationObserverState state;

  RemoveLocationObserverMessage({required this.state});
}
