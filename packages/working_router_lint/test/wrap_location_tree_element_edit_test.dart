import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:working_router_lint/src/assists/remove_location_tree_element_edit.dart';
import 'package:working_router_lint/src/assists/wrap_location_tree_element_edit.dart';
import 'package:working_router_lint/src/assists/wrap_with_location.dart';
import 'package:working_router_lint/src/assists/wrap_with_multi_shell.dart';
import 'package:working_router_lint/src/assists/wrap_with_scope.dart';
import 'package:working_router_lint/src/assists/wrap_with_shell.dart';

void main() {
  test('wrap with scope wraps a builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    PrivacyLocation(
      build: (builder, location) {
        builder.content = Content.widget('privacy');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'PrivacyLocation(',
      template: WrapWithScope.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('Scope('));
    expect(changedSource, contains('builder.children = ['));
    expect(changedSource, contains('PrivacyLocation('));
  });

  test('wrap with shell wraps a builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    PrivacyLocation(
      build: (builder, location) {
        builder.content = Content.widget('privacy');
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
    expect(changedSource, contains('PrivacyLocation('));
  });

  test('wrap with location wraps a builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    PrivacyLocation(
      build: (builder, location) {
        builder.content = Content.widget('privacy');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'PrivacyLocation(',
      template: WrapWithLocation.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('Location('));
    expect(changedSource, contains('builder.content = const Content.none();'));
    expect(changedSource, contains('PrivacyLocation('));
  });

  test('wrap with multi shell wraps a builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    PrivacyLocation(
      build: (builder, location) {
        builder.content = Content.widget('privacy');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'PrivacyLocation(',
      template: WrapWithMultiShell.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('MultiShell('));
    expect(changedSource, contains('final slot = builder.slot();'));
    expect(changedSource, contains('return slots.child(slot);'));
    expect(changedSource, contains('Scope('));
    expect(changedSource, contains('parentRouterKey: slot.routerKey,'));
    expect(changedSource, contains('PrivacyLocation('));
  });

  test('wrap with shell wraps an entry in a returned tree list', () {
    const source = '''
List<Object> buildLocations() {
  return [
    SplashLocation(
      build: (builder, location) {
        builder.content = Content.widget('splash');
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

  test('wrap with location wraps an entry in a returned tree list', () {
    const source = '''
List<Object> buildLocations() {
  return [
    SplashLocation(
      build: (builder, location) {
        builder.content = Content.widget('splash');
      },
    ),
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'SplashLocation(',
      template: WrapWithLocation.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('return ['));
    expect(changedSource, contains('Location('));
    expect(changedSource, contains('builder.content = const Content.none();'));
    expect(changedSource, contains('SplashLocation('));
  });

  test('wrap with scope wraps an entry inside an if spread branch', () {
    const source = '''
List<Object> buildLocations(bool enabled) {
  return [
    if (enabled) ...[
      Shell(
        build: (builder, shell, routerKey) {
          builder.children = [
            PrivacyLocation(
              build: (builder, location) {
                builder.content = Content.widget('privacy');
              },
            ),
          ];
        },
      ),
    ],
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'Shell(',
      template: WrapWithScope.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('if (enabled) ...['));
    expect(changedSource, contains('Scope('));
    expect(changedSource, contains('Shell('));
  });

  test('wrap with scope wraps a shell inside a builder.children if spread branch', () {
    const source = '''
void build(builder, permissions) {
  builder.children = [
    if (permissions.maySeeAttendances) ...[
      Shell(
        build: (builder, shell, routerKey) {
          builder.children = [
            PrivacyLocation(
              build: (builder, location) {
                builder.content = Content.widget('privacy');
              },
            ),
          ];
        },
      ),
    ],
  ];
}
''';
    final edit = _createEdit(
      source: source,
      snippet: 'Shell(',
      template: WrapWithScope.templateForTest,
    );

    expect(edit, isNotNull);
    final changedSource = _applyEdit(source, edit!);
    expect(changedSource, contains('if (permissions.maySeeAttendances) ...['));
    expect(changedSource, contains('Scope('));
    expect(changedSource, contains('Shell('));
  });

  test(
    'wrap with scope finds a shell inside a builder.children if spread branch from line indentation',
    () {
      const source = '''
void build(builder, permissions) {
  builder.children = [
    if (permissions.maySeeAttendances) ...[
      Shell(
        build: (builder, shell, routerKey) {
          builder.children = [
            PrivacyLocation(
              build: (builder, location) {
                builder.content = Content.widget('privacy');
              },
            ),
          ];
        },
      ),
    ],
  ];
}
''';
      final edit = _createCollapsedEditAtLineIndent(
        source: source,
        lineSnippet: '      Shell(',
        template: WrapWithScope.templateForTest,
      );

      expect(edit, isNotNull);
      final changedSource = _applyEdit(source, edit!);
      expect(changedSource, contains('if (permissions.maySeeAttendances) ...['));
      expect(changedSource, contains('Scope('));
      expect(changedSource, contains('Shell('));
    },
  );

  test('wrap with shell formats nested children indentation correctly', () {
    const source = '''
void build(builder) {
  builder.children = [
    ALocation(
      id: LocationId.a,
      build: (builder, location) {
        builder.content = Content.widget('a');
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
      build: (builder, shell, routerKey) {
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
      build: (builder, shell, routerKey) {
        builder.children = [
          PrivacyLocation(
            build: (builder, location) {
              builder.content = Content.widget('privacy');
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
      snippet: "builder.content = Content.widget('privacy')",
      template: WrapWithScope.templateForTest,
    );

    expect(edit, isNull);
  });

  test('remove element unwraps a middle builder.children entry', () {
    const source = '''
void build(builder) {
  builder.children = [
    ALocation(),
    Scope(
      build: (builder, scope) {
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
    final edit = _createRemoveEdit(source: source, snippet: 'Scope(');

    expect(edit, isNotNull);
    final changedSource = _applyRemoveEdit(source, edit!);
    expect(changedSource, isNot(contains('Scope(')));
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
    Scope(
      build: (builder, scope) {
        builder.children = [
          BLocation(),
          CLocation(),
        ];
      },
    ),
  ];
}
''';
    final edit = _createRemoveEdit(source: source, snippet: 'Scope(');

    expect(edit, isNotNull);
    final changedSource = _applyRemoveEdit(source, edit!);
    expect(changedSource, isNot(contains('Scope(')));
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
        builder.content = Content.widget('splash');
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
        builder.content = Content.widget('splash');
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

WrapLocationTreeElementEdit? _createCollapsedEditAtLineIndent({
  required String source,
  required String lineSnippet,
  required WrapTemplate template,
}) {
  final parsed = parseString(content: source);
  final offset = source.indexOf(lineSnippet);
  if (offset == -1) {
    throw StateError('Snippet `$lineSnippet` not found in test source.');
  }

  return WrapLocationTreeElementEdit.create(
    unit: parsed.unit,
    source: source,
    selectionOffset: offset,
    selectionLength: 0,
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
