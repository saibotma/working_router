import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'pop_until_target.dart';

class ADCScreen extends StatelessWidget {
  const ADCScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green,
      child: SizedBox(
        width: 300,
        height: 300,
        child: LocationObserver(
          beforeLeave: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) {
                return Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                    child: MaterialButton(
                      child: const Text('Press to allow pop.'),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ),
                );
              },
            );
            return result ?? false;
          },
          child: Center(
            child: MaterialButton(
              child: const Text('Press to pop to FallbackLocation.'),
              onPressed: () {
                WorkingRouter.of(context).routeBackUntil(
                  (location) => location.hasTag(PopUntilTarget()),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
