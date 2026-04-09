import 'package:flutter/material.dart';

class ShellBypassScreen extends StatelessWidget {
  const ShellBypassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4CC),
      body: Center(
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB54D),
            border: Border.all(
              color: const Color(0xFF9A4F00),
              width: 4,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bypassing the inner shell',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Color(0xFF5C2E00),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'This route is owned by the outer shell navigator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'The blue inner-shell frame disappears because /a/d/e does '
                'not render inside that nested navigator.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
