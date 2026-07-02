import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ModalOption extends StatefulWidget {
  const ModalOption({
    required this.title,
    required this.subtitle,
    super.key,
    this.sancion = '',
    this.titleButton = 'Confirmar',
    this.icon = 'paper.svg',
    this.funcion,
    this.funcionCancelar,
    this.isLoading = false,
    this.child,
  });
  final String title;
  final String subtitle;
  final String sancion;
  final String titleButton;
  final String icon;
  final void Function()? funcion;
  final void Function()? funcionCancelar;
  final bool isLoading;
  final Widget? child;

  @override
  State<ModalOption> createState() => _ModalOptionState();
}

class _ModalOptionState extends State<ModalOption> {
  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    final responsive = Responsive.of(context);
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
                  CustomHeading(
                    title: widget.title,
                    subTitle: widget.subtitle,
                    fonsizeTitle: responsive.heightPercent(2),
                    fonsizesubTitle: responsive.heightPercent(1.5),
                    color: Theme.of(context).textTheme.bodyLarge!.color!,
                    centro: true,
                  ),
                  if (widget.sancion != '')
                    const SizedBox(
                      height: 10,
                    ),
                  if (widget.sancion != '')
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: lunchColor.withOpacity(.05),
                        border: Border.all(color: lunchColor, width: 0.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            '${assetImgIcon}userFaltas.svg',
                            color: lunchColor,
                            width: responsive.heightPercent(1.6),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Nota: ', // Texto dinámico
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.4,
                                            ),
                                            color: lunchColor,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Montserrat',
                                            height: 1.1,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              widget.sancion, // Texto dinámico
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.4,
                                            ),
                                            color: lunchColor,
                                            fontFamily: 'Montserrat',
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.child != null) widget.child!,
                  const SizedBox(
                    height: smallSpacer,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      CustomButtonBoxStyle(
                        title: widget.titleButton,
                        funcion: widget.funcion,
                        color: violet,
                        iconActive: true,
                        icon: widget.icon,
                        fontSize: responsive.heightPercent(1.4),
                        sizeHeight: responsive.widthPercent(10),
                        sizeWidth: responsive.widthPercent(40),
                        isLoading: widget.isLoading,
                      ),
                      CustomButtonBoxStyle(
                        title: 'Cancelar',
                        funcion:
                            widget.funcionCancelar ??
                            () {
                              context.pop(false);
                            },
                        color: darkMode
                            ? Theme.of(context).scaffoldBackgroundColor
                            : const Color(0xffD8DDE2),
                        titleColor: Theme.of(context).hintColor,
                        iconColor: Theme.of(context).hintColor,
                        iconActive: true,
                        icon: 'close.svg',
                        fontSize: responsive.heightPercent(1.4),
                        sizeHeight: responsive.widthPercent(10),
                        sizeWidth: responsive.widthPercent(40),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: smallSpacer,
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
