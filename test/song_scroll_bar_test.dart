import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/widgets/song_scroll_bar.dart';

/// Krok „szybkie przewijanie": uchwyt przy prawej krawędzi i etykieta z numerem pieśni.
void main() {
  late ScrollController controller;

  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  /// Lista 2000 wierszy o **różnej** wysokości — co dziesiąty jest wyższy, tak jak wiersz
  /// z zawiniętym tytułem. Gdyby kod liczył pozycję ze stałej wysokości, tu by się wywrócił.
  Future<void> pumpList(
    WidgetTester tester, {
    bool enabled = true,
    double textScale = 1.0,
    int itemCount = 2000,
  }) async {
    tester.view.physicalSize = const Size(411 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SongScrollBar(
              controller: controller,
              enabled: enabled,
              labelForIndex: (index) => index < itemCount ? '${index + 1}' : null,
              child: ListView.builder(
                controller: controller,
                itemCount: itemCount,
                itemBuilder: (context, index) => SizedBox(
                  height: index % 10 == 0 ? 96.0 : 48.0,
                  child: Text('wiersz $index'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Przeciąga uchwyt do podanego ułamka toru.
  Future<void> dragThumbTo(WidgetTester tester, double fraction) async {
    final bar = tester.getRect(find.byType(SongScrollBar));
    final start = Offset(bar.right - SongScrollBar.hitWidth / 2, bar.top + SongScrollBar.thumbHeight / 2);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(Offset(start.dx, bar.top + bar.height * fraction));
    await tester.pumpAndSettle();
    // Gest zostaje wciśnięty: etykieta pokazuje się tylko w trakcie przeciągania.
  }

  testWidgets('przeciągnięcie uchwytu przewija listę', (tester) async {
    await pumpList(tester);
    expect(controller.offset, 0.0);

    await dragThumbTo(tester, 0.5);

    expect(controller.offset, greaterThan(0.0));
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent * 0.5, controller.position.maxScrollExtent * 0.1),
      reason: 'w połowie toru jesteśmy mniej więcej w połowie listy',
    );
  });

  testWidgets('etykieta pokazuje numer pieśni, która naprawdę jest na górze', (tester) async {
    await pumpList(tester);

    await dragThumbTo(tester, 0.5);

    // Numer bierzemy z modelu przez labelForIndex, a indeks z listy — nie z dzielenia offsetu.
    final label = find.descendant(of: find.byType(SongScrollBar), matching: find.byType(Text));
    final numbers = tester
        .widgetList<Text>(label)
        .map((text) => text.data)
        .where((text) => text != null && !text.startsWith('wiersz'))
        .toList();
    expect(numbers, hasLength(1), reason: 'jedna etykieta w trakcie przeciągania');

    final shown = int.parse(numbers.single!);
    final firstVisible = firstVisibleItemIndex(controller);
    expect(firstVisible, isNotNull);
    expect(shown, firstVisible! + 1, reason: 'etykieta zgadza się z pierwszym widocznym wierszem');
  });

  testWidgets('etykieta znika po puszczeniu uchwytu', (tester) async {
    await pumpList(tester);
    final bar = tester.getRect(find.byType(SongScrollBar));
    final start = Offset(bar.right - SongScrollBar.hitWidth / 2, bar.top + SongScrollBar.thumbHeight / 2);

    final gesture = await tester.startGesture(start);
    await gesture.moveTo(Offset(start.dx, bar.top + bar.height * 0.4));
    await tester.pumpAndSettle();
    final duringDrag = tester.widgetList<Text>(find.byType(Text)).length;

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.widgetList<Text>(find.byType(Text)).length, lessThan(duringDrag));
  });

  testWidgets('uchwyt znika przy aktywnym wyszukiwaniu', (tester) async {
    await pumpList(tester, enabled: false);

    // Zostaje sama lista: przy wynikach wyszukiwania uchwyt nic nie wnosi.
    expect(find.byType(ListView), findsOneWidget);
    final bar = tester.getRect(find.byType(SongScrollBar));
    final hit = Offset(bar.right - SongScrollBar.hitWidth / 2, bar.top + SongScrollBar.thumbHeight / 2);
    final gesture = await tester.startGesture(hit);
    await gesture.moveTo(Offset(hit.dx, bar.top + bar.height * 0.8));
    await tester.pumpAndSettle();

    expect(controller.offset, 0.0, reason: 'nie ma czego przeciągać');
    await gesture.up();
  });

  testWidgets('uchwyt nie pokazuje się przy krótkiej liście', (tester) async {
    await pumpList(tester, itemCount: 5);

    await dragThumbTo(tester, 0.9);

    expect(controller.offset, 0.0);
  });

  group('powiększenie czcionki', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('działa przy ×$scale', (tester) async {
        await pumpList(tester, textScale: scale);

        await dragThumbTo(tester, 0.6);

        expect(controller.offset, greaterThan(0.0));
        expect(firstVisibleItemIndex(controller), isNotNull);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('cel dotknięcia uchwytu ma co najmniej 48 dp', (tester) async {
    await pumpList(tester);

    final hitArea = find.descendant(of: find.byType(SongScrollBar), matching: find.byType(GestureDetector));
    final size = tester.getSize(hitArea.first);

    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('kolory idą z motywu, w obu wariantach', (tester) async {
    for (final theme in [lightTheme, darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SongScrollBar(
              controller: controller,
              labelForIndex: (index) => '$index',
              child: ListView.builder(
                controller: controller,
                itemCount: 500,
                itemBuilder: (context, index) => const SizedBox(height: 48.0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appColors = Theme.of(tester.element(find.byType(SongScrollBar))).extension<AppColors>()!;
      final decoration = tester
          .widgetList<Container>(find.descendant(of: find.byType(SongScrollBar), matching: find.byType(Container)))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decoration.first.color, appColors.indexDots, reason: 'uchwyt w spoczynku');
    }
  });

  group('odczyt pierwszego widocznego wiersza', () {
    testWidgets('bez podpiętej listy zwraca null zamiast rzucać', (tester) async {
      final loose = ScrollController();
      addTearDown(loose.dispose);

      expect(firstVisibleItemIndex(loose), isNull);
    });

    testWidgets('gdy w drzewie nie ma listy, etykieta się nie pokazuje, a ekran żyje', (tester) async {
      // SingleChildScrollView nie ma RenderSliverMultiBoxAdaptor — dokładnie przypadek,
      // w którym odczyt musi odpuścić.
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: SongScrollBar(
              controller: controller,
              labelForIndex: (index) => '$index',
              child: SingleChildScrollView(
                controller: controller,
                child: const SizedBox(height: 5000.0, child: Text('treść')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(firstVisibleItemIndex(controller), isNull);

      final bar = tester.getRect(find.byType(SongScrollBar));
      final hit = Offset(bar.right - SongScrollBar.hitWidth / 2, bar.top + SongScrollBar.thumbHeight / 2);
      final gesture = await tester.startGesture(hit);
      await gesture.moveTo(Offset(hit.dx, bar.top + bar.height * 0.7));
      await tester.pumpAndSettle();

      expect(find.text('treść'), findsOneWidget, reason: 'lista przewija się dalej');
      expect(tester.takeException(), isNull);
      await gesture.up();
    });

    testWidgets('pusta lista nie wywraca odczytu', (tester) async {
      await pumpList(tester, itemCount: 0);

      expect(firstVisibleItemIndex(controller), isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
