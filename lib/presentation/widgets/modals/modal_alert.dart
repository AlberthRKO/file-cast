import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ModalAlert extends StatelessWidget {
  const ModalAlert({
    required this.type,
    super.key,
    this.name = '',
    this.provider = '',
    this.centro = false,
  });
  final String name;
  final String provider;
  final String type;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      padding: const EdgeInsets.all(appPadding),
      height: size.height * .18,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            '${assetImgIcon}check.svg',
            color: textSucces,
            width: 35,
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            type == 'BackMessage'
                ? '$provider $name'
                : '$provider $name $type exitosamente.',
            maxLines: 2,
            textAlign: centro ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontSize: 12,
              color: textSucces,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}
