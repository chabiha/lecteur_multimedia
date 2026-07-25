import 'package:flutter_test/flutter_test.dart';
import 'package:lecteur_multimedia/main.dart';

void main() {
  testWidgets("L'application se lance sans planter", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LecteurMultimediaApp());
    expect(find.text('Lecteur Multimédia'), findsOneWidget);
  });
}
