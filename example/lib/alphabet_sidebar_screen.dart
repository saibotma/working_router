import 'package:flutter/material.dart';

import 'alphabet_sidebar.dart';

class AlphabetSidebarScreen extends StatelessWidget {
  const AlphabetSidebarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AlphabetSidebar(showInnerShellBypassRoute: false),
    );
  }
}
