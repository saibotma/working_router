import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:working_router_lint/src/assists/remove_location_tree_element_edit.dart';
import 'package:working_router_lint/src/assists/wrap_location_tree_element_edit.dart';
import 'package:working_router_lint/src/assists/wrap_with_group.dart';
import 'package:working_router_lint/src/assists/wrap_with_shell.dart';

void main() {
  test('wrap with group wraps a builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    PrivacyLocation(
      build: (builder, location) {
        builder.widget('privacy');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'PrivacyLocation(',
      template: WrapWithGroup.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('Group('));
    expect(changedSource, contains('builder.children = ['));
    expect(changedSource, contains('PrivacyLocation('));
  });

  test('wrap with shell wraps a builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    PrivacyLocation(
      build: (builder, location) {
        builder.widget('privacy');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'PrivacyLocation(',
      template: WrapWithShell.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('Shell('));
    expect(
      changedSource,
      contains('builder.widgetBuilder((context, data, child) => child);'),
    );
    expect(changedSource, contains('PrivacyLocation('));
  });

  test('wrap with shell wraps an entry in a returned tree list', () {
    const source = '''
List<Object> buildLocations() {
  return [
    SplashLocation(
      build: (builder, location) {
        builder.widget('splash');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'SplashLocation(',
      template: WrapWithShell.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('return ['));
    expect(changedSource, contains('Shell('));
    expect(changedSource, contains('SplashLocation('));
  });

  test('wrap with shell formats nested children indentation correctly', () {
    const source = '''
void build(builder) {
  builder.children = [
    ALocation(
      id: LocationId.a,
      build: (builder, location) {
        builder.widget('a');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'ALocation(',
      template: WrapWithShell.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(
      changedSource,
      contains('''
  builder.children = [
    Shell(
      build: (builder, routerKey) {
        builder.widgetBuilder((context, data, child) => child);
        builder.children = [
          ALocation(
'''),
    );
  });

  test('does not wrap when cursor is inside a shell widget builder body', () {
    const source = '''
List<Object> buildLocations() {
  return [
    Shell(
      build: (builder, routerKey) {
        builder.widgetBuilder((context, data, child) => child);
        builder.children = [
          PrivacyLocation(
            build: (builder, location) {
              builder.widget('privacy');
            },
          ),
        ];
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'child) => child',
      template: WrapWithGroup.templateForTest,
    );

    expect(edit, isNull);
  });

  test('remove element unwraps a middle builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    ALocation(),
    Group(
      build: (builder) {
        builder.children = [
          BLocation(),
          CLocation(),
        ];
      },
    ),
    DLocation(),
  ];
}
''';
    final edit = _createRemoveEdit(source: source, snippet: 'Group(');

    expect(edit, isNotNull);
    final changedSource = _applyRemoveEdit(source, edit!);
    expect(changedSource, isNot(contains('Group(')));
    expect(
      changedSource,
      contains('''
  builder.children = [
    ALocation(),
    BLocation(),
    CLocation(),
    DLocation(),
  ];
'''),
    );
  });

  test('remove element unwraps the last builder.children entry cleanly', () {
    const source = '''
void build(builder) {
  builder.children = [
    ALocation(),
    Group(
      build: (builder) {
        builder.children = [
          BLocation(),
          CLocation(),
        ];
      },
    ),
  ];
}
''';
    final edit = _createRemoveEdit(source: source, snippet: 'Group(');

    expect(edit, isNotNull);
    final changedSource = _applyRemoveEdit(source, edit!);
    expect(changedSource, isNot(contains('Group(')));
    expect(
      changedSource,
      contains('''
  builder.children = [
    ALocation(),
    BLocation(),
    CLocation(),
  ];
'''),
    );
  });

  test('remove element deletes a leaf entry when there are no children to unwrap', () {
    const source = '''
void build(builder) {
  builder.children = [
    ALocation(),
    BLocation(),
  ];
}
''';
    final edit = _createRemoveEdit(source: source, snippet: 'BLocation(');

    expect(edit, isNotNull);
    final changedSource = _applyRemoveEdit(source, edit!);
    expect(changedSource, isNot(contains('BLocation(')));
    expect(changedSource, contains('builder.children = [\n    ALocation(),\n  ];'));
  });

  test('remove element unwraps a returned root entry with one direct children assignment', () {
    const source = '''
List<Object> buildLocations() {
  return [
    SplashLocation(
      build: (builder, location) {
        builder.widget('splash');
        builder.children = [
          ALocation(),
        ];
      },
    ),
  ];
}
''';
    final edit = _createRemoveEdit(source: source, snippet: 'SplashLocation(');

    expect(edit, isNotNull);
    final changedSource = _applyRemoveEdit(source, edit!);
    expect(changedSource, isNot(contains('SplashLocation(')));
    expect(
      changedSource,
      contains('''
  return [
    ALocation(),
  ];
'''),
    );
  });

  test('remove element is unavailable for returned root entry with conditional children', () {
    const source = '''
List<Object> buildLocations(bool showA) {
  return [
    SplashLocation(
      build: (builder, location) {
        builder.widget('splash');
        if (showA) {
          builder.children = [
            ALocation(),
          ];
          return;
        }
        builder.children = [
          BLocation(),
        ];
      },
    ),
  ];
}
''';
    final edit = _createRemoveEdit(source: source, snippet: 'SplashLocation(');

    expect(edit, isNull);
  });
}

WrapLocationTreeElementEdit? _createEdit({
  required String source,
  required String snippet,
  required WrapTemplate template,
}) {
  final parsed = parseString(content: source);
  final offset = source.indexOf(snippet);
  if (offset == -1) {
    throw StateError('Snippet `$snippet` not found in test source.');
  }

  return WrapLocationTreeElementEdit.create(
    unit: parsed.unit,
    source: source,
    selectionOffset: offset,
    selectionLength: snippet.length,
    eol: '\n',
    template: template,
  );
}

String _applyEdit(String source, WrapLocationTreeElementEdit edit) {
  return source.replaceRange(
    edit.range.offset,
    edit.range.end,
    edit.replacement,
  );
}

RemoveLocationTreeElementEdit? _createRemoveEdit({
  required String source,
  required String snippet,
}) {
  final parsed = parseString(content: source);
  final offset = source.indexOf(snippet);
  if (offset == -1) {
    throw StateError('Snippet `$snippet` not found in test source.');
  }

  return RemoveLocationTreeElementEdit.create(
    unit: parsed.unit,
    source: source,
    selectionOffset: offset,
    selectionLength: snippet.length,
  );
}

String _applyRemoveEdit(String source, RemoveLocationTreeElementEdit edit) {
  return source.replaceRange(edit.range.offset, edit.range.end, edit.replacement);
}
