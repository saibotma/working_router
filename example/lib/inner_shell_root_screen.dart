import 'package:flutter/material.dart';

class InnerShellRootScreen extends StatelessWidget {
  const InnerShellRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Inner shell root page',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'When this card is visible, the active route is rendered inside '
            'the inner shell navigator.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'Navigate to /a/d/e to bypass this navigator and render the page '
            'directly on the outer shell.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
