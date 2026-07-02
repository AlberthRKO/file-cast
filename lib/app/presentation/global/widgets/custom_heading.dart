import 'package:flutter/material.dart';

class CustomHeading extends StatelessWidget {
  const CustomHeading({
    super.key,
    required this.title,
    this.title2 = "",
    this.subTitle = "",
    required this.color,
    this.color2,
    this.centro = false,
    this.fonsizeTitle = 20.0,
    this.fonsizesubTitle = 14.0,
    this.fontWeight = FontWeight.w600,
    this.fontWeightSubtitle = FontWeight.w400,
  });

  final String title;
  final String title2;
  final String subTitle;
  final Color color;
  final Color? color2;
  final bool centro;
  final double fonsizeTitle;
  final double fonsizesubTitle;
  final FontWeight fontWeight;
  final FontWeight fontWeightSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          (centro) ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: fonsizeTitle,
            fontWeight: fontWeight,
          ),
          textAlign: centro ? TextAlign.center : TextAlign.left,
        ),
        subTitle == "" ? Container() : const SizedBox(height: 0.0),
        subTitle == ""
            ? Container()
            : Text(
                subTitle,
                style: TextStyle(
                  color: color2 ?? color,
                  fontSize: fonsizesubTitle,
                  fontWeight: fontWeightSubtitle,
                ),
                textAlign: centro ? TextAlign.center : TextAlign.left,
              ),
      ],
    );
  }
}

class CustomHeading2 extends StatelessWidget {
  const CustomHeading2({
    super.key,
    required this.title,
    required this.title2,
    required this.color,
    this.color2 = const Color(0xFF2EA5FF),
    this.align = 1,
    this.fonsizeTitle = 18.0,
    this.fonsizeTitle2 = 18.0,
  });

  final String title;
  final String title2;
  final Color color;
  final Color color2;
  final int align;
  final double fonsizeTitle;
  final double fonsizeTitle2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: (align == 0)
          ? CrossAxisAlignment.center
          : align == 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color2,
            fontSize: fonsizeTitle,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
          textAlign: align == 0
              ? TextAlign.center
              : align == 1
                  ? TextAlign.left
                  : TextAlign.end,
        ),
        SizedBox(
          height: 8,
        ),
        Text(
          title2,
          style: TextStyle(
            color: color,
            fontSize: fonsizeTitle2,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
          textAlign: align == 0
              ? TextAlign.center
              : align == 1
                  ? TextAlign.left
                  : TextAlign.end,
        ),
      ],
    );
  }
}

class CustomHeading3 extends StatelessWidget {
  const CustomHeading3({
    super.key,
    required this.title,
    this.title2 = "",
    this.subTitle = "",
    required this.color,
    this.color2,
    this.centro = false,
    this.fonsizeTitle = 20.0,
    this.fonsizeTitle3 = 16.0,
    this.fonsizesubTitle = 14.0,
    this.fontWeight = FontWeight.w600,
    this.fontWeightSubtitle = FontWeight.w400,
    this.title3 = "",
  });

  final String title;
  final String title2;
  final String title3;
  final String subTitle;
  final Color color;
  final Color? color2;
  final bool centro;
  final double fonsizeTitle;
  final double fonsizeTitle3;
  final double fonsizesubTitle;
  final FontWeight fontWeight;
  final FontWeight fontWeightSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          (centro) ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: fonsizeTitle,
            fontWeight: fontWeight,
          ),
          textAlign: centro ? TextAlign.end : TextAlign.left,
        ),
        Text(
          title3,
          style: TextStyle(
            color: color,
            fontSize: fonsizeTitle3,
            fontWeight: FontWeight.w500,
          ),
          textAlign: centro ? TextAlign.end : TextAlign.left,
        ),
        subTitle == "" ? Container() : const SizedBox(height: 0.0),
        subTitle == ""
            ? Container()
            : Text(
                subTitle,
                style: TextStyle(
                  color: color2 ?? color,
                  fontSize: fonsizesubTitle,
                  fontWeight: fontWeightSubtitle,
                ),
                textAlign: centro ? TextAlign.center : TextAlign.left,
              ),
      ],
    );
  }
}
