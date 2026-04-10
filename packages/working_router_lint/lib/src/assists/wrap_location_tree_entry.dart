import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'wrap_location_tree_element_edit.dart';

abstract class WrapLocationTreeEntryProducer extends ResolvedCorrectionProducer {
  WrapLocationTreeEntryProducer({required super.context});

  WrapTemplate get template;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final edit = WrapLocationTreeElementEdit.create(
      unit: unit,
      source: unitResult.content,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
      eol: defaultEol,
      template: template,
    );
    if (edit == null) {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(edit.range, edit.replacement);
    });
  }
}
