import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App smoke test — LoginScreen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const RideUzApp());
    expect(find.text('RideUz'), findsAny);
  });
}
