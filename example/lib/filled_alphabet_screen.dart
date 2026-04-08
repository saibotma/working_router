import 'package:flutter/material.dart';

class FilledAlphabetScreen extends StatelessWidget {
  const FilledAlphabetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Colors.blueGrey,
        child: Column(
          children: [
            MaterialButton(
              child: const Text('push'),
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, _, __) => const Placeholder(),
                  ),
                );
              },
            ),
            const BackButton(),
          ],
        ),
      ),
    );
  }
}
