import 'package:flutter/cupertino.dart';

import 'working_router_data.dart';
import 'working_router_sailor.dart';

abstract class WorkingRouterDataSailor<ID>
    implements WorkingRouterSailor<ID>, ChangeNotifier {
  WorkingRouterData<ID> get data;
}
