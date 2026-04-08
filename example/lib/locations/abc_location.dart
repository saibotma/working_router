import 'package:working_router/working_router.dart';

import '../abc_screen.dart';
import '../location_id.dart';
import '../platform_modal/platform_modal_page.dart';

class ABCLocation extends Location<LocationId> {
  ABCLocation({
    super.id,
    required super.parentNavigatorKey,
  });

  @override
  bool get buildsOwnPage => true;

  @override
  void build(LocationBuilder<LocationId> builder) {
    builder.pathLiteral('c');
    final id = builder.pathParam(const StringRouteParamCodec());
    final bParam = builder.queryParam('b', const StringRouteParamCodec());
    final cParam = builder.queryParam('c', const StringRouteParamCodec());

    builder.buildPage(
      buildPage: (key, child) {
        return PlatformModalPage<dynamic>(key: key, child: child);
      },
      buildWidget: (context, data) {
        return ABCScreen(
          id: data.pathParameter(id),
          b: data.queryParameter(bParam),
          c: data.queryParameter(cParam),
        );
      },
    );
  }
}
