import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'remove_location_tree_element_edit.dart';

class RemoveLocationTreeElement extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'working_router.assist.removeElement',
    101,
    'Remove element',
  );

  RemoveLocationTreeElement({required super.context});

  @override
  AssistKind get assistKind => _kind;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final edit = RemoveLocationTreeElementEdit.create(
      unit: unit,
      source: unitResult.content,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    );
    if (edit == null) {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(edit.range, edit.replacement);
    });
  }
}
