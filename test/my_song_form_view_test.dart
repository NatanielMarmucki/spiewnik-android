import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';

void main() {
  late FakeMySongRepository repository;
  late DateTime now;
  late MySongViewModel viewModel;

  setUp(() {
    repository = FakeMySongRepository();
    now = DateTime(2026, 9, 17, 12);
    viewModel = MySongViewModel(repository, now: () => now);
  });

  final titleField = find.widgetWithText(TextFormField, 'Tytuł');
  final contentField = find.widgetWithText(TextFormField, 'Treść');
  final discardDialogTitle = find.text('Odrzucić zmiany?');

  /// Opens the form on top of a home route, so closing the form is observable.
  Future<void> openForm(WidgetTester tester, {MySong? song}) async {
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MySongFormView(viewModel: viewModel, song: song)),
            ),
            child: const Text('otwórz formularz'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('otwórz formularz'));
    await tester.pumpAndSettle();
  }

  bool formIsOpen() => find.byType(MySongFormView).evaluate().isNotEmpty;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Zapisz'));
    await tester.pumpAndSettle();
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('adding', () {
    testWidgets('saves a new user song with trimmed title and content and closes the form', (tester) async {
      await openForm(tester);
      expect(find.text('Dodaj pieśń'), findsOneWidget);

      await tester.enterText(titleField, '  Moja pieśń  ');
      await tester.enterText(contentField, '\n1. Pierwsza zwrotka\n\n2. Druga zwrotka\n');
      await tester.pump();
      await tapSave(tester);

      final saved = repository.songs.single;
      expect(saved.title, 'Moja pieśń');
      expect(saved.content, '1. Pierwsza zwrotka\n\n2. Druga zwrotka');
      expect(saved.createdAt.isAtSameMomentAs(now), isTrue);
      expect(formIsOpen(), isFalse);
      expect(discardDialogTitle, findsNothing);
    });

    testWidgets('requires a title and content and saves nothing when they are empty', (tester) async {
      await openForm(tester);

      await tapSave(tester);

      expect(find.text('Podaj tytuł pieśni'), findsOneWidget);
      expect(find.text('Podaj treść pieśni'), findsOneWidget);
      expect(repository.songs.isEmpty, isTrue);
      expect(formIsOpen(), isTrue);
    });

    testWidgets('treats whitespace-only fields as empty', (tester) async {
      await openForm(tester);

      await tester.enterText(titleField, '   ');
      await tester.enterText(contentField, ' \n\n ');
      await tester.pump();
      await tapSave(tester);

      expect(find.text('Podaj tytuł pieśni'), findsOneWidget);
      expect(find.text('Podaj treść pieśni'), findsOneWidget);
      expect(repository.songs.isEmpty, isTrue);
    });

    testWidgets('clears a validation message once the field is filled', (tester) async {
      await openForm(tester);
      await tapSave(tester);

      await tester.enterText(titleField, 'Tytuł jest');
      await tester.pump();

      expect(find.text('Podaj tytuł pieśni'), findsNothing);
      expect(find.text('Podaj treść pieśni'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('shows the song, saves changes and updates updatedAt', (tester) async {
      final song = viewModel.addSong(title: 'Stary tytuł', content: 'Stara treść');
      now = DateTime(2026, 9, 18, 9);
      await openForm(tester, song: song);
      expect(find.text('Edytuj pieśń'), findsOneWidget);
      expect(find.text('Stary tytuł'), findsOneWidget);
      expect(find.text('Stara treść'), findsOneWidget);

      await tester.enterText(contentField, 'Nowa treść');
      await tester.pump();
      await tapSave(tester);

      final stored = repository.byId(song.id)!;
      expect(stored.title, 'Stary tytuł');
      expect(stored.content, 'Nowa treść');
      expect(stored.updatedAt.isAtSameMomentAs(now), isTrue);
      expect(repository.songs.length, 1);
      expect(formIsOpen(), isFalse);
    });

    testWidgets('closes without asking when the song was not changed', (tester) async {
      final song = viewModel.addSong(title: 'Tytuł', content: 'Treść');
      await openForm(tester, song: song);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(discardDialogTitle, findsNothing);
      expect(formIsOpen(), isFalse);
    });

    testWidgets('asks before discarding changes to an existing song', (tester) async {
      final song = viewModel.addSong(title: 'Tytuł', content: 'Treść');
      await openForm(tester, song: song);
      await tester.enterText(titleField, 'Zmieniony tytuł');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odrzuć'));
      await tester.pumpAndSettle();

      expect(formIsOpen(), isFalse);
      expect(repository.byId(song.id)!.title, 'Tytuł');
    });
  });

  group('leaving the form', () {
    testWidgets('closes an empty form immediately with the back button', (tester) async {
      await openForm(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(discardDialogTitle, findsNothing);
      expect(formIsOpen(), isFalse);
    });

    testWidgets('closes an empty form immediately with the system back gesture', (tester) async {
      await openForm(tester);

      await systemBack(tester);

      expect(discardDialogTitle, findsNothing);
      expect(formIsOpen(), isFalse);
    });

    testWidgets('closes immediately when typed text was removed again', (tester) async {
      await openForm(tester);
      await tester.enterText(titleField, 'Chwilowy tekst');
      await tester.pump();
      // No frame after removing the text: leaving is still blocked, the form must re-check the fields.
      await tester.enterText(titleField, '');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(discardDialogTitle, findsNothing);
      expect(formIsOpen(), isFalse);
    });

    testWidgets('keeps the form and its text when discarding is cancelled', (tester) async {
      await openForm(tester);
      await tester.enterText(contentField, 'Niezapisana treść');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(discardDialogTitle, findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(formIsOpen(), isTrue);
      expect(find.text('Niezapisana treść'), findsOneWidget);
    });

    testWidgets('asks on the system back gesture and closes after discarding', (tester) async {
      await openForm(tester);
      await tester.enterText(titleField, 'Niezapisany tytuł');
      await tester.pump();

      await systemBack(tester);
      expect(discardDialogTitle, findsOneWidget);
      await tester.tap(find.text('Odrzuć'));
      await tester.pumpAndSettle();

      expect(formIsOpen(), isFalse);
      expect(repository.songs.isEmpty, isTrue);
    });
  });
}
