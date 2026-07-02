import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ModalAlmuerzo extends StatefulWidget {
  const ModalAlmuerzo({
    super.key,
  });

  @override
  State<ModalAlmuerzo> createState() => _ModalAlmuerzoState();
}

class _ModalAlmuerzoState extends State<ModalAlmuerzo> {
  bool fetching = false;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    final responsive = Responsive.of(context);
    return Form(
      child: Builder(
        builder: (context) {
          return AbsorbPointer(
            absorbing: fetching,
            child: Container(
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
                      title: 'Salida de Almuerzo',
                      subTitle:
                          'Esta generando su salida de almuerzo, tiene 30 minutos a partir de la marcación en el biométrico.',
                      fonsizeTitle: responsive.heightPercent(2),
                      fonsizesubTitle: responsive.heightPercent(1.5),
                      color: Theme.of(context).textTheme.bodyLarge!.color!,
                      centro: true,
                    ),
                    const SizedBox(
                      height: smallSpacer,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        CustomButtonBoxStyle(
                          title: 'Confirmar',
                          funcion: () {},
                          color: violet,
                          iconActive: true,
                          icon: 'food.svg',
                          fontSize: responsive.heightPercent(1.4),
                          sizeHeight: responsive.widthPercent(10),
                          sizeWidth: responsive.widthPercent(35),
                          isLoading: fetching,
                        ),
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
                          fontSize: responsive.heightPercent(1.4),
                          sizeHeight: responsive.widthPercent(10),
                          sizeWidth: responsive.widthPercent(35),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: smallSpacer,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
