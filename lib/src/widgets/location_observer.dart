import 'package:flutter/material.dart';

class LocationObserver extends StatefulWidget {
  final Widget child;

  /// Called after the location of this observer got added to the location list.
  final void Function()? afterEnter;

  /// Called after the location list changed, but the location of this observer
  /// already was and still is in the location list.
  final void Function()? afterUpdate;

  const LocationObserver({
    required this.child,
    this.afterEnter,
    this.afterUpdate,
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
