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
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    RemoveLocationGuardMessage(state: this).dispatch(context);
    super.dispose();
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
