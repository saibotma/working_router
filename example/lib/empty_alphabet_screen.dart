import 'package:flutter/material.dart';

class EmptyAlphabetScreen extends StatelessWidget {
  const EmptyAlphabetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Text('Empty page'),
    );
  }
}
