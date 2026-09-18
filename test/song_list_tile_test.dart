import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, SongListTile tile, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? lightTheme,
        home: Scaffold(body: Column(children: [tile])),
      ),
    );
  }

  Text titleText(WidgetTester tester) => tester.widget<Text>(find.byType(Text).first);

  TextStyle styleOf(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style ?? const TextStyle();
  }

  testWidgets('pokazuje tytuł i numer', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Alleluja, chwalcie Pana', number: 1));

    expect(find.text('Alleluja, chwalcie Pana'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('wysokość jest minimalna, nie stała: rośnie z tekstem', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Krótki', number: 1));
    final small = tester.getSize(find.byType(SongListTile)).height;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(body: Column(children: const [SongListTile(title: 'Krótki', number: 1)])),
        ),
      ),
    );
    final scaled = tester.getSize(find.byType(SongListTile)).height;

    expect(small, SongListTile.minHeight);
    expect(scaled, greaterThan(small));
  });

  testWidgets('serce ulubionej stoi przy tytule, nie na końcu wiersza', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Bądź Panu cześć', number: 3, isFavorite: true));

    final heart = tester.getRect(find.byIcon(Icons.favorite));
    final title = tester.getRect(find.text('Bądź Panu cześć'));
    final number = tester.getRect(find.text('3'));

    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).size, 11.0);
    expect(heart.left - title.right, lessThan(16.0), reason: 'serce tuż za tytułem');
    expect(heart.right, lessThan(number.left), reason: 'serce przed numerem');
  });

  testWidgets('bez ulubionej nie ma serca', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Boże wielki', number: 4));

    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('własna pieśń ma wersalik MOJA zamiast numeru', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Wieczorna modlitwa', badge: 'MOJA'));

    expect(find.text('MOJA'), findsOneWidget);
    expect(styleOf(tester, 'MOJA').letterSpacing, closeTo(8.5 * 0.26, 0.001));
  });

  testWidgets('numer jest tabelaryczny i w kolorze tekstu drugiego', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Pieśń', number: 12));

    final style = styleOf(tester, '12');
    expect(style.fontFeatures?.map((f) => f.feature), contains('tnum'));
    expect(style.color, AppColors.light.textSecondary);
  });

  testWidgets('wybrany wiersz ma numer w kolorze akcentu', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Pieśń', number: 12, isSelected: true));

    expect(styleOf(tester, '12').color, AppColors.light.accent);
  });

  testWidgets('tytuł używa kroju szeryfowego w rozmiarze 17', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Pieśń', number: 1));

    final style = titleText(tester).style;
    expect(style?.fontFamily, 'Newsreader');
    expect(style?.fontSize, 17.0);
  });

  testWidgets('długi tytuł skraca się wielokropkiem i nie wypycha numeru', (tester) async {
    const long = 'Bardzo długi tytuł pieśni, który nie mieści się w jednej linii na ekranie telefonu';
    await pumpTile(tester, const SongListTile(title: long, number: 2000));

    expect(titleText(tester).overflow, TextOverflow.ellipsis);
    expect(titleText(tester).maxLines, 1);
    expect(find.text('2000'), findsOneWidget);
    final numberRect = tester.getRect(find.text('2000'));
    expect(numberRect.right, lessThanOrEqualTo(tester.getSize(find.byType(SongListTile)).width));
  });

  testWidgets('cały wiersz jest celem dotknięcia', (tester) async {
    var taps = 0;
    await pumpTile(tester, SongListTile(title: 'Pieśń', number: 1, onTap: () => taps++));

    final rect = tester.getRect(find.byType(SongListTile));
    await tester.tapAt(Offset(rect.right - 4, rect.center.dy)); // pusty obszar przy numerze
    await tester.tapAt(Offset(rect.left + 4, rect.center.dy)); // pusty obszar przy krawędzi

    expect(taps, 2);
  });

  testWidgets('wciśnięcie przyciemnia tło i wraca po puszczeniu', (tester) async {
    await pumpTile(tester, SongListTile(title: 'Pieśń', number: 1, onTap: () {}));

    Color? background() {
      final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      return (container.decoration as BoxDecoration?)?.color;
    }
    expect(background(), lightTheme.colorScheme.surface);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(SongListTile)));
    await tester.pump();
    expect(background(), AppColors.light.pressedSurface);

    await gesture.up();
    await tester.pump(SongListTile.pressDuration);
    expect(background(), lightTheme.colorScheme.surface);
  });

  testWidgets('trafienie wyszukiwania jest podświetlone w tytule', (tester) async {
    await pumpTile(tester, const SongListTile(title: 'Chwalże ma duszo', number: 8, highlight: 'chwal'));

    final rich = tester.widget<Text>(find.byType(Text).first);
    final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((s) => s.text).join(), 'Chwalże ma duszo');
    final highlighted = spans.firstWhere((s) => s.style?.color == AppColors.light.accent);
    expect(highlighted.text, 'Chwal');
  });

  testWidgets('w ciemnym motywie kolory idą z motywu', (tester) async {
    await pumpTile(
      tester,
      const SongListTile(title: 'Pieśń', number: 1, isFavorite: true),
      theme: darkTheme,
    );

    expect(styleOf(tester, '1').color, AppColors.dark.textSecondary);
    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color, AppColors.dark.favorite);
  });
}
