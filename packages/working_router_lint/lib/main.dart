import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/assists/wrap_with_group.dart';
import 'src/assists/wrap_with_shell.dart';

final plugin = _WorkingRouterPlugin();

class _WorkingRouterPlugin extends Plugin {
  @override
  String get name => 'working_router_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerAssist(WrapWithGroup.new);
    registry.registerAssist(WrapWithShell.new);
  }
}
