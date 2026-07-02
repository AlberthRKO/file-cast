import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:file_cast/presentation/widgets/card_info.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ModalErrorQR extends StatelessWidget {
  const ModalErrorQR({
    required this.title,
    required this.subtitle,
    super.key,
    this.sancion = '',
    this.titleButton = 'Confirmar',
    this.icon = 'paper.svg',
    this.funcion,
    this.colorText = textSucces,
  });
  final String title;
  final String subtitle;
  final String sancion;
  final String titleButton;
  final String icon;
  final void Function()? funcion;
  final Color colorText;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    return Form(
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(appPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: CardSinResultados(
                      boxShadow: false,
                      title: title,
                      subtitle: subtitle,
                      img: darkMode
                          ? '${assetImgIllustration}qrScanDark.svg'
                          : '${assetImgIllustration}qrScan.svg',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
