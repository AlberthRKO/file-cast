import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/utils/funciones.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardAprobacionAlmacen extends StatelessWidget {
  const CardAprobacionAlmacen({
    required this.title,
    required this.funcionarios,
    required this.codigo,
    required this.canViewDoc,
    super.key,
    this.time,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.almacen,
    this.fechaSolicitud,
    this.fechaAutorizacion,
    this.colorProgress = violet,
    this.porcentaje = 0,
    this.isProgress = true,
    this.statePorcentaje = '',
    this.onViewItems,
    this.onView,
    this.onViewDoc,
    this.onAprobar,
    this.onObservar,
    this.onRechazar,
    this.canAprobar = false,
    this.canObservar = false,
    this.canRechazar = false,
    this.funcionario = '',
  });

  final String title;
  final String funcionarios;
  final String codigo;
  final String? time;
  final String? fechaSolicitud;
  final String? fechaAutorizacion;
  final String? almacen;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color colorProgress;
  final double porcentaje;
  final bool isProgress;
  final String statePorcentaje;
  final void Function()? onViewItems;
  final String funcionario;

  final void Function()? onView;
  final void Function()? onViewDoc;
  final void Function()? onAprobar;
  final void Function()? onObservar;
  final void Function()? onRechazar;

  final bool canViewDoc;
  final bool canAprobar;
  final bool canObservar;
  final bool canRechazar;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: responsive.width,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        gradient: LinearGradient(
          colors: [
            background, // #145388
            // #7178EB
            background, // #145388
          ],
          stops: const [
            0.0,
            1.0,
          ], // Controla la posición relativa de los colores
          begin: Alignment.topLeft, // Ajusta el ángulo a 45 grados
          end: Alignment.bottomRight, // Ajusta el ángulo a 45 grados
        ),
        boxShadow: [
          BoxShadow(
            color: textBlack.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: responsive.heightPercent(1.7),
                        color: colorText,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              InkWell(
                onTap: onViewItems,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: responsive.widthPercent(10),
                  width: responsive.widthPercent(10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: SvgPicture.asset(
                    '${assetImgIcon}modelo.svg',
                    color: Theme.of(context).primaryColor,
                    width: responsive.heightPercent(2),
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton2(
                  customButton: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      '${assetImgIcon}ellipsisH.svg',
                      width: responsive.heightPercent(2.8),
                      // color: textColor,
                      color: colorText,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Ver',
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            '${assetImgIcon}eye.svg',
                            color: Theme.of(context).canvasColor,
                            width: responsive.heightPercent(2.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ver',
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.5),
                              color: Theme.of(context).canvasColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canViewDoc)
                      DropdownMenuItem(
                        value: 'Ver Documento',
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              '${assetImgIcon}verDoc.svg',
                              color: Theme.of(context).canvasColor,
                              width: responsive.heightPercent(2.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ver Documento',
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.5),
                                color: Theme.of(context).canvasColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (canAprobar)
                      DropdownMenuItem(
                        value: 'Aprobar',
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              '${assetImgIcon}fileAprobar.svg',
                              color: textSucces,
                              width: responsive.heightPercent(2.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Aprobar',
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.5),
                                color: textSucces,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (canObservar)
                      DropdownMenuItem(
                        value: 'Observar',
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              '${assetImgIcon}contrato.svg',
                              color: esam,
                              width: responsive.heightPercent(2.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Observar',
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.5),
                                color: esam,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (canRechazar)
                      DropdownMenuItem(
                        value: 'Rechazar',
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              '${assetImgIcon}fileRechazar.svg',
                              color: deleteColor,
                              width: responsive.heightPercent(2.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rechazar',
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.5),
                                color: deleteColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    // Manejo de las opciones seleccionadas
                    if (value == 'Ver') {
                      onView!();
                    } else if (value == 'Ver Documento') {
                      onViewDoc!();
                    } else if (value == 'Aprobar') {
                      onAprobar!();
                    } else if (value == 'Observar') {
                      onObservar!();
                    } else if (value == 'Rechazar') {
                      onRechazar!();
                    }
                  },
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    width: responsive.widthPercent(45),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).canvasColor.withOpacity(.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).cardColor,
                    ),
                    scrollbarTheme: ScrollbarThemeData(
                      radius: const Radius.circular(40),
                      thickness: MaterialStateProperty.all<double>(6),
                      thumbVisibility: MaterialStateProperty.all<bool>(true),
                    ),
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    height: 40,
                    padding: EdgeInsets.only(left: 14, right: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          if (funcionario != '')
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono en color verde
                SvgPicture.asset(
                  '${assetImgIcon}user_icon.svg',
                  color: Theme.of(
                    context,
                  ).primaryColor, // Color verde para el ícono
                  width: responsive.heightPercent(1.6),
                ),
                const SizedBox(width: 5),
                // Título y descripción
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'De: ', // Título en verde
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: funcionario, // Descripción
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: colorDescription,
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
          if (funcionario != '')
            const SizedBox(
              height: 5,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primer bloque: Ícono + Título + Descripción
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono en color verde
                    SvgPicture.asset(
                      '${assetImgIcon}atrasos.svg',
                      color: Theme.of(
                        context,
                      ).primaryColor, // Color verde para el ícono
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    // Título y descripción
                    Flexible(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Codigo: ', // Título en verde
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: codigo, // Descripción
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: colorDescription,
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
              const SizedBox(width: 3), // Espaciado entre bloques
              // Segundo bloque: Ícono + Título + Descripción
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Ícono en color verde
                    SvgPicture.asset(
                      '${assetImgIcon}modelo.svg',
                      color: Theme.of(
                        context,
                      ).primaryColor, // Color verde para el ícono
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    // Título y descripción
                    Flexible(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Almacen: ', // Título en verde
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: almacen, // Descripción
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: colorDescription,
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
          const SizedBox(
            height: 5,
          ),
          /*Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primer bloque: Ícono + Título + Descripción
              if (fechaSolicitud != null)
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícono en color verde
                      SvgPicture.asset(
                        "${assetImgIcon}marca.svg",
                        color: Theme.of(context)
                            .primaryColor, // Color verde para el ícono
                        width: responsive.heightPercent(1.6),
                      ),
                      const SizedBox(width: 5),
                      // Título y descripción
                      Flexible(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Tipo de Solicitud: ", // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: tipoSolicitud, // Descripción
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: colorDescription,
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
          SizedBox(
            height: 5,
          ),*/
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primer bloque: Ícono + Título + Descripción
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono en color verde
                    SvgPicture.asset(
                      '${assetImgIcon}calendar.svg',
                      color: Theme.of(
                        context,
                      ).primaryColor, // Color verde para el ícono
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    // Título y descripción
                    Flexible(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Solicitud: ', // Título en verde
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: formatDateWithYear(
                                fechaSolicitud!,
                              ), // Descripción
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: colorDescription,
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
              if (fechaAutorizacion != null)
                const SizedBox(width: 3), // Espaciado entre bloques
              // Segundo bloque: Ícono + Título + Descripción
              if (fechaAutorizacion != null)
                Flexible(
                  child: Row(
                    mainAxisAlignment: fechaAutorizacion != null
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      // Ícono en color verde
                      SvgPicture.asset(
                        '${assetImgIcon}calendar.svg',
                        color: Theme.of(
                          context,
                        ).primaryColor, // Color verde para el ícono
                        width: responsive.heightPercent(1.6),
                      ),
                      const SizedBox(width: 5),
                      // Título y descripción
                      Flexible(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Autorización: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Montserrat',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: formatDateWithYear(
                                  fechaAutorizacion!,
                                ), // Descripción
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: colorDescription,
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
          SizedBox(
            height: fechaSolicitud != null || fechaAutorizacion != null ? 5 : 0,
          ),
          if (isProgress)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statePorcentaje,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.3),
                    color: colorDescription,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: colorProgress.withOpacity(.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: porcentaje / 100,
                            child: Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: colorProgress.withOpacity(.7),
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorProgress.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: responsive.widthPercent(10),
                      alignment: Alignment.center,
                      child: Text(
                        '$porcentaje%',
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.1),
                          color: colorProgress,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            const SizedBox(),
          const SizedBox(
            height: 10,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                '${assetImgIcon}user_icon.svg',
                color: Theme.of(context).primaryColor,
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
                              text: 'Funcionarios ', // Título en verde
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: '\n$funcionarios', // Descripción
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: colorDescription,
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
        ],
      ),
    );
  }
}
