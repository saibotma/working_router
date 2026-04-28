import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';

typedef BuildOverlay<Self extends AnyOverlay<Self>> =
    void Function(OverlayBuilder builder, Self node);

abstract interface class BuildsWithOverlayBuilder {
  void build(OverlayBuilder builder);
}

final class OverlayCondition<T> {
  final DefaultQueryParam<T> parameter;
  final T value;

  const OverlayCondition._({
    required this.parameter,
    required this.value,
  });
}

extension OverlayConditionQueryParam<T> on DefaultQueryParam<T> {
  OverlayCondition<T> matches(T value) {
    return OverlayCondition<T>._(parameter: this, value: value);
  }
}

final class OverlayBuildResult {
  final List<OverlayCondition<dynamic>> conditions;
  final LocationWidgetBuilder? buildWidget;
  final SelfBuiltLocationPageBuilder? buildPage;

  const OverlayBuildResult({
    required this.conditions,
    required this.buildWidget,
    required this.buildPage,
  });
}

/// Builder for query-controlled overlays.
///
/// Overlays are not locations and cannot define path, query parameters,
/// children, or nested overlays. They only define render content and are
/// activated by the overlay conditions configured on this builder.
class OverlayBuilder {
  List<OverlayCondition<dynamic>>? _conditions;
  Content? _content;
  SelfBuiltLocationPageBuilder? _buildPage;

  set conditions(List<OverlayCondition<dynamic>> conditions) {
    if (_conditions != null) {
      throw StateError(
        'OverlayBuilder conditions were already configured. '
        'conditions may only be configured once.',
      );
    }
    _conditions = List.unmodifiable(conditions);
  }

  set content(Content content) {
    if (_content != null) {
      throw StateError(
        'OverlayBuilder content was already configured. '
        'content may only be configured once.',
      );
    }
    _content = content;
  }

  set page(SelfBuiltLocationPageBuilder page) {
    if (_buildPage != null) {
      throw StateError(
        'OverlayBuilder page was already configured. '
        'page may only be configured once.',
      );
    }
    _buildPage = page;
  }

  OverlayBuildResult resolve() {
    final conditions = _conditions;
    if (conditions == null) {
      throw StateError(
        'OverlayBuilder conditions were not configured. '
        'Configure conditions before resolving an overlay.',
      );
    }
    final buildWidget = _content?.resolveWidgetBuilderOrNull();
    if (buildWidget == null) {
      if (_buildPage != null) {
        throw StateError(
          'OverlayBuilder page was configured without content. '
          'Configure content before setting page.',
        );
      }
    }
    return OverlayBuildResult(
      conditions: conditions,
      buildWidget: buildWidget,
      buildPage: _buildPage,
    );
  }
}

abstract class AnyOverlay<Self extends AnyOverlay<Self>>
    extends RouteNode<Self> {
  AnyOverlay({
    super.id,
    super.localId,
    super.parentRouterKey,
  });

  OverlayBuilder createBuilder() => OverlayBuilder();

  @override
  LocalKey buildPageKey(WorkingRouterData data) {
    return ValueKey((runtimeType, identityHashCode(this)));
  }

  late final OverlayBuildResult _definition = _buildDefinition();

  List<OverlayCondition<dynamic>> get conditions => _definition.conditions;

  OverlayBuildResult _buildDefinition() {
    final builder = createBuilder();
    if (this case final BuildsWithOverlayBuilder element) {
      element.build(builder);
      return builder.resolve();
    }
    throw StateError(
      'Unsupported overlay/builder combination: '
      '$runtimeType/${builder.runtimeType}.',
    );
  }

  bool get contributesPage => _definition.buildWidget != null;

  Widget buildWidget(BuildContext context, WorkingRouterData data) {
    final buildWidget = _definition.buildWidget;
    if (buildWidget == null) {
      throw StateError('Overlay $runtimeType does not build content.');
    }
    return buildWidget(context, data);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return _definition.buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}

/// Override-based base class for query-controlled overlay content.
///
/// An overlay is matched when all [conditions] match the current route state. It
/// can render into a navigator via [parentRouterKey], but it never becomes part
/// of the primary route stack and can never be the primary leaf.
abstract class AbstractOverlay<Self extends AnyOverlay<Self>>
    extends AnyOverlay<Self>
    implements BuildsWithOverlayBuilder {
  AbstractOverlay({
    super.id,
    super.localId,
    super.parentRouterKey,
  });
}

class Overlay<Self extends AnyOverlay<Self>> extends AbstractOverlay<Self> {
  final BuildOverlay<Self> _build;

  Overlay({
    super.id,
    super.localId,
    super.parentRouterKey,
    required BuildOverlay<Self> build,
  }) : _build = build;

  @override
  void build(OverlayBuilder builder) {
    _build(builder, this as Self);
  }
}
