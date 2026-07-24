import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
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
    return Container(
      width: 1.sw,
      height: 45.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(17.5.r),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.8),
            blurRadius: 6.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
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
    return Container(
      width: 0.3.sw,
      height: 40.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: typeCancel ? textWhite : deleteColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: typeCancel
            ? Border.all(color: deleteColor.withOpacity(.7))
            : null,
        boxShadow: [
          if (typeCancel)
            const BoxShadow()
          else
            BoxShadow(
              color: deleteColor.withOpacity(0.5),
              blurRadius: 6.r,
              offset: Offset(0, 2.h),
            ),
        ],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
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
    return Container(
      width: sizeWidth == 0 ? 0.4.sw : sizeWidth,
      height: 40.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: typeCancel ? textWhite : color.withOpacity(1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
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
              blurRadius: 6.r,
              offset: Offset(0, 2.h),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconActive)
            SvgPicture.asset(
              '$assetImgIcon$icon',
              color: textWhite,
              width: 18.r,
            ),
          if (iconActive) SizedBox(width: AppDimensions.spaceS),
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
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
    this.isGradient = false,
    this.gradient,
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
  final Gradient? gradient;
  final bool isGradient;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    return InkWell(
      onTap: funcion,
      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      child: Container(
        width: sizeWidth == 0 ? 0.4.sw : sizeWidth,
        height: sizeHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isGradient
              ? null
              : cancel
              ? Theme.of(context).cardColor
              : color,
          gradient: isGradient ? gradient : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
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
          boxShadow: isShadow || isGradient
              ? null
              : isShadowCustom
              ? [
                  BoxShadow(
                    color: darkMode
                        ? Theme.of(context).primaryColor.withOpacity(0.15)
                        : Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: 15.r,
                    offset: Offset(0, 7.h),
                  ),
                ]
              : [
                  BoxShadow(
                    color: cancel
                        ? deleteColor.withOpacity(0.1)
                        : color.withOpacity(0.5),
                    blurRadius: 6.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconActive)
              isLoading
                  ? SizedBox(
                      width: (fontSize ?? 14.sp) + 2,
                      height: (fontSize ?? 14.sp) + 2,
                      child: CircularProgressIndicator(
                        color: titleColor,
                        strokeWidth: 2,
                      ),
                    )
                  : SvgPicture.asset(
                      '$assetImgIcon$icon',
                      color: cancel ? deleteColor : titleColor,
                      width: fontSize == null ? 20.r : fontSize! + 2,
                    ),
            if (iconActive) SizedBox(width: AppDimensions.spaceS),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize ?? 14.sp,
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
