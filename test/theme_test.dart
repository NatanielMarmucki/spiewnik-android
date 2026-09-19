import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/theme.dart';

/// A theme without shadows: docs/DESIGN-SYSTEM.md has none anywhere, including on the pill button.
void main() {
  for (final (name, theme) in [('light', lightTheme), ('dark', darkTheme)]) {
    group('$name theme: pill button has no shadow', () {
      final style = theme.elevatedButtonTheme.style!;

      for (final states in <Set<WidgetState>>[
        {},
        {WidgetState.pressed},
        {WidgetState.hovered},
        {WidgetState.focused},
        {WidgetState.disabled},
      ]) {
        test('elevation 0 and a transparent shadow in the ${states.isEmpty ? 'resting' : states.first.name} state', () {
          expect(style.elevation!.resolve(states), 0.0);
          expect(style.shadowColor!.resolve(states), Colors.transparent);
        });
      }

      testWidgets('a pressed button does not lift', (tester) async {
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
