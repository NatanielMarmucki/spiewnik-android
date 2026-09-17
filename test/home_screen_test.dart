import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/main.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';

import 'support/test_store.dart';

void main() {
  late TestStore testStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testStore = TestStore.open();
  });
  tearDown(() => testStore.close());

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FontSizeModel(),
        child: MaterialApp(theme: lightTheme, home: HomeScreen(store: testStore.store)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens user songs from the third tab', (tester) async {
    await pumpHomeScreen(tester);

    await tester.tap(find.text('Moje pieśni'));
    await tester.pumpAndSettle();

    final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(indexedStack.index, 2);
    expect(indexedStack.children[2], isA<MySongsView>());
    expect(find.text('Brak własnych pieśni'), findsOneWidget);
  });

  testWidgets('shows the add button only on the user songs tab and opens the form', (tester) async {
    await pumpHomeScreen(tester);
    expect(find.byTooltip('Dodaj pieśń'), findsNothing);

    await tester.tap(find.text('Ulubione'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dodaj pieśń'), findsNothing);

    await tester.tap(find.text('Moje pieśni'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj pieśń'));
    await tester.pumpAndSettle();

    expect(find.byType(MySongFormView), findsOneWidget);
    expect(find.text('Dodaj pieśń'), findsOneWidget);
  });
}
