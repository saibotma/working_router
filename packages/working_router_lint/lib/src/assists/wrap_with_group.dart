import 'wrap_location_tree_entry.dart';
import 'wrap_location_tree_element_edit.dart';

import 'package:analyzer_plugin/utilities/assist/assist.dart';

class WrapWithGroup extends WrapLocationTreeEntryProducer {
  static const _kind = AssistKind(
    'working_router.assist.wrapWithGroup',
    100,
    'Wrap with Group',
  );

  WrapWithGroup({required super.context});

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
          'Group(',
          '${builderIndent}build: (builder, group) {',
          '${bodyIndent}builder.children = [',
          '$selectedSource,',
          '$bodyIndent];',
          '$builderIndent},',
          '$indent)',
        ].join(eol);
      };
}
