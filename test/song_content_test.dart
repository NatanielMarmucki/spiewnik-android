import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/song_text_scale.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/widgets/song_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song =
      '1. Alleluja, chwalcie Pana, Nućcie Jemu chwałę, cześć!\n\n'
      'Refren: Wysławiajcie imię Pańskie, [:Niech są pełne Jego chwały,:] w dzień i w noc!\n\n'
      '2. Chwalcie wszystkie Go narody, Złóżcie przed Nim chwałę swą!';

  Future<FontSizeModel> pumpContent(
    WidgetTester tester, {
    String content = song,
    Map<String, Object> settings = const {'fontSize': 19.0, 'lineHeight': 1.62},
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(settings));
    final model = FontSizeModel();
    await model.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<FontSizeModel>.value(
        value: model,
        child: MaterialApp(
          theme: lightTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: Scaffold(body: SongContent(content: content)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  TextSpan spanOf(WidgetTester tester, String contains) {
    final text = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (widget) => (widget.textSpan?.toPlainText() ?? widget.data ?? '').contains(contains),
    );
    return text.textSpan! as TextSpan;
  }

  List<InlineSpan> flatten(InlineSpan span) {
    final spans = <InlineSpan>[];
    span.visitChildren((child) {
      spans.add(child);
      return true;
    });
    return spans;
  }

  testWidgets('zdejmuje znaczniki z toku tekstu', (tester) async {
    await pumpContent(tester);

    expect(find.textContaining('1. Alleluja'), findsNothing);
    expect(find.textContaining('Refren:'), findsNothing);
    expect(find.textContaining('Alleluja, chwalcie Pana'), findsOneWidget);
  });

  testWidgets('pierwsza zwrotka otwiera się inicjałem zamiast numeru', (tester) async {
    await pumpContent(tester);

    final spans = flatten(spanOf(tester, 'lleluja, chwalcie Pana')).cast<TextSpan>();
    expect(spans.first.text, 'A');
    expect(spans.first.style?.fontSize, closeTo(2.16 * 19.0, 0.001));
    expect(spans[1].style?.fontSize ?? 19.0, 19.0);
    expect(find.text('1'), findsNothing, reason: 'numer pierwszej zwrotki zastępuje inicjał');
  });

  testWidgets('kolejna zwrotka ma cyfrę w rozmiarze 0,74 × S', (tester) async {
    await pumpContent(tester);

    final number = tester.widget<Text>(find.text('2'));
    expect(number.style?.fontSize, closeTo(0.74 * 19.0, 0.001));
    expect(number.style?.fontFeatures?.map((f) => f.feature), contains('tnum'));
  });

  testWidgets('refren ma wersalik bez kursywy i wcięcie treści', (tester) async {
    await pumpContent(tester);

    final label = tester.widget<Text>(find.text('REFREN'));
    expect(label.style?.fontStyle ?? FontStyle.normal, FontStyle.normal);
    expect(label.style?.letterSpacing, closeTo(8.5 * 0.26, 0.001));

    final refrainText = find.textContaining('Wysławiajcie imię Pańskie');
    final padding = tester.widget<Padding>(
      find.ancestor(of: refrainText, matching: find.byType(Padding)).first,
    );
    expect((padding.padding as EdgeInsets).left, closeTo(0.74 * 19.0, 0.001));
  });

  testWidgets('znaki powtórzenia są w akcencie i przyklejone do frazy', (tester) async {
    await pumpContent(tester);

    final spans = flatten(spanOf(tester, 'Niech są pełne')).cast<TextSpan>();
    final opening = spans.firstWhere((span) => span.text == '[:');
    final closing = spans.firstWhere((span) => span.text == ':]');
    expect(opening.style?.color, AppColors.light.accent);
    expect(closing.style?.color, AppColors.light.accent);

    final joined = spans.map((span) => span.text ?? '').join();
    expect(joined, contains('[:Niech są pełne'), reason: 'bez odstępu po znaku');
    expect(joined, contains('chwały,:]'), reason: 'bez odstępu przed znakiem');
  });

  testWidgets('rozmiar i interlinia idą z ustawień użytkownika', (tester) async {
    await pumpContent(tester, settings: const {'fontSize': 26.0, 'lineHeight': 1.75});

    final body = tester.widget<Text>(find.textContaining('Chwalcie wszystkie Go narody'));
    expect(body.style?.fontSize, 26.0);
    expect(body.style?.height, 1.75);
  });

  testWidgets('systemowe powiększenie czcionki działa obok S, nie zamiast', (tester) async {
    await pumpContent(tester, textScaler: const TextScaler.linear(2.0));

    final body = tester.widget<Text>(find.textContaining('Chwalcie wszystkie Go narody'));
    // W stylu zostaje S, mnożnik dokłada warstwa tekstu.
    expect(body.style?.fontSize, 19.0);
    final scaler = MediaQuery.textScalerOf(tester.element(find.byType(SongContent)));
    expect(scaler.scale(19.0), 38.0);
  });

  testWidgets('kolumna ma margines 22 dp i limit szerokości 34 × S', (tester) async {
    await pumpContent(tester);

    final box = tester.widget<ConstrainedBox>(
      find.ancestor(of: find.byType(SingleChildScrollView), matching: find.byType(ConstrainedBox)).first,
    );
    expect(box.constraints.maxWidth, closeTo(34.0 * 19.0, 0.001));

    final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect((scroll.padding as EdgeInsets).left, SongTextScale.sideMargin);
  });

  testWidgets('bloki rozdziela odstęp, nie puste wiersze', (tester) async {
    await pumpContent(tester);

    final gaps = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.height != null && box.height! > 20.0)
        .map((box) => box.height!);
    expect(gaps, contains(closeTo(1.26 * 19.0, 0.001)));
    expect(find.text(''), findsNothing);
  });

  testWidgets('pieśń bez refrenu renderuje się bez wersalika', (tester) async {
    await pumpContent(tester, content: '1. Pierwsza zwrotka\n\n2. Druga zwrotka');

    expect(find.text('REFREN'), findsNothing);
    expect(find.textContaining('Pierwsza zwrotka'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
