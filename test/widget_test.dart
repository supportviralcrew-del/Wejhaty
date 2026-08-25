import 'package:flutter_test/flutter_test.dart';
import 'package:tripproject/main.dart';

void main() {
  testWidgets('Splash screen displays app title', (WidgetTester tester) async {
    await tester.pumpWidget(const RoadTripApp());

    expect(find.text('RoadTrip Jordan'), findsOneWidget);
    expect(find.text('Your smart companion for the road.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
