import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/main.dart'; // Importuj główny plik aplikacji
import 'package:spiewnik/objectbox.g.dart'; // Użyj ścieżki pakietowej

void main() {
  testWidgets('MyApp has a title and message', (WidgetTester tester) async {
    final store = await openStore();

    await tester.pumpWidget(MyApp(store: store));

    expect(find.text('Śpiewnik'), findsOneWidget);

    store.close();
  });
}