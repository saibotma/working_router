import 'package:flutter/cupertino.dart';

import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_sailor.dart';

abstract class WorkingRouterDataSailor<ID>
    implements WorkingRouterSailor<ID>, ChangeNotifier {
  WorkingRouterData<ID> get data;
}
