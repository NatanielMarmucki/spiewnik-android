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

  testWidgets('dialog ma promień 12 dp i wnętrze 24 dp', (tester) async {
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

  testWidgets('akcje rozchodzą się do krawędzi dialogu', (tester) async {
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

  testWidgets('każda akcja ma własne tło 12%', (tester) async {
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

  testWidgets('akcja niszcząca jest w kolorze niszczącym na tle 12%, nie wypełniona', (tester) async {
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

  testWidgets('Anuluj przestaje być akcentem', (tester) async {
    await openConfirmation(tester);
    final appColors = Theme.of(tester.element(find.byType(AlertDialog))).extension<AppColors>()!;

    expect(styleOf(tester, 'Anuluj')?.foregroundColor?.resolve({}), appColors.textSecondary);
  });

  testWidgets('w ciemnym motywie kolory też idą z tokenów', (tester) async {
    await openConfirmation(tester, theme: darkTheme);
    final appColors = Theme.of(tester.element(find.byType(AlertDialog))).extension<AppColors>()!;

    expect(styleOf(tester, 'Usuń')?.foregroundColor?.resolve({}), appColors.destructive);
    expect(styleOf(tester, 'Anuluj')?.foregroundColor?.resolve({}), appColors.textSecondary);
  });

  testWidgets('zablokowana akcja zostaje czytelna, w kolorze tekstu trzeciego', (tester) async {
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
  });

  testWidgets('przyciski dialogu mają cel co najmniej 48 dp', (tester) async {
    await openConfirmation(tester);

    for (final label in ['Anuluj', 'Usuń']) {
      final button = find.ancestor(of: find.text(label), matching: find.byType(TextButton));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48.0));
    }
  });
}
