// import 'dart:ui';

import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
// import 'package:cca/theme/padding.dart';
import 'package:flutter/material.dart';

class CustomTitle extends StatelessWidget {
  const CustomTitle({
    required this.title,
    super.key,
    this.route = '/404',
    this.extend = true,
    this.fontSize = 16.0,
    this.centro = false,
    this.color = primary,
    this.funcion,
    this.textLink = 'Ver todo',
  });

  final String title;
  final String route;
  final bool centro;
  final bool extend;
  final double fontSize;
  final Color color;
  final void Function()? funcion;
  final String textLink;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Row(
      mainAxisAlignment: centro
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (extend)
          GestureDetector(
            onTap: funcion,
            child: Text(
              textLink,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: responsive.heightPercent(1.6),
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          Container(),
      ],
    );
  }
}

class CustomTitle2 extends StatelessWidget {
  const CustomTitle2({
    required this.title,
    super.key,
    this.route = '/404',
    this.extend = true,
    this.fontSize = 16.0,
    this.centro = false,
    this.color = primary,
    this.funcion,
    this.widget,
  });

  final String title;
  final String route;
  final bool centro;
  final bool extend;
  final double fontSize;
  final Color color;
  final void Function()? funcion;
  final Widget? widget;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centro
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (extend) widget ?? Container() else Container(),
      ],
    );
  }
}
