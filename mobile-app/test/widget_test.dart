import 'package:flutter_test/flutter_test.dart';

import 'package:medtrack/main.dart';
import 'package:medtrack/repository/local_dose_repository.dart';

void main() {
  testWidgets('Home screen shows seeded compartments', (tester) async {
    await tester.pumpWidget(
      MedTrackApp(initialRepository: LocalDoseRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Compartment 1'), findsOneWidget);
    expect(find.text('Compartment 2'), findsOneWidget);
    expect(find.text('Simulate dispense'), findsWidgets);
  });

  testWidgets('Simulate dispense marks a compartment dispensed',
      (tester) async {
    await tester.pumpWidget(
      MedTrackApp(initialRepository: LocalDoseRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simulate dispense').first);
    await tester.pumpAndSettle();

    expect(find.text('Dispensed'), findsOneWidget);
  });
}
