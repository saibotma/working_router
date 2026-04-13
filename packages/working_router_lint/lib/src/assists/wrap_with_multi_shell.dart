import 'wrap_location_tree_entry.dart';
import 'wrap_location_tree_element_edit.dart';

import 'package:analyzer_plugin/utilities/assist/assist.dart';

class WrapWithMultiShell extends WrapLocationTreeEntryProducer {
  static const _kind = AssistKind(
    'working_router.assist.wrapWithMultiShell',
    97,
    'Wrap with MultiShell',
  );

  WrapWithMultiShell({required super.context});

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
          'MultiShell(',
          '$builderIndent' 'build: (builder, shell) {',
          '$bodyIndent' 'final slot = builder.slot();',
          '$bodyIndent' 'builder.content = MultiShellContent.builder(',
          '$entryIndent' '(context, data, slots) {',
          '$entryIndent' '  return slots.child(slot);',
          '$entryIndent' '},',
          '$bodyIndent' ');',
          '$bodyIndent' 'builder.children = [',
          '$entryIndent' 'Scope(',
          '$entryIndent' '  parentRouterKey: slot.routerKey,',
          '$entryIndent' '  build: (builder, scope) {',
          '$entryIndent' '    builder.children = [',
          '$selectedSource,',
          '$entryIndent' '    ];',
          '$entryIndent' '  },',
          '$entryIndent' '),',
          '$bodyIndent];',
          '$builderIndent},',
          '$indent)',
        ].join(eol);
      };
}
