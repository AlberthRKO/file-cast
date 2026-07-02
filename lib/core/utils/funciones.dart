import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_cast/presentation/widgets/modals/modal_error.dart';
import 'package:flutter/material.dart';
import 'package:get_ip_address/get_ip_address.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

String formatDateTimeWithUtc() {
  final DateTime nowUtc = DateTime.now().toUtc();
  final String formattedDateTime = nowUtc.toIso8601String();
  return formattedDateTime;
}

String formatDateTimeWithUtcMilliseconds() {
  final DateTime nowUtc = DateTime.now();
  final String isoString = nowUtc.toIso8601String();
  final int dotIndex = isoString.indexOf('.');
  if (dotIndex != -1) {
    return '${isoString.substring(0, dotIndex + 4)}Z';
  } else {
    return '${isoString}Z';
  }
}

String formatDateWithHour(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat('HH:mm', 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithHourSeg(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat('HH:mm:ss', 'es');
  return dateFormat.format(dateTime);
}

double formatTimeToMinutes(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final int hours = dateTime.hour;
  final int minutes = dateTime.minute;
  final double seconds =
      dateTime.second / 60.0; // Convierte segundos a fracción de minuto
  return (hours * 60) + minutes + seconds; // Suma todo como minutos
}

List<int> separarHoraDesdeISO8601UTC(String iso8601String) {
  try {
    final DateTime dateTime = DateTime.parse(
      iso8601String,
    ); // Se omite .toLocal()
    return [dateTime.hour, dateTime.minute];
  } catch (e) {
    print('Error al parsear la fecha ISO 8601: $e');
    return []; // Retorna una lista vacía en caso de error
  }
}

List<int> separarHora(String hora) {
  final List<String> partes = hora.split(':');
  if (partes.length == 2) {
    final int? horas = int.tryParse(partes[0]);
    final int? minutos = int.tryParse(partes[1]);
    if (horas != null && minutos != null) {
      return [horas, minutos];
    }
  }
  return [];
}

String formatDurationFromTime(String dateStr) {
  // Extraer la parte de la hora de la cadena
  final String timeStr = dateStr.split('T')[1].split('.')[0];
  final DateTime dateTime = DateFormat('HH:mm:ss').parse(timeStr);

  // Obtener la hora actual y crear un objeto DateTime con la fecha base
  final DateTime now = DateTime.now();
  final DateTime nowWithTime = DateTime(
    now.year,
    now.month,
    now.day,
    dateTime.hour,
    dateTime.minute,
    dateTime.second,
  );

  // Calcular la duración
  final Duration duration = nowWithTime.difference(dateTime);

  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);

  String formattedDuration = '';

  if (hours > 0) {
    formattedDuration += '$hours hora${hours > 1 ? 's' : ''} ';
  }

  formattedDuration += '$minutes min';

  if (seconds > 0) {
    formattedDuration += ' $seconds seg';
  }

  return formattedDuration.trim();
}

String formatDateWithYear(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy', 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithDayAndTime(String dateStr) {
  if (dateStr.isEmpty) {
    return '';
  }
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss', 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithDayAndTimeLocal(String dateStr) {
  if (dateStr.isEmpty) return '';

  try {
    final dateTime = DateTime.parse(dateStr).toLocal();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
    return dateFormat.format(dateTime);
  } catch (e) {
    return '';
  }
}

String formatDateWithFullTextLocal(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr).toLocal();
  final DateFormat dateFormat = DateFormat(
    "EEEE d 'de' MMMM, yyyy, HH:mm",
    'es',
  );
  return dateFormat.format(dateTime);
}

String formatDateWithDaySinHoraAndTimeLocal(String dateStr) {
  if (dateStr.isEmpty) return '';

  try {
    final dateTime = DateTime.parse(dateStr).toLocal();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es');
    return dateFormat.format(dateTime);
  } catch (e) {
    return '';
  }
}

String formatDateWithHourAndTimeLocal(String dateStr) {
  if (dateStr.isEmpty) return '';

  try {
    final dateTime = DateTime.parse(dateStr).toLocal();
    final dateFormat = DateFormat('HH:mm', 'es');
    return dateFormat.format(dateTime);
  } catch (e) {
    return '';
  }
}

String formatDateWithDayAndTimeLocalNoti(String dateStr) {
  if (dateStr.isEmpty) {
    return '';
  }
  final DateTime dateTime = DateTime.parse(dateStr).toLocal();
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy\nHH:mm', 'es');
  return dateFormat.format(dateTime);
}

String formatDateDayLocal(String dateStr) {
  if (dateStr.isEmpty) return '';

  try {
    final dateTime = DateTime.parse(dateStr).toLocal();
    final dateFormat = DateFormat('dd', 'es');
    return dateFormat.format(dateTime);
  } catch (e) {
    return '';
  }
}

String formatDateMonthLocal(String dateStr) {
  if (dateStr.isEmpty) return '';

  try {
    final dateTime = DateTime.parse(dateStr).toLocal();
    final dateFormat = DateFormat('MMMM', 'es');
    return dateFormat.format(dateTime);
  } catch (e) {
    return '';
  }
}

String formatDatePlus30Minutes(String dateStr) {
  if (dateStr.isEmpty) return '';

  try {
    final originalDate = DateTime.parse(dateStr).toLocal();
    final newDate = originalDate.add(const Duration(minutes: 30));
    final dateFormat = DateFormat('hh:mm', 'es');
    return dateFormat.format(newDate);
  } catch (e) {
    return '';
  }
}

String formatDateWithDayHour(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat('d MMM yyyy, HH:mm:ss', 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithDayHourPlusDias(String dateStr, int daysToAdd) {
  final DateTime dateTime = DateTime.parse(
    dateStr,
  ).add(Duration(days: daysToAdd));
  final DateFormat dateFormat = DateFormat('d MMM yyyy, HH:mm:ss', 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithFullText(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat("EEEE d 'de' MMMM, yyyy", 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithMesFullText(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat("EEEE d 'de' MMMM", 'es');
  return dateFormat.format(dateTime);
}

String formatDateWithoutDay(String dateStr) {
  final DateTime dateTime = DateTime.parse(dateStr);
  final DateFormat dateFormat = DateFormat('d MMMM yyyy', 'es');
  return dateFormat.format(dateTime);
}

Future<void> loadUrl(String url) async {
  final Uri uri = Uri.parse(url);
  final bool launched = await launchUrl(
    uri,
    mode: Platform.isIOS
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  );

  if (!launched) {
    throw Exception('No se pudo abrir la URL $url');
  }
}

Future<void> loadUrlExterno(String url) async {
  final Uri uri = Uri.parse(url);
  final bool launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched) {
    throw Exception('No se pudo abrir la URL $url');
  }
}

Future<void> openDeepLink(String deepLink) async {
  final Uri uri = Uri.parse(deepLink);

  if (await canLaunchUrl(uri)) {
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ); // Abre en el navegador o app predeterminada
  } else {
    throw 'No se pudo abrir la URL $deepLink';
  }
}

Future<String> convertImageToBase64(String imagePath) async {
  final File imageFile = File(imagePath);
  final Uint8List imageBytes = await imageFile.readAsBytes();
  return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
}

Future<void> showModalError(BuildContext context, String message) async {
  await showMaterialModalBottomSheet(
    isDismissible: false,
    enableDrag: false,
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
      return ModalError(
        error: message,
      );
    },
  );
}

Future<void> clearImageCache() async {
  final directory = await getApplicationDocumentsDirectory();
  const cacheKeyPrefix = 'ms_avatar_'; // Prefijo de la clave de caché

  try {
    final files = directory.listSync();
    for (final file in files) {
      if (file is File && file.path.contains(cacheKeyPrefix)) {
        await file.delete();
        print('Cache de imagen eliminada: ${file.path}');
      }
    }
    print('Cache de imágenes de avatar limpiada.');
  } catch (e) {
    print('Error al limpiar la caché de imágenes: $e');
  }
}

String convertToAgeticUrlNoti({
  required String urlRedirectClient,
  required String msFileId,
  required String binnacleId,
  required String msAgeticToken,
  required String generatedUuid,
  required String casoId,
}) {
  final encodedUrl = Uri.encodeComponent(urlRedirectClient);
  final encodedDocumentId = Uri.encodeComponent(msFileId);
  final encodedBinnacleId = Uri.encodeComponent(binnacleId);
  final encodedToken = Uri.encodeComponent(msAgeticToken);
  final encodedProcessKey = Uri.encodeComponent(generatedUuid);

  return 'https://agetic.mp.gob.bo/aprobacion?'
      'urlRedirectClient=$encodedUrl&'
      'documentId=$encodedDocumentId&'
      'binnacleId=$encodedBinnacleId&'
      'token=$encodedToken&'
      'processKey=Noti$encodedProcessKey-$casoId&'
      'redirectFullPath=true';
}

String urlLogout({
  required String urlRedirectClient,
  required String binnacleId,
}) {
  final encodedUrl = Uri.encodeComponent(urlRedirectClient);
  final encodedBinacleId = Uri.encodeComponent(binnacleId);

  return 'https://agetic.mp.gob.bo/logout?'
      'urlRedirectLogout=$encodedUrl&'
      'binnacleId=$encodedBinacleId';
}

String? getNumberAfterPlus(String text) {
  // Encuentra la posición del signo '+'
  final int plusIndex = text.indexOf('+');

  if (plusIndex == -1 || plusIndex == text.length - 1) {
    return null;
  }

  // Extrae la subcadena que comienza justo después del '+'
  final String numberString = text.substring(plusIndex + 1);

  return numberString;
}

int? getLastNumberAfterDash(String text) {
  // Encuentra la última ocurrencia del guion.
  final lastDashIndex = text.lastIndexOf('-');

  // Si no hay guion o si el guion es el último carácter,
  // no hay número después, así que devolvemos null.
  if (lastDashIndex == -1 || lastDashIndex == text.length - 1) {
    return null;
  }

  // Extrae la subcadena después del último guion.
  final numberString = text.substring(lastDashIndex + 1);

  try {
    // Intenta parsear la subcadena a un entero.
    return int.parse(numberString);
  } catch (e) {
    // Si la subcadena no es un número válido, devolvemos null
    // y puedes imprimir un mensaje de error si lo deseas.
    print("Error al parsear el número: $e para el string '$numberString'");
    return null;
  }
}

bool diferenciaMayor60Minutos(String fecha1, String fecha2) {
  // Parsear las fechas a objetos DateTime
  final DateTime dateTime1 = DateTime.parse(fecha1);
  final DateTime dateTime2 = DateTime.parse(fecha2);

  // Calcular la diferencia en minutos
  final diferencia = dateTime1.difference(dateTime2).inMinutes.abs();

  // Devolver true si la diferencia es mayor a 30 minutos
  return diferencia > 60;
}

Future<String> getDeviceInfoAgent() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    //log('Running on Android: $androidInfo');

    // Construir el User-Agent para Android (ejemplo: Xiaomi)
    final String androidVersion =
        androidInfo.version.release; // Android OS (ej: "13")
    final String deviceModel =
        androidInfo.model; // Modelo (ej: "Redmi Note 12")
    const String webkitVersion = '537.36'; // Versión común de WebKit

    final String userAgent =
        'Mozilla/5.0 (Linux; Android $androidVersion; $deviceModel) '
        'AppleWebKit/$webkitVersion (KHTML, like Gecko) ';
    return userAgent;
    //log('User-Agent generado: $userAgent');
  } else if (Platform.isIOS) {
    final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    //log('Running on iOS: $iosInfo');

    // Construir el User-Agent para iOS (opcional)
    final String userAgent =
        "Mozilla/5.0 (${iosInfo.modelName}; CPU ${iosInfo.model} OS ${iosInfo.systemVersion.replaceAll(".", "_")} like Mac OS X)";

    return userAgent;
  } else {
    //log('Unsupported platform');
    return 'Mozilla/5.0 (Unknown)';
  }
}

Future<String> getIpAddress() async {
  try {
    final ipAddress = IpAddress(type: RequestType.json);
    final response = await ipAddress.getIpAddress();

    // Extrae solo la IP del JSON (ej: si response es {"ip": "200.87.154.97"})
    final ip = (response is Map) ? response['ip']?.toString() ?? '' : '';
    print('IP obtenida: $ip');
    return ip;
  } catch (e) {
    print('Error al obtener la IP: $e');
    return ''; // Devuelve string vacío en caso de error
  }
}

// Método auxiliar para parsear el String horaSalida a DateTime
DateTime? parseHoraString(String horaString, DateTime referenceDate) {
  try {
    // Caso 1: Formato ISO 8601 completo (con fecha)
    if (horaString.contains('T')) {
      final fechaCompleta = DateTime.parse(horaString);
      return DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
        fechaCompleta.hour,
        fechaCompleta.minute,
      );
    }
    // Caso 2: Formato simple HH:mm
    else if (horaString.contains(':')) {
      final parts = horaString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
          hour,
          minute,
        );
      }
    }

    // Si no coincide con ningún formato conocido
    return null;
  } catch (e) {
    print('Error al parsear horaString "$horaString": $e');
    return null;
  }
}

String getTruncatedFileName(String fileName, {int maxLength = 20}) {
  if (fileName.length <= maxLength) {
    return fileName; // Si el nombre del archivo es menor o igual al máximo, no truncamos
  }

  // Mostramos los primeros 8 caracteres y los últimos 10 del nombre del archivo
  const int keepStart = 10;
  const int keepEnd = 20;

  final String start = fileName.substring(0, keepStart);
  final String end = fileName.substring(fileName.length - keepEnd);

  return '$start...$end';
}
