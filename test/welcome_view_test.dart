import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/post_migration_welcome.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/welcome_view.dart';

import 'support/screen_harness.dart';

/// Welcome screen after migration: approved copy, a single exit, accessibility and both themes.
void main() {
  Finder continueButton() => find.bySemanticsLabel(WelcomeView.continueSemanticsLabel);

  /// Text on screen as approved, ignoring the no-break spaces that only change line breaking.
  Finder approvedText(String text) => find.byWidgetPredicate(
    (widget) => widget is Text && widget.data?.replaceAll('\u00A0', ' ') == text,
  );

  group('text and way out', () {
    testWidgets('shows the approved text', (tester) async {
      await pumpScreen(tester, (context) => WelcomeView(onContinue: () {}));

      expect(approvedText('Śpiewnik w nowej odsłonie'), findsOneWidget);
      expect(
        approvedText('Twoje ulubione i własne pieśni są na miejscu — przeniosły się razem z aplikacją.'),
        findsOneWidget,
      );
      expect(approvedText('Co się zmieniło:'), findsOneWidget);
      for (final change in [
        'Nowy wygląd, czytelniejszy przy słabym świetle',
        'Tekst pieśni z wyraźnym podziałem na zwrotki i refren',
        'Wyszukiwanie działa też bez polskich znaków',
        'Ustawienia rozmiaru tekstu i interlinii w jednym miejscu',
      ]) {
        expect(approvedText(change), findsOneWidget);
      }
      expect(find.text('Zaczynajmy'), findsOneWidget);
    });

    testWidgets('„tylko ustawienia” variant: different first paragraph, rest of the screen unchanged', (tester) async {
      await pumpScreen(
        tester,
        (context) => WelcomeView(variant: WelcomeVariant.settingsOnly, onContinue: () {}),
      );

      expect(approvedText('Twoje ustawienia przeniosły się razem z aplikacją.'), findsOneWidget);
      expect(find.textContaining('ulubione'), findsNothing, reason: 'nie obiecujemy ulubionych, których nie było');
      expect(approvedText('Śpiewnik w nowej odsłonie'), findsOneWidget);
      expect(approvedText('Co się zmieniło:'), findsOneWidget);
      for (final change in WelcomeView.changes) {
        expect(approvedText(change), findsOneWidget);
      }
      expect(find.text('Zaczynajmy'), findsOneWidget);
    });

    testWidgets('the default variant mentions favorites and user songs', (tester) async {
      await pumpScreen(tester, (context) => WelcomeView(variant: WelcomeVariant.songs, onContinue: () {}));

      expect(
        approvedText('Twoje ulubione i własne pieśni są na miejscu — przeniosły się razem z aplikacją.'),
        findsOneWidget,
      );
      expect(approvedText('Twoje ustawienia przeniosły się razem z aplikacją.'), findsNothing);
    });

    testWidgets('single-letter words are not left at the end of a line', (tester) async {
      await pumpScreen(tester, (context) => WelcomeView(onContinue: () {}));

      expect(find.text('Tekst pieśni z\u00A0wyraźnym podziałem na zwrotki i\u00A0refren'), findsOneWidget);
      expect(find.text('Ustawienia rozmiaru tekstu i\u00A0interlinii w\u00A0jednym miejscu'), findsOneWidget);
      expect(WelcomeView.typeset('i w dom'), 'i\u00A0w\u00A0dom', reason: 'kolejne jednoliterowe słowa też');
      expect(WelcomeView.typeset('Twoje ulubione'), 'Twoje ulubione', reason: 'zwykłe spacje zostają');
    });

    testWidgets('has a single exit, without „Wesprzyj” or „Zgłoś błąd”', (tester) async {
      await pumpScreen(tester, (context) => WelcomeView(onContinue: () {}));

      expect(find.bySubtype<ButtonStyleButton>(), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(InkWell), findsOneWidget, reason: 'jedyny cel dotknięcia to przycisk');
      expect(find.byType(AppBar), findsNothing, reason: 'bez paska nie ma też strzałki wstecz');
      expect(find.textContaining('Wesprzyj'), findsNothing);
      expect(find.textContaining('Zgłoś'), findsNothing);
    });

    testWidgets('„Zaczynajmy” triggers the exit', (tester) async {
      var continued = 0;
      await pumpScreen(tester, (context) => WelcomeView(onContinue: () => continued++));

      await tester.tap(find.text('Zaczynajmy'));
      expect(continued, 1);
    });
  });

  group('WelcomeGate', () {
    Widget home(BuildContext context) => const Scaffold(body: Text('lista pieśni'));

    testWidgets('shows the welcome screen first, then the song list for good after „Zaczynajmy”', (tester) async {
      await pumpScreen(tester, (context) => WelcomeGate(welcome: WelcomeVariant.songs, buildHome: home));

      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.text('lista pieśni'), findsNothing);

      await tester.tap(find.text('Zaczynajmy'));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeView), findsNothing);
      expect(find.text('lista pieśni'), findsOneWidget);
    });

    testWidgets('passes the variant to the welcome screen', (tester) async {
      await pumpScreen(tester, (context) => WelcomeGate(welcome: WelcomeVariant.settingsOnly, buildHome: home));

      expect(approvedText(WelcomeView.settingsOnlyLead), findsOneWidget);
    });

    testWidgets('without a welcome screen shows the song list right away', (tester) async {
      await pumpScreen(tester, (context) => WelcomeGate(welcome: null, buildHome: home));

      expect(find.byType(WelcomeView), findsNothing);
      expect(find.text('lista pieśni'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('the button has a Polish label and the title is a semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, (context) => WelcomeView(onContinue: () {}));

      expect(continueButton(), findsOneWidget);
      expect(
        tester.getSemantics(approvedText(WelcomeView.title)),
        matchesSemantics(label: WelcomeView.typeset(WelcomeView.title), isHeader: true),
      );
      expect(find.bySemanticsLabel('Nowy wygląd, czytelniejszy przy słabym świetle'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the button is at least 48 dp tall', (tester) async {
      await pumpScreen(tester, (context) => WelcomeView(onContinue: () {}));

      expect(tester.getSize(find.byType(ElevatedButton)).height, greaterThanOrEqualTo(48.0));
    });

    for (final (name, theme) in [('light', lightTheme), ('dark', darkTheme)]) {
      for (final size in [const Size(411, 915), const Size(320, 568)]) {
        testWidgets('$name theme, ${size.width.toInt()} dp screen, text scale ×2.0: nothing overflows '
            'and „Zaczynajmy” is reachable', (tester) async {
          final handle = tester.ensureSemantics();
          var continued = 0;
          await pumpScreen(
            tester,
            (context) => WelcomeView(onContinue: () => continued++),
            theme: theme,
            textScale: 2.0,
            size: size,
          );
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.text('Zaczynajmy'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Zaczynajmy'));
          expect(continued, 1);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  });
}
