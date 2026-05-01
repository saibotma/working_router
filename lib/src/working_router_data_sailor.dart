import 'package:flutter/cupertino.dart';

import 'package:working_router/src/route_target.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_sailor.dart';

abstract class WorkingRouterDataSailor
    implements WorkingRouterSailor, ChangeNotifier {
  WorkingRouterData get data;

  RouteTarget get routeTarget;
}
