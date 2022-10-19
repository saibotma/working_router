import 'package:flutter/material.dart';
import 'package:navigator_test/my_route_information_parser.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/my_router_delegate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final myRouter = MyRouter();
  late final routerDelegate = MyRouterDelegate(myRouter: myRouter);
  final routeInformationParser = MyRouteInformationParser();

  @override
  Widget build(BuildContext context) {
    return MyRouterProvider(
      myRouter: myRouter,
      child: MaterialApp.router(
        routerDelegate: routerDelegate,
        routeInformationParser: routeInformationParser,
      ),
    );
  }
}
