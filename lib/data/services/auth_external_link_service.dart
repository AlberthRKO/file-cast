import 'package:url_launcher/url_launcher.dart';

class AuthExternalLinkService {
  Future<bool> openTelegram(String? address) async {
    final uri =
        Uri.tryParse(address ?? '') ??
        Uri.parse('https://t.me/fiscalia_bo_bot');
    final target = uri.hasScheme
        ? uri
        : Uri.parse('https://t.me/fiscalia_bo_bot');
    if (target.scheme != 'https' ||
        !const {'t.me', 'telegram.me'}.contains(target.host.toLowerCase())) {
      return false;
    }
    return launchUrl(target, mode: LaunchMode.externalApplication);
  }
}
