import 'package:flutter_test/flutter_test.dart';
import 'package:luxxito_sports_mobile/main.dart';

void main() {
  testWidgets('Renderiza barra de navegación de Luxxito Sports',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuxxitoSportsApp());
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Mis reservas'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
