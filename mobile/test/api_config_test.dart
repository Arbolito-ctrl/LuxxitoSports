import 'package:flutter_test/flutter_test.dart';
import 'package:luxxito_sports_mobile/services/api_service.dart';

void main() {
  test('la app usa una API pública por defecto, no una IP de la PC', () {
    final uri = Uri.parse(ApiService.baseUrl);
    expect(uri.scheme, 'https');
    expect(uri.path, '/api');
    expect(uri.host, isNot(anyOf('localhost', '10.0.2.2', '192.168.1.14')));
  });

  test('un fallo de API no puede activar Supabase directo en el APK del taller', () {
    final original = ApiService.baseUrl;
    expect(ApiService.enableSupabaseCloudMode, throwsA(isA<ApiException>()));
    expect(ApiService.baseUrl, original);
  });
}
