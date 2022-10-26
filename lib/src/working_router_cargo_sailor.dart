import 'working_router_data.dart';
import 'working_router_sailor.dart';

abstract class WorkingRouterCargoSailor<ID> implements WorkingRouterSailor<ID> {
  WorkingRouterData<ID> get data;
}
