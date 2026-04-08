import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../location_id.dart';
import '../platform_modal/platform_modal_page.dart';

class ABCLocation extends Location<LocationId> {
  final idParam = pathParam(const StringRouteParamCodec());
  final bParam = queryParam('b', const StringRouteParamCodec());
  final cParam = queryParam('c', const StringRouteParamCodec());

  ABCLocation({
    super.id,
    required super.parentNavigatorKey,
  });

  @override
  List<PathSegment> get path => [
        literal('c'),
        idParam,
      ];

  @override
  List<QueryParam<dynamic>> get queryParameters => [bParam, cParam];

  @override
  bool get buildsOwnPage => true;

  @override
  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return PlatformModalPage<dynamic>(key: key, child: child);
  }

  @override
  Widget buildWidget(BuildContext context, WorkingRouterData<LocationId> data) {
    final id = data.pathParameter(idParam);
    final b = data.queryParameter(bParam);
    final c = data.queryParameter(cParam);

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
