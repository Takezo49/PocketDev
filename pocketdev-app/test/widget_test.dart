import 'package:flutter_test/flutter_test.dart';

import 'package:devbox_flutter/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const DevBoxApp());
    expect(find.text('DevBox'), findsOneWidget);
  });
}
