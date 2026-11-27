import 'package:smart_auth/smart_auth.dart';

class AuthSmsCodeService {
  Future<String?> listen() async {
    try {
      final result = await SmartAuth.instance.getSmsWithRetrieverApi().timeout(
        const Duration(seconds: 30),
      );
      return result.hasData ? result.requireData.code : null;
    } on Object {
      return null;
    }
  }

  Future<void> stop() async {
    try {
      await SmartAuth.instance.removeSmsRetrieverApiListener();
    } on Object {
      // El retriever puede no estar disponible en esta plataforma.
    }
  }
}
