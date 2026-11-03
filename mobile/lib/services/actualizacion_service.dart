import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión publicada en GitHub Releases que puede instalarse sobre la actual.
class InfoActualizacion {
  final String version;
  final int buildNumber;
  final String apkUrl;

  const InfoActualizacion({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
  });
}

/// Actualización desde la app: el APK de GitHub Releases trae su canal
/// (`latest-apk` o `dev-apk`) y compara su build con el `version.json`
/// publicado junto al APK de ese mismo canal.
class ActualizacionService {
  ActualizacionService._();

  static const String _repo = 'https://github.com/Arbolito-ctrl/LuxxitoSports';

  /// Vacío en compilaciones locales (`flutter run`): esas no se actualizan solas.
  static const String canal = String.fromEnvironment('APK_CANAL');

  static bool get disponible => canal.isNotEmpty;

  static Future<String> versionInstalada() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (build ${info.buildNumber})';
  }

  /// Devuelve la versión nueva si hay una mayor que la instalada; null si está al día.
  static Future<InfoActualizacion?> buscar() async {
    if (!disponible) return null;

    final instalado =
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    final res = await http
        .get(Uri.parse('$_repo/releases/download/$canal/version.json'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception(
        'No se pudo consultar la última versión (HTTP ${res.statusCode}).',
      );
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final publicado = (data['build_number'] as num?)?.toInt() ?? 0;
    if (publicado <= instalado) return null;

    return InfoActualizacion(
      version: data['version']?.toString() ?? '1.0.$publicado',
      buildNumber: publicado,
      apkUrl: '$_repo/releases/download/$canal/luxxito-sports.apk',
    );
  }

  /// Descarga el APK dentro de la app y abre el instalador de Android.
  static Stream<OtaEvent> instalar(InfoActualizacion info) {
    return OtaUpdate().execute(
      info.apkUrl,
      destinationFilename: 'luxxito-sports-${info.buildNumber}.apk',
    );
  }
}
