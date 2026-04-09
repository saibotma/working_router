import 'package:flutter/material.dart';

import 'alphabet_sidebar.dart';

class NestedScreen extends StatelessWidget {
  final Widget child;

  const NestedScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6EEC5),
      child: Column(
        children: [
          Container(
            height: 44,
            width: double.infinity,
            color: const Color(0xFFD5B74A),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              'Outer shell navigator',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF3F2E00),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const AlphabetSidebar(showInnerShellBypassRoute: true),
                Expanded(
                  child: ClipRect(
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
