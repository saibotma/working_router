import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'platform_modal/platform_modal_page.dart';

class ABCRouteNode extends Location<ABCRouteNode> {
  ABCRouteNode({
    super.id,
    required super.parentRouterKey,
  });

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('c');
    final id = builder.stringPathParam();
    final bParam = builder.stringQueryParam('b');
    final cParam = builder.stringQueryParam('c');

    builder.content = Content.builder((context, data) {
      return ABCScreen(
        id: data.param(id),
        b: data.param(bParam),
        c: data.param(cParam),
      );
    });
    builder.page = (key, child) {
      return PlatformModalPage<dynamic>(key: key, child: child);
    };
  }
}

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
