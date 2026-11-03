import 'package:flutter_test/flutter_test.dart';
import 'package:luxxito_sports_mobile/main.dart';

void main() {
  testWidgets('Renderiza pantalla inicial de Login de Luxxito Sports',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuxxitoSportsApp());
    expect(find.text('Bienvenido a Luxxito Sports'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
