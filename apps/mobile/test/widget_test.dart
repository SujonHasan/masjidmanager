import 'package:flutter_test/flutter_test.dart';

import 'package:masjid_manager_mobile/app/app.dart';

void main() {
  testWidgets('Masjid Manager app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MasjidManagerApp());
    expect(find.text('Masjid Manager'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });
}
