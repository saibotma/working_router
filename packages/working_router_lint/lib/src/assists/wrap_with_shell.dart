import 'wrap_location_tree_entry.dart';
import 'wrap_location_tree_element_edit.dart';

import 'package:analyzer_plugin/utilities/assist/assist.dart';

class WrapWithShell extends WrapLocationTreeEntryProducer {
  static const _kind = AssistKind(
    'working_router.assist.wrapWithShell',
    99,
    'Wrap with Shell',
  );

  WrapWithShell({required super.context});

  static WrapTemplate get templateForTest => _template;

  @override
  AssistKind get assistKind => _kind;

  @override
  WrapTemplate get template => _template;

  static WrapTemplate get _template =>
      ({
        required String selectedSource,
        required String indent,
        required String builderIndent,
        required String bodyIndent,
        required String entryIndent,
        required String eol,
      }) {
        return [
          'Shell(',
          '$builderIndent' 'build: (builder, shell, routerKey) {',
          '$bodyIndent'
              'builder.widgetBuilder((context, data, child) => child);',
          '$bodyIndent' 'builder.children = [',
          '$selectedSource,',
          '$bodyIndent];',
          '$builderIndent},',
          '$indent)',
        ].join(eol);
      };
}
