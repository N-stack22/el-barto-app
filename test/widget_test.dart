import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Carga una pantalla básica de El Barto', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('El Barto'),
          ),
        ),
      ),
    );

    expect(find.text('El Barto'), findsOneWidget);
  });
}
