import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class CustomButtonBox extends StatelessWidget {
  const CustomButtonBox({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: 45,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // color: primary.withOpacity(0.7),
        color: primary,
        borderRadius: BorderRadius.circular(17.5),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textWhite,
        ),
      ),
    );
  }
}

class CustomButtonBoxDelete extends StatelessWidget {
  const CustomButtonBoxDelete({
    required this.title,
    super.key,
    this.typeCancel = true,
  });

  final String title;
  final bool typeCancel;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width * .3,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: typeCancel ? textWhite : deleteColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: typeCancel
            ? Border.all(color: deleteColor.withOpacity(.7))
            : null,
        boxShadow: [
          if (typeCancel)
            const BoxShadow()
          else
            BoxShadow(
              color: deleteColor.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: typeCancel ? deleteColor : textWhite,
        ),
      ),
    );
  }
}

class CustomButtonBoxCrud extends StatelessWidget {
  const CustomButtonBoxCrud({
    required this.title,
    super.key,
    this.color = textWhite,
    this.typeCancel = true,
    this.titleColor = textWhite,
    this.option = false,
    this.sizeWidth = 0,
    this.icon = 'eye.svg',
    this.iconActive = false,
  });

  final String title;
  final Color color;
  final bool typeCancel;
  final Color titleColor;
  final bool option;
  final double sizeWidth;
  final bool iconActive;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: sizeWidth == 0 ? size.width * .4 : sizeWidth,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: typeCancel ? textWhite : color.withOpacity(1),
        borderRadius: BorderRadius.circular(10),
        border: typeCancel
            ? Border.all(color: deleteColor.withOpacity(.7))
            : option
            ? Border.all(color: titleColor.withOpacity(.7))
            : null,
        boxShadow: [
          if (typeCancel)
            const BoxShadow()
          else
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!iconActive)
            Container()
          else
            SvgPicture.asset(
              '$assetImgIcon$icon',
              color: textWhite,
              width: 18,
            ),
          if (!iconActive)
            Container()
          else
            const SizedBox(
              width: 10,
            ),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: typeCancel ? deleteColor : titleColor,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomButtonBoxStyle extends StatelessWidget {
  const CustomButtonBoxStyle({
    required this.title,
    super.key,
    this.color = primary,
    this.typeCancel = true,
    this.titleColor = textWhite,
    this.option = false,
    this.sizeWidth = 0,
    this.sizeHeight = 40,
    this.icon = 'eye.svg',
    this.iconColor = textWhite,
    this.iconActive = false,
    this.funcion,
    this.fontSize,
    this.cancel = false,
    this.fontWeight = FontWeight.w600,
    this.isBorder = false,
    this.colorBorder = primary,
    this.isLoading = false,
    this.reverse = false,
    this.isShadowCustom = false,
    this.isShadow = false,
  });
  final bool reverse;
  final bool isBorder;
  final String title;
  final Color color;
  final bool typeCancel;
  final Color titleColor;
  final bool option;
  final double? fontSize;
  final double sizeWidth;
  final double sizeHeight;
  final bool iconActive;
  final String icon;
  final Color iconColor;
  final Color colorBorder;
  final bool cancel;
  final FontWeight fontWeight;
  final void Function()? funcion;
  final bool isLoading;
  final bool isShadowCustom;
  final bool isShadow;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    return InkWell(
      onTap: funcion,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: sizeWidth == 0 ? responsive.width * .4 : sizeWidth,
        height: sizeHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cancel ? Theme.of(context).cardColor : color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            width: cancel
                ? 1
                : isBorder
                ? 1
                : 0,
            color: cancel
                ? deleteColor
                : isBorder
                ? colorBorder
                : color,
          ),
          boxShadow: isShadow
              ? null
              : isShadowCustom
              ? [
                  BoxShadow(
                    color: darkMode
                        ? Theme.of(context).primaryColor.withOpacity(0.15)
                        : Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 7),
                  ),
                ]
              : [
                  BoxShadow(
                    color: cancel
                        ? deleteColor.withOpacity(0.1)
                        : color.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconActive)
              Container()
            else
              isLoading
                  ? CircularProgressIndicator(
                      color: titleColor,
                      strokeWidth: 2,
                      strokeAlign: -7,
                    ) // Muestra el loader
                  : SvgPicture.asset(
                      '$assetImgIcon$icon',
                      color: cancel ? deleteColor : titleColor,
                      width: fontSize == null
                          ? responsive.heightPercent(2)
                          : fontSize! + 2,
                    ),
            if (!iconActive)
              Container()
            else
              const SizedBox(
                width: 10,
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize ?? responsive.heightPercent(1.7),
                fontWeight: fontWeight,
                color: cancel ? deleteColor : titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
