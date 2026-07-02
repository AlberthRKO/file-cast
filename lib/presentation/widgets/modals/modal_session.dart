import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ModalSession extends StatelessWidget {
  const ModalSession({
    required this.title,
    required this.titleButton,
    required this.name,
    super.key,
    this.funcion,
    this.fetching = false,
    this.centro = false,
  });
  final String title;
  final String titleButton;
  final String name;
  final void Function()? funcion;
  final bool fetching;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    final responsive = Responsive.of(context);
    // var size = MediaQuery.of(context).size;
    return Container(
      padding: const EdgeInsets.all(appPadding),
      height: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Column(
        children: [
          Text(
            '¿$title $name?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: centro ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontSize: 14,
              color: deleteColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(
            height: smallSpacer,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CustomButtonBoxStyle(
                title: 'Cancelar',
                funcion: () {
                  context.pop(false);
                },
                color: darkMode
                    ? Theme.of(context).scaffoldBackgroundColor
                    : const Color(0xffD8DDE2),
                titleColor: Theme.of(context).hintColor,
                iconColor: Theme.of(context).hintColor,
                iconActive: true,
                icon: 'close.svg',
                sizeHeight: responsive.widthPercent(10),
                sizeWidth: responsive.widthPercent(35),
                fontSize: responsive.heightPercent(1.4),
              ),
              CustomButtonBoxStyle(
                title: titleButton,
                funcion: funcion,
                color: deleteColor,
                iconActive: true,
                icon: 'logout.svg',
                sizeHeight: responsive.widthPercent(10),
                sizeWidth: responsive.widthPercent(35),
                fontSize: responsive.heightPercent(1.4),
                isLoading: fetching,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ModalSession2 extends StatelessWidget {
  const ModalSession2({
    required this.title,
    required this.titleButton,
    required this.name,
    super.key,
    this.funcion,
    this.fetching = false,
    this.centro = false,
    this.subtitle = '',
    this.isSubtilte = false,
  });
  final String title;
  final String titleButton;
  final String name;
  final void Function()? funcion;
  final bool fetching;
  final bool centro;
  final String subtitle;
  final bool isSubtilte;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    final responsive = Responsive.of(context);
    // var size = MediaQuery.of(context).size;
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
            Text(
              '¿$title $name?',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: centro ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: responsive.heightPercent(1.5),
                color: deleteColor,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            if (isSubtilte)
              const SizedBox(
                height: 10,
              ),
            if (isSubtilte)
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: centro ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: responsive.heightPercent(1.5),
                  color: deleteColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            const SizedBox(
              height: smallSpacer,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CustomButtonBoxStyle(
                  title: 'Cancelar',
                  funcion: () {
                    context.pop(false);
                  },
                  color: darkMode
                      ? Theme.of(context).scaffoldBackgroundColor
                      : const Color(0xffD8DDE2),
                  titleColor: Theme.of(context).hintColor,
                  iconColor: Theme.of(context).hintColor,
                  iconActive: true,
                  icon: 'close.svg',
                  sizeHeight: responsive.widthPercent(10),
                  sizeWidth: responsive.widthPercent(35),
                  fontSize: responsive.heightPercent(1.4),
                ),
                CustomButtonBoxStyle(
                  title: titleButton,
                  funcion: funcion,
                  color: deleteColor,
                  iconActive: true,
                  icon: 'logout.svg',
                  sizeHeight: responsive.widthPercent(10),
                  sizeWidth: responsive.widthPercent(35),
                  fontSize: responsive.heightPercent(1.4),
                  isLoading: fetching,
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
