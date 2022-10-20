import 'package:flutter/material.dart';
import 'package:navigator_test/locations/location.dart';

class LocationGuard extends StatefulWidget {
  final Widget child;
  final bool Function(Location location) guard;
  final Future<bool> Function() mayLeave;

  const LocationGuard({
    required this.child,
    required this.guard,
    required this.mayLeave,
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
