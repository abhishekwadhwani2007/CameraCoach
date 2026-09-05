import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_coach/main.dart';

void main() {
  testWidgets('PoseCoach smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CameraCoachApp(showOnboarding: false));
    await tester.pumpAndSettle();

    expect(find.text('CameraCoach AI'), findsOneWidget);
    expect(find.text('Upload Reference'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
  });
}
