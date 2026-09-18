import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/theme.dart';

/// Motyw bez cieni: docs/DESIGN-SYSTEM.md nie przewiduje ich nigdzie, także na przycisku-pastylce.
void main() {
  for (final (name, theme) in [('jasny', lightTheme), ('ciemny', darkTheme)]) {
    group('motyw $name: przycisk-pastylka bez cienia', () {
      final style = theme.elevatedButtonTheme.style!;

      for (final states in <Set<WidgetState>>[
        {},
        {WidgetState.pressed},
        {WidgetState.hovered},
        {WidgetState.focused},
        {WidgetState.disabled},
      ]) {
        test('elevation 0 i przezroczysty cień w stanie ${states.isEmpty ? 'spoczynku' : states.first.name}', () {
          expect(style.elevation!.resolve(states), 0.0);
          expect(style.shadowColor!.resolve(states), Colors.transparent);
        });
      }

      testWidgets('wciśnięty przycisk nie unosi się', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(child: ElevatedButton(onPressed: () {}, child: const Text('Wyczyść wyszukiwanie'))),
            ),
          ),
        );
        Material material() =>
            tester.widget<Material>(find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)));

        expect(material().elevation, 0.0);
        final gesture = await tester.startGesture(tester.getCenter(find.byType(ElevatedButton)));
        await tester.pumpAndSettle();
        expect(material().elevation, 0.0);
        expect(material().shadowColor, Colors.transparent);
        await gesture.up();
      });
    });
  }
}
