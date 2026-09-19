import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/confirmation_dialog.dart';
import 'package:spiewnik/view/widgets/dialog_actions.dart';

void main() {
  Future<void> openConfirmation(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConfirmationDialog(
              context,
              title: 'Usunąć pieśń?',
              message: 'Pieśń „Testowa” zostanie trwale usunięta.',
              confirmLabel: 'Usuń',
            ),
            child: const Text('otwórz'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('otwórz'));
    await tester.pumpAndSettle();
  }

  ButtonStyle? styleOf(WidgetTester tester, String label) {
    return tester
        .widget<TextButton>(find.ancestor(of: find.text(label), matching: find.byType(TextButton)))
        .style;
  }

  testWidgets('dialog has a 12 dp radius and 24 dp padding', (tester) async {
    await openConfirmation(tester);

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final shape = Theme.of(tester.element(find.byType(AlertDialog))).dialogTheme.shape;
    expect(
      shape,
      const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
    );
    expect(dialog.titlePadding, kDialogTitlePadding);
    expect(dialog.contentPadding, kDialogContentPadding);
  });

  testWidgets('actions spread out to the dialog edges', (tester) async {
    await openConfirmation(tester);

    final row = tester.widget<Row>(
      find.descendant(of: find.byType(DialogActions), matching: find.byType(Row)).first,
    );
    expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween);

    // Pasek akcji zajmuje całą szerokość wnętrza dialogu, więc wystarczy porównać się z nim.
    final actions = tester.getRect(find.byType(DialogActions));
    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Anuluj'));
    final confirm = tester.getRect(find.widgetWithText(TextButton, 'Usuń'));

    expect(cancel.left, closeTo(actions.left, 0.5), reason: 'wycofanie przy lewej krawędzi');
    expect(confirm.right, closeTo(actions.right, 0.5), reason: 'potwierdzenie przy prawej');
    expect(confirm.left - cancel.right, greaterThan(100.0), reason: 'akcje są rozsunięte');
  });

  testWidgets('each action has its own 12% background', (tester) async {
    await openConfirmation(tester);
    final appColors = Theme.of(tester.element(find.byType(AlertDialog))).extension<AppColors>()!;

    expect(
      styleOf(tester, 'Anuluj')?.backgroundColor?.resolve({}),
      appColors.textSecondary.withValues(alpha: 0.12),
    );
    expect(
      styleOf(tester, 'Usuń')?.backgroundColor?.resolve({}),
      appColors.destructive.withValues(alpha: 0.12),
    );
  });

  testWidgets('destructive action uses the destructive color on a 12% background, not filled', (tester) async {
    await openConfirmation(tester);
    final appColors = Theme.of(tester.element(find.byType(AlertDialog))).extension<AppColors>()!;

    final style = styleOf(tester, 'Usuń');
    expect(style?.foregroundColor?.resolve({}), appColors.destructive);
    expect(style?.backgroundColor?.resolve({}), appColors.destructive.withValues(alpha: 0.12));
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(ElevatedButton)),
      findsNothing,
      reason: 'akcja niszcząca nigdy nie jest wypełnionym przyciskiem',
    );
  });

  testWidgets('„Anuluj” uses the secondary text color instead of the accent', (tester) async {
    await openConfirmation(tester);
    final appColors = Theme.of(tester.element(find.byType(AlertDialog))).extension<AppColors>()!;

    expect(styleOf(tester, 'Anuluj')?.foregroundColor?.resolve({}), appColors.textSecondary);
  });

  testWidgets('dark theme colors also come from tokens', (tester) async {
    await openConfirmation(tester, theme: darkTheme);
    final appColors = Theme.of(tester.element(find.byType(AlertDialog))).extension<AppColors>()!;

    expect(styleOf(tester, 'Usuń')?.foregroundColor?.resolve({}), appColors.destructive);
    expect(styleOf(tester, 'Anuluj')?.foregroundColor?.resolve({}), appColors.textSecondary);
  });

  testWidgets('disabled action stays readable, in the tertiary text color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: DialogActions(
              children: [dialogAccentButton(context, label: 'Przejdź', onPressed: null)],
            ),
          ),
        ),
      ),
    );
    final appColors = Theme.of(tester.element(find.text('Przejdź'))).extension<AppColors>()!;

    final style = styleOf(tester, 'Przejdź');
    expect(style?.foregroundColor?.resolve({WidgetState.disabled}), appColors.textTertiary);
    expect(
      style?.backgroundColor?.resolve({WidgetState.disabled}),
      appColors.line,
      reason: 'kształt przycisku zostaje widoczny, tylko bez poświaty akcentu',
    );
  });

  testWidgets('dialog buttons have a tap target of at least 48 dp', (tester) async {
    await openConfirmation(tester);

    for (final label in ['Anuluj', 'Usuń']) {
      final button = find.ancestor(of: find.text(label), matching: find.byType(TextButton));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48.0));
    }
  });
}
