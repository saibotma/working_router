import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:working_router/src/route_generation/route_helpers_generator.dart';

Builder workingRouterRouteHelpersBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [RouteHelpersGenerator()],
    'working_router',
  );
}
