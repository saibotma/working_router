import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/assists/remove_location_tree_element.dart';
import 'src/assists/wrap_with_scope.dart';
import 'src/assists/wrap_with_shell.dart';

final plugin = _WorkingRouterPlugin();

class _WorkingRouterPlugin extends Plugin {
  @override
  String get name => 'working_router_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerAssist(RemoveLocationTreeElement.new);
    registry.registerAssist(WrapWithScope.new);
    registry.registerAssist(WrapWithShell.new);
  }
}
