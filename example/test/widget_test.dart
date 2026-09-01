import 'package:flutter_test/flutter_test.dart';
import 'package:blur_check_example/main.dart';

void main() {
  testWidgets('demo page loads', (tester) async {
    await tester.pumpWidget(const BlurDetectorExampleApp());
    await tester.pump(); // start async analyze
    expect(find.text('blur_check'), findsOneWidget);
    expect(find.text('Offline sharpness check'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
