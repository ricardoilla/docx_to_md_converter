import 'package:docflip/app.dart';
import 'package:docflip/models/convert_mode.dart';
import 'package:docflip/state/converter_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('layout shows labels, drop zone and disabled convert', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(DocFlipApp(state: ConverterState()));
    expect(find.text('DOCX'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.text('Drop a .docx here or click to open'), findsOneWidget);
    expect(find.byKey(const Key('copy-button')), findsOneWidget);
    final convert = tester.widget<FilledButton>(
      find.byKey(const Key('convert-button')),
    );
    expect(convert.onPressed, isNull);
  });

  testWidgets('swap flips labels, rotates the arrow and hides Copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = ConverterState();
    await tester.pumpWidget(DocFlipApp(state: state));
    await tester.tap(find.byKey(const Key('swap-button')));
    await tester.pumpAndSettle();

    expect(state.mode, ConvertMode.md2docx);
    expect(
      tester
          .widget<AnimatedRotation>(find.byKey(const Key('swap-rotation')))
          .turns,
      0.5,
    );
    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    expect(find.byKey(const Key('copy-button')), findsNothing);
    expect(find.text('Download .docx'), findsOneWidget);
  });
}
