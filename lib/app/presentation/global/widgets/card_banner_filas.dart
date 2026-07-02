import 'package:flutter/material.dart';
import 'package:file_cast/app/presentation/global/controllers/theme_controller.dart';
import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:file_cast/app/presentation/global/widgets/custom_button_box.dart';
import 'package:provider/provider.dart';

class CardBannerFilas extends StatelessWidget {
  const CardBannerFilas({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.titleButton,
    required this.iconbutton,
    super.key,
    this.bgColor = colorCard,
    this.bgButton = esam,
    this.color = secondary,
    this.textButtonColor = secondary,
    this.reverse = false,
    this.funcion,
  });

  final String title;
  final String subtitle;
  final String image;
  final Color bgColor;
  final Color bgButton;
  final Color color;
  final Color textButtonColor;
  final String titleButton;
  final bool reverse;
  final void Function()? funcion;
  final String iconbutton;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    final responsive = Responsive.of(context);
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: -10,
          child: Container(
            width: responsive.width * .85,
            height: 50,
            decoration: BoxDecoration(
              color: darkMode
                  ? violet.withOpacity(.5)
                  : bgColor.withOpacity(.7),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Container(
          width: responsive.width,
          height: 130,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          decoration: BoxDecoration(
            color: darkMode ? violet : bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: reverse
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: responsive.width * .425,
                child: Text(
                  title,
                  textAlign: reverse ? TextAlign.end : TextAlign.start,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(2),
                    color: darkMode ? textWhite : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              SizedBox(
                width: responsive.width * .425,
                child: Text(
                  subtitle,
                  textAlign: reverse ? TextAlign.end : TextAlign.start,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.3),
                    fontWeight: FontWeight.w400,
                    color: darkMode ? textWhite : color,
                  ),
                  maxLines: 2, // Limita el texto a 2 líneas
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              CustomButtonBoxStyle(
                title: titleButton,
                funcion: funcion,
                color: darkMode ? textWhite : bgButton,
                titleColor: darkMode ? textColor : textButtonColor,
                iconColor: Theme.of(context).hintColor,
                iconActive: true,
                icon: iconbutton,
                fontSize: responsive.heightPercent(1.3),
                sizeHeight: responsive.widthPercent(8),
                sizeWidth: responsive.widthPercent(30),
                isShadow: true,
              ),
            ],
          ),
        ),
        if (reverse)
          Positioned(
            top: -responsive.width * .12,
            left: 0,
            child: SizedBox(
              height: responsive.width * .50,
              child: Image.asset(
                image,
                width: responsive.width * .45,
              ),
            ),
          )
        else
          Positioned(
            top: -responsive.width * .12,
            right: 0,
            child: SizedBox(
              height: responsive.width * .50,
              child: Image.asset(
                image,
                width: responsive.width * .45,
              ),
            ),
          ),
      ],
    );
  }
}
