import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:money_master/shared/widgets/app_dialogs.dart';
import 'package:money_master/shared/widgets/app_form_page.dart';

void main() {
  testWidgets('destructive confirmation has consistent accessible actions', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showAppDestructiveConfirmation(
                    context: context,
                    title: 'Delete Item?',
                    message: 'This action cannot be undone.',
                    confirmLabel: 'Delete Item',
                  );
                },
                child: const Text('Open confirmation'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
    final confirm = find.widgetWithText(FilledButton, 'Delete Item');
    expect(find.text('Delete Item?'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));

    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Item'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form action bar communicates saving and disables commands', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              AppFormActionBar(
                accent: AppTheme.blue,
                saveLabel: 'Save Changes',
                isSaving: true,
                onCancel: () {},
                onSave: () => saves++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Saving...'),
    );
    expect(cancel.onPressed, isNull);
    expect(save.onPressed, isNull);
    expect(find.bySemanticsLabel(RegExp('Saving')), findsWidgets);
    expect(saves, 0);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
