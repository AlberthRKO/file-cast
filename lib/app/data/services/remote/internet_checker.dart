import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

class InternetChecker {
  Future<bool> hasInternet() async {
    try {
      // Comprobar internet en web
      // esto se ejecutara si la app esta corriendo en web
      if (kIsWeb) {
        final response = await get(
          // hacemos la peticion al dns respectivo del dominio
          // Uri.parse('https://google.com'),
          Uri.parse('8.8.8.8'),
        );
        return response.statusCode == 200;
      } else {
        // dart:io compatibles con moviles
        final list = await InternetAddress.lookup('google.com');
        // comprobamos si la solicitud retorno info
        return list.isNotEmpty && list.first.rawAddress.isNotEmpty;
        // return false;
      }
    } catch (e) {
      return false;
    }
  }
}
