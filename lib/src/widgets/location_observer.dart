import 'dart:async';

import 'package:flutter/material.dart';
import 'package:working_router/src/transition_decision.dart';

class LocationObserver extends StatefulWidget {
  final Widget child;

  /// Called after the location of this observer got added to the location list.
  final void Function()? afterEnter;

  /// Called after the location list changed, but the location of this observer
  /// already was and still is in the location list.
  final void Function()? afterUpdate;

  /// Decides whether this observer's location may be removed.
  ///
  /// Keep this callback short. Routing is paused until it completes.
  /// Use it for quick UI decisions like confirmation dialogs, not for
  /// cleanup or long-running work.
  final Future<bool> Function()? canLeave;

  /// Called after a committed transition removes this observer's location.
  ///
  /// Returned futures do not delay navigation or other observers. Capture any
  /// dependencies needed by asynchronous work before the observer unmounts.
  // ignore: avoid_futureor_void
  final FutureOr<void> Function(RouteTransition transition)? afterLeave;

  const LocationObserver({
    required this.child,
    this.afterEnter,
    this.afterUpdate,
    this.canLeave,
    this.afterLeave,
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
