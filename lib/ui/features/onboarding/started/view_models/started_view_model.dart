import 'package:flutter/foundation.dart';

typedef StartedContent = ({
  String appName,
  String title,
  String subtitle,
  String actionLabel,
});

class StartedViewModel extends ChangeNotifier {
  StartedViewModel({required String appName})
    : content = (
        appName: appName,
        title: 'La forma más fácil de registrar evidencias',
        subtitle: 'Registra y monitorea las evidencias que obtienes',
        actionLabel: 'Empezar',
      );

  final StartedContent content;
}
