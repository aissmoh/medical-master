import 'package:flutter_test/flutter_test.dart';

import 'package:mon_app/app.dart';

void main() {
  testWidgets('App starts on intro screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MediPulse'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });
}
