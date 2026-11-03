import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luxxito_sports_mobile/main.dart';

void main() {
  testWidgets('Renderiza pantalla inicial de Login de Luxxito Sports',
      (WidgetTester tester) async {
    // Celular sin sesión guardada: la app termina en la pantalla de login
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const LuxxitoSportsApp());
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a Luxxito Sports'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
