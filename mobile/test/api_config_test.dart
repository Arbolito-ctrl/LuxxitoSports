import 'package:flutter_test/flutter_test.dart';
import 'package:luxxito_sports_mobile/services/api_service.dart';

void main() {
  test('la app usa una API pública por defecto, no una IP de la PC', () {
    final uri = Uri.parse(ApiService.baseUrl);
    expect(uri.scheme, 'https');
    expect(uri.path, '/api');
    expect(uri.host, isNot(anyOf('localhost', '10.0.2.2', '192.168.1.14')));
  });

  test('si la API no responde, la app muestra un error de red y no cambia de destino', () async {
    final original = ApiService.baseUrl;
    // Puerto cerrado en la propia máquina: la conexión falla al instante
    ApiService.setBaseUrl('http://127.0.0.1:1/api');
    try {
      await expectLater(
        ApiService.getComplejos(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NETWORK_ERROR')
              .having((e) => e.statusCode, 'statusCode', 0),
        ),
      );
      expect(ApiService.baseUrl, 'http://127.0.0.1:1/api');
    } finally {
      ApiService.setBaseUrl(original);
    }
  });
}
