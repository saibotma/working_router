import 'package:flutter/material.dart';

class ABCScreen extends StatelessWidget {
  final String id;
  final String b;
  final String c;

  const ABCScreen({
    required this.id,
    required this.b,
    required this.c,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 300,
        height: 300,
        child: Center(
          child: Text('$id, $b, $c'),
        ),
      ),
    );
  }
}
