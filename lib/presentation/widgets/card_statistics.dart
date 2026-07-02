import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardHorario extends StatelessWidget {
  const CardHorario({
    required this.title,
    required this.horaIngreso,
    required this.horaSalida,
    required this.cantidad,
    super.key,
    this.icon = 'user_icon.svg',
    this.colorIcon = primary,
    this.colorText = primary,
    this.sizeCircle = 25,
    this.isTiempo = false,
    this.iconTiempo = 'dia.svg',
  });

  final String title;
  final String icon;
  final String horaIngreso;
  final String horaSalida;
  final double sizeCircle;
  final Color colorIcon;
  final Color colorText;
  final String cantidad;
  final bool isTiempo;
  final String iconTiempo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      width: responsive.widthPercent(44),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: textBlack.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isTiempo)
            Positioned(
              right: -25,
              bottom: -25,
              child: Opacity(
                opacity: 0.3,
                child: SvgPicture.asset(
                  '$assetImgIcon$iconTiempo',
                  width: 80,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Row(
                  children: [
                    Container(
                      height: sizeCircle,
                      width: sizeCircle,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorIcon.withOpacity(.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: SvgPicture.asset(
                        '${assetImgIcon}entrada.svg',
                        color: colorIcon,
                        width: 15,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Entrada: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            horaIngreso,
                            style: TextStyle(
                              color: colorText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 5,
                ),
                Row(
                  children: [
                    Container(
                      height: sizeCircle,
                      width: sizeCircle,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorIcon.withOpacity(.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: SvgPicture.asset(
                        '${assetImgIcon}salida.svg',
                        color: colorIcon,
                        width: 15,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Salida: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            horaSalida,
                            style: TextStyle(
                              color: colorText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CardHorarioNew extends StatelessWidget {
  const CardHorarioNew({
    required this.title,
    required this.horaIngreso,
    required this.horaIngresoRegular,
    required this.horaSalida,
    required this.horaSalidaRegular,
    super.key,
    this.icon = 'user_icon.svg',
    this.colorIcon = primary,
    this.colorText = primary,
    this.colorTextRegistro = primary,
    this.sizeCircle = 25,
    this.isTiempo = false,
    this.iconTiempo = 'dia.svg',
    this.atraso = false,
    this.shadow = false,
    this.background = Colors.transparent,
    this.isWithHour = false,
    this.timeAtraso,
    this.child,
    this.titleEntrada = 'Entrada',
    this.isWithSalida = true,
    this.padding = 12,
    this.isTemporalEntrada = false,
    this.isTemporalSalida = false,
  });

  final String title;
  final String titleEntrada;
  final String icon;
  final String horaIngreso;
  final String horaIngresoRegular;
  final String horaSalida;
  final String horaSalidaRegular;
  final double sizeCircle;
  final Color colorIcon;
  final Color colorText;
  final Color colorTextRegistro;
  final bool isTiempo;
  final String iconTiempo;
  final String? timeAtraso;
  final bool atraso;
  final bool shadow;
  final Color background;
  final bool isWithHour;
  final bool isWithSalida;
  final Widget? child;
  final double padding;
  final bool isTemporalEntrada;
  final bool isTemporalSalida;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: textBlack.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    fontSize: responsive.heightPercent(1.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (atraso)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: esam.withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Atraso: ', // Título en verde
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.2),
                              color: esam,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          TextSpan(
                            text: timeAtraso ?? '', // Descripción
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.2),
                              color: esam,
                              fontFamily: 'AlarmClock',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        height: sizeCircle,
                        width: sizeCircle,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorIcon.withOpacity(.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: SvgPicture.asset(
                          '${assetImgIcon}entrada.svg',
                          color: colorIcon,
                          width: responsive.heightPercent(1.5),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$titleEntrada: ',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: responsive.heightPercent(1.2),
                        ),
                      ),
                      Text(
                        "$horaIngresoRegular${isWithHour ? "" : "/"}",
                        style: TextStyle(
                          color: colorText,
                          fontFamily: 'AlarmClock',
                          fontSize: responsive.heightPercent(1.6),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      if (!isWithHour)
                        Text(
                          horaIngreso,
                          style: TextStyle(
                            color: isTemporalEntrada ? esam : colorTextRegistro,
                            fontFamily: 'AlarmClock',
                            fontSize: responsive.heightPercent(1.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isWithSalida)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment
                          .end, // Alinea el segundo grupo a la derecha
                      children: [
                        Container(
                          height: sizeCircle,
                          width: sizeCircle,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorIcon.withOpacity(.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: SvgPicture.asset(
                            '${assetImgIcon}salida.svg',
                            color: colorIcon,
                            width: responsive.heightPercent(1.5),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Salida: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: responsive.heightPercent(1.2),
                          ),
                        ),
                        Text(
                          "$horaSalidaRegular${isWithHour ? "" : "/"}",
                          style: TextStyle(
                            color: colorText,
                            fontFamily: 'AlarmClock',
                            fontSize: responsive.heightPercent(1.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isWithHour)
                          Text(
                            horaSalida,
                            style: TextStyle(
                              color: isTemporalSalida
                                  ? esam
                                  : colorTextRegistro,
                              fontFamily: 'AlarmClock',
                              fontSize: responsive.heightPercent(1.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (child != null) const SizedBox(height: 10),
            ?child,
          ],
        ),
      ),
    );
  }
}

class CardHorarioNew4 extends StatelessWidget {
  const CardHorarioNew4({
    required this.title,
    required this.horaIngreso,
    required this.horaIngresoRegular,
    required this.horaSalida,
    required this.horaSalidaRegular,
    super.key,
    this.icon = 'user_icon.svg',
    this.colorIcon = primary,
    this.colorText = primary,
    this.colorTextRegistro = primary,
    this.sizeCircle = 25,
    this.isTiempo = false,
    this.iconTiempo = 'dia.svg',
    this.atraso = false,
    this.shadow = false,
    this.background = Colors.transparent,
    this.isWithHour = false,
    this.timeAtraso,
    this.child,
    this.titleEntrada = 'Entrada',
    this.isWithSalida = true,
    this.padding = 12,
    this.isTemporalEntrada = false,
    this.isTemporalSalida = false,
  });

  final String title;
  final String titleEntrada;
  final String icon;
  final String horaIngreso;
  final String horaIngresoRegular;
  final String horaSalida;
  final String horaSalidaRegular;
  final double sizeCircle;
  final Color colorIcon;
  final Color colorText;
  final Color colorTextRegistro;
  final bool isTiempo;
  final String iconTiempo;
  final String? timeAtraso;
  final bool atraso;
  final bool shadow;
  final Color background;
  final bool isWithHour;
  final bool isWithSalida;
  final Widget? child;
  final double padding;
  final bool isTemporalEntrada;
  final bool isTemporalSalida;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: textBlack.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    fontSize: responsive.heightPercent(1.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (atraso)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: esam.withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Atraso: ', // Título en verde
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.2),
                              color: esam,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          TextSpan(
                            text: timeAtraso ?? '', // Descripción
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.2),
                              color: esam,
                              fontFamily: 'AlarmClock',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        height: sizeCircle,
                        width: sizeCircle,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorIcon.withOpacity(.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: SvgPicture.asset(
                          '${assetImgIcon}entrada.svg',
                          color: colorIcon,
                          width: responsive.heightPercent(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$titleEntrada: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: responsive.heightPercent(1.3),
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$horaIngresoRegular${isWithHour ? "" : "/"}",
                                style: TextStyle(
                                  color: colorText,
                                  fontFamily: 'AlarmClock',
                                  fontSize: responsive.heightPercent(1.7),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.end,
                              ),
                              if (!isWithHour)
                                Text(
                                  horaIngreso,
                                  style: TextStyle(
                                    color: isTemporalEntrada
                                        ? Theme.of(context).hintColor
                                        : colorTextRegistro,
                                    fontFamily: 'AlarmClock',
                                    fontSize: responsive.heightPercent(1.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isWithSalida)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment
                          .end, // Alinea el segundo grupo a la derecha
                      children: [
                        Container(
                          height: sizeCircle,
                          width: sizeCircle,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorIcon.withOpacity(.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: SvgPicture.asset(
                            '${assetImgIcon}salida.svg',
                            color: colorIcon,
                            width: responsive.heightPercent(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Salida: ',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: responsive.heightPercent(1.3),
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "$horaSalidaRegular${isWithHour ? "" : "/"}",
                                  style: TextStyle(
                                    color: colorText,
                                    fontFamily: 'AlarmClock',
                                    fontSize: responsive.heightPercent(1.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!isWithHour)
                                  Text(
                                    horaSalida,
                                    style: TextStyle(
                                      color: isTemporalSalida
                                          ? Theme.of(context).hintColor
                                          : colorTextRegistro,
                                      fontFamily: 'AlarmClock',
                                      fontSize: responsive.heightPercent(1.7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (child != null) const SizedBox(height: 10),
            ?child,
          ],
        ),
      ),
    );
  }
}

class CardHorarioNew2 extends StatelessWidget {
  const CardHorarioNew2({
    required this.title,
    required this.horaIngreso,
    required this.horaIngresoRegular,
    required this.horaSalida,
    required this.horaSalidaRegular,
    super.key,
    this.icon = 'user_icon.svg',
    this.colorIcon = primary,
    this.colorText = primary,
    this.colorTextRegistro = primary,
    this.sizeCircle = 35,
    this.isTiempo = false,
    this.iconTiempo = 'dia.svg',
    this.atraso = false,
    this.shadow = false,
    this.background = Colors.transparent,
    this.isWithHour = false,
    this.timeAtraso,
  });

  final String title;
  final String icon;
  final String horaIngreso;
  final String horaIngresoRegular;
  final String horaSalida;
  final String horaSalidaRegular;
  final double sizeCircle;
  final Color colorIcon;
  final Color colorText;
  final Color colorTextRegistro;
  final bool isTiempo;
  final String iconTiempo;
  final bool atraso;
  final bool shadow;
  final Color background;
  final bool isWithHour;
  final String? timeAtraso;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: textBlack.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    fontSize: responsive.heightPercent(1.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (atraso)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: esam.withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Atraso: ', // Título en verde
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.2),
                              color: esam,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          TextSpan(
                            text: timeAtraso ?? '', // Descripción
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.2),
                              color: esam,
                              fontFamily: 'AlarmClock',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        height: sizeCircle,
                        width: sizeCircle,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorIcon.withOpacity(.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: SvgPicture.asset(
                          '${assetImgIcon}entrada.svg',
                          color: colorIcon,
                          width: responsive.heightPercent(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entrada: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: responsive.heightPercent(1.3),
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Row(
                            children: [
                              Text(
                                "$horaIngresoRegular${isWithHour ? "" : "/"}",
                                style: TextStyle(
                                  color: colorText,
                                  fontFamily: 'AlarmClock',
                                  fontSize: responsive.heightPercent(1.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!isWithHour)
                                Text(
                                  horaIngreso,
                                  style: TextStyle(
                                    color: atraso ? esam : colorTextRegistro,
                                    fontFamily: 'AlarmClock',
                                    fontSize: responsive.heightPercent(1.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment
                        .end, // Alinea el segundo grupo a la derecha
                    children: [
                      Container(
                        height: sizeCircle,
                        width: sizeCircle,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorIcon.withOpacity(.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: SvgPicture.asset(
                          '${assetImgIcon}salida.svg',
                          color: colorIcon,
                          width: responsive.heightPercent(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salida: ',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: responsive.heightPercent(1.3),
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Row(
                            children: [
                              Text(
                                "$horaSalidaRegular${isWithHour ? "" : "/"}",
                                style: TextStyle(
                                  color: colorText,
                                  fontFamily: 'AlarmClock',
                                  fontSize: responsive.heightPercent(1.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!isWithHour)
                                Text(
                                  horaSalida,
                                  style: TextStyle(
                                    color: colorTextRegistro,
                                    fontFamily: 'AlarmClock',
                                    fontSize: responsive.heightPercent(1.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CardHorario2 extends StatelessWidget {
  const CardHorario2({
    required this.title,
    required this.horaIngreso,
    required this.horaSalida,
    required this.cantidad,
    super.key,
    this.icon = 'user_icon.svg',
    this.colorIcon = primary,
    this.colorText = primary,
    this.sizeCircle = 25,
    this.isTiempo = false,
    this.iconTiempo = 'dia.svg',
  });

  final String title;
  final String icon;
  final String horaIngreso;
  final String horaSalida;
  final double sizeCircle;
  final Color colorIcon;
  final Color colorText;
  final String cantidad;
  final bool isTiempo;
  final String iconTiempo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      width: responsive.widthPercent(39),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Row(
            children: [
              Container(
                height: sizeCircle,
                width: sizeCircle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorIcon.withOpacity(.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: SvgPicture.asset(
                  '${assetImgIcon}entrada.svg',
                  color: colorIcon,
                  width: 15,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Entrada: ',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Text(
                      horaIngreso,
                      style: TextStyle(
                        color: colorText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Row(
            children: [
              Container(
                height: sizeCircle,
                width: sizeCircle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorIcon.withOpacity(.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: SvgPicture.asset(
                  '${assetImgIcon}salida.svg',
                  color: colorIcon,
                  width: 15,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Salida: ',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Text(
                      horaSalida,
                      style: TextStyle(
                        color: colorText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CardHorarioNew3 extends StatelessWidget {
  const CardHorarioNew3({
    required this.title,
    required this.horaIngreso,
    required this.horaIngresoRegular,
    required this.horaSalida,
    required this.horaSalidaRegular,
    super.key,
    this.icon = 'user_icon.svg',
    this.colorIcon = primary,
    this.colorText = primary,
    this.colorTextRegistro = primary,
    this.sizeCircle = 25,
    this.isTiempo = false,
    this.iconTiempo = 'dia.svg',
    this.atraso = false,
    this.shadow = false,
    this.background = Colors.transparent,
    this.isWithHour = false,
    this.timeAtraso,
    this.child,
    this.titleEntrada = 'Entrada',
    this.isWithSalida = true,
    this.funcion,
  });

  final String title;
  final String titleEntrada;
  final String icon;
  final String horaIngreso;
  final String horaIngresoRegular;
  final String horaSalida;
  final String horaSalidaRegular;
  final double sizeCircle;
  final Color colorIcon;
  final Color colorText;
  final Color colorTextRegistro;
  final bool isTiempo;
  final String iconTiempo;
  final String? timeAtraso;
  final bool atraso;
  final bool shadow;
  final Color background;
  final bool isWithHour;
  final bool isWithSalida;
  final Widget? child;
  final void Function()? funcion;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: textBlack.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge!.color,
                              fontSize: responsive.heightPercent(1.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (atraso)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: esam.withOpacity(.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Atraso: ', // Título en verde
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.2),
                                        color: esam,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    TextSpan(
                                      text: timeAtraso ?? '', // Descripción
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.2),
                                        color: esam,
                                        fontFamily: 'AlarmClock',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  height: sizeCircle,
                                  width: sizeCircle,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorIcon.withOpacity(.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: SvgPicture.asset(
                                    '${assetImgIcon}entrada.svg',
                                    color: colorIcon,
                                    width: responsive.heightPercent(1.5),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$titleEntrada: ',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontSize: responsive.heightPercent(1.2),
                                  ),
                                ),
                                Text(
                                  "$horaIngresoRegular${isWithHour ? "" : "/"}",
                                  style: TextStyle(
                                    color: colorText,
                                    fontFamily: 'AlarmClock',
                                    fontSize: responsive.heightPercent(1.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                                if (!isWithHour)
                                  Text(
                                    horaIngreso,
                                    style: TextStyle(
                                      color: atraso ? esam : colorTextRegistro,
                                      fontFamily: 'AlarmClock',
                                      fontSize: responsive.heightPercent(1.6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isWithSalida)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .end, // Alinea el segundo grupo a la derecha
                                children: [
                                  Container(
                                    height: sizeCircle,
                                    width: sizeCircle,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: colorIcon.withOpacity(.1),
                                      borderRadius: BorderRadius.circular(
                                        100,
                                      ),
                                    ),
                                    child: SvgPicture.asset(
                                      '${assetImgIcon}salida.svg',
                                      color: colorIcon,
                                      width: responsive.heightPercent(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Salida: ',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontSize: responsive.heightPercent(1.2),
                                    ),
                                  ),
                                  Text(
                                    "$horaSalidaRegular${isWithHour ? "" : "/"}",
                                    style: TextStyle(
                                      color: colorText,
                                      fontFamily: 'AlarmClock',
                                      fontSize: responsive.heightPercent(1.6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!isWithHour)
                                    Text(
                                      horaSalida,
                                      style: TextStyle(
                                        color: colorTextRegistro,
                                        fontFamily: 'AlarmClock',
                                        fontSize: responsive.heightPercent(1.6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isWithSalida)
                  InkWell(
                    onTap: funcion,
                    child: Container(
                      height: 50,
                      width: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorIcon.withOpacity(.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: SvgPicture.asset(
                        '${assetImgIcon}address.svg',
                        color: colorIcon,
                        width: responsive.heightPercent(2.5),
                      ),
                    ),
                  ),
              ],
            ),
            if (child != null) const SizedBox(height: 10),
            ?child,
          ],
        ),
      ),
    );
  }
}
