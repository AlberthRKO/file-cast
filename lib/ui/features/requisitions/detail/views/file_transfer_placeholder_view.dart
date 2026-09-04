import 'package:flutter/material.dart';

class FileTransferPlaceholderView extends StatelessWidget {
  const FileTransferPlaceholderView({required this.requisitionId, super.key});
  final String requisitionId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transferencia de archivos')),
    body: const Center(
      child: Text(
        'Transferencia de archivos\nPróximamente',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
