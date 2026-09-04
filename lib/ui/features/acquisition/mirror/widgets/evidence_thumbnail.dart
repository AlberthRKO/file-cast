import 'dart:io';

import 'package:flutter/material.dart';

class EvidenceThumbnail extends StatelessWidget {
  const EvidenceThumbnail({
    required this.localPath,
    required this.fallback,
    super.key,
  });
  final String? localPath;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (path == null) return fallback;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
