import 'package:flutter/material.dart';

class LocationGuard extends StatefulWidget {
  final Widget child;

  final void Function()? afterUpdate;
  final Future<bool> Function()? beforeLeave;

  const LocationGuard({
    required this.child,
    this.afterUpdate,
    this.beforeLeave,
    Key? key,
  }) : super(key: key);

  @override
  State<LocationGuard> createState() => LocationGuardState();
}

class LocationGuardState extends State<LocationGuard> {
  @override
  void initState() {
    super.initState();
    AddLocationGuardMessage(state: this).dispatch(context);
  }

  @override
  void activate() {
    super.activate();
    AddLocationGuardMessage(state: this).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void deactivate() {
    // Need to call this in deactivate, because then the context
    // may not be used anymore.
    RemoveLocationGuardMessage(state: this).dispatch(context);
    super.deactivate();
  }
}

class AddLocationGuardMessage extends Notification {
  final LocationGuardState state;

  AddLocationGuardMessage({required this.state});
}

class RemoveLocationGuardMessage extends Notification {
  final LocationGuardState state;

  RemoveLocationGuardMessage({required this.state});
}
