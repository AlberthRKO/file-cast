import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

PreferredSize getAppbar(Color fondo) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(0),
    child: AppBar(
      elevation: 0,
      backgroundColor: fondo,
    ),
  );
}

PreferredSize getAppbar2(Color fondo) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(0),
    child: AppBar(
      elevation: 0,
      backgroundColor: fondo,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
  );
}
