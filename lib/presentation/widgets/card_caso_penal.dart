import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/utils/funciones.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardCasoPenal extends StatelessWidget {
  const CardCasoPenal({
    required this.title,
    required this.status,
    required this.canSolicitar,
    required this.isSelected,
    required this.onCheckboxChanged,
    required this.delito,
    required this.fechaHecho,
    required this.sujeto,
    required this.cantidadActividades,
    required this.cantidadSujetos,
    required this.tipo,
    super.key,
    this.onSolicitar,
    this.onView,
    this.onActividades,
    this.onSujetos,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.colorProgress = violet,
    this.isAbogado = false,
    this.canViewAbogado = false,
    this.canViewCiudadano = false,
    this.canViewSujAbogado = false,
    this.canViewSujCiudadano = false,
    this.onViewAbogado,
    this.onViewCiudadano,
    this.onViewSujAbogado,
    this.onViewSujCiudadano,
    this.isAmbos = false,
  });

  final String title;
  final String sujeto;
  final String delito;
  final String fechaHecho;
  final String tipo;
  final int cantidadActividades;
  final int cantidadSujetos;
  final void Function()? onSolicitar;
  final void Function()? onView;
  final void Function()? onViewAbogado;
  final void Function()? onViewCiudadano;
  final void Function()? onViewSujAbogado;
  final void Function()? onViewSujCiudadano;
  final void Function()? onActividades;
  final void Function()? onSujetos;
  final bool canSolicitar;
  final bool canViewAbogado;
  final bool canViewCiudadano;
  final bool canViewSujAbogado;
  final bool canViewSujCiudadano;
  final String status;
  final bool isSelected;
  final ValueChanged<bool?> onCheckboxChanged;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;
  final Color colorProgress;
  final bool isAbogado;
  final bool isAmbos;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        onCheckboxChanged(!isSelected);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
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
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: state.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isAbogado
                            ? isAmbos
                                  ? 'Abogado\nCiudadano'
                                  : tipo
                            : status,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.2),
                          color: state,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                          if (canSolicitar)
                            DropdownMenuItem(
                              value: 'Solicitar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}paper.svg',
                                    color: Theme.of(context).canvasColor,
                                    width: responsive.heightPercent(2.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Solicitar',
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.5),
                                      color: Theme.of(context).canvasColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          DropdownMenuItem(
                            value: 'Ver Actividades',
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  '${assetImgIcon}file.svg',
                                  color: Theme.of(context).canvasColor,
                                  width: responsive.heightPercent(2.5),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ver Actividades',
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.5),
                                    color: Theme.of(context).canvasColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Ver Sujetos',
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  '${assetImgIcon}users.svg',
                                  color: Theme.of(context).canvasColor,
                                  width: responsive.heightPercent(2.5),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ver Sujetos',
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.5),
                                    color: Theme.of(context).canvasColor,
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
                          } else if (value == 'Solicitar') {
                            onSolicitar!();
                          } else if (value == 'Ver Actividades') {
                            onActividades!();
                          } else if (value == 'Ver Sujetos') {
                            onSujetos!();
                          }
                        },
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 200,
                          width: (!canViewAbogado || !canViewCiudadano)
                              ? responsive.widthPercent(45)
                              : responsive.widthPercent(55),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).canvasColor.withOpacity(.1),
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
                            thumbVisibility: MaterialStateProperty.all<bool>(
                              true,
                            ),
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
                if (delito != '')
                  Row(
                    children: [
                      // Segundo bloque: Ícono + Título + Descripción
                      Flexible(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ícono en color verde
                            SvgPicture.asset(
                              '${assetImgIcon}contrato.svg',
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
                                      text: 'Delito: ', // Título en verde
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    TextSpan(
                                      text: delito, // Descripción
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).hintColor,
                                        fontFamily: 'Poppins',
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
                if (delito != '')
                  const SizedBox(
                    height: 5,
                  ),
                if (isAbogado)
                  Row(
                    children: [
                      // Segundo bloque: Ícono + Título + Descripción
                      Flexible(
                        child: Row(
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
                                      text:
                                          'Sujeto Procesal: ', // Título en verde
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    TextSpan(
                                      text: sujeto, // Descripción
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).hintColor,
                                        fontFamily: 'Poppins',
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
                if (isAbogado)
                  const SizedBox(
                    height: 5,
                  ),
                if (isAmbos)
                  Row(
                    children: [
                      // Segundo bloque: Ícono + Título + Descripción
                      Flexible(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ícono en color verde
                            SvgPicture.asset(
                              '${assetImgIcon}marca.svg',
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
                                      text: 'Tipo: ', // Título en verde
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    TextSpan(
                                      text: tipo, // Descripción
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).hintColor,
                                        fontFamily: 'Poppins',
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
                if (isAmbos)
                  const SizedBox(
                    height: 5,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primer bloque: Ícono + Título + Descripción
                    if (!isAbogado)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ícono en color verde
                            SvgPicture.asset(
                              '${assetImgIcon}marca.svg',
                              color: Theme.of(
                                context,
                              ).primaryColor, // Color verde para el ícono
                              width: responsive.heightPercent(1.6),
                            ),
                            const SizedBox(width: 5),
                            // Título y descripción
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Tipo: ', // Título en verde
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        height: 1.1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: tipo, // Descripción
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: colorDescription,
                                        fontFamily: 'Poppins',
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
                    if (!isAbogado)
                      const SizedBox(width: 10), // Espaciado entre bloques
                    // Segundo bloque: Ícono + Título + Descripción
                    Row(
                      mainAxisAlignment: isAbogado
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      children: [
                        // Ícono en color verde
                        SvgPicture.asset(
                          '${assetImgIcon}calendar.svg',
                          color: Theme.of(
                            context,
                          ).primaryColor, // Color verde para el ícono
                          width: 15,
                        ),
                        const SizedBox(width: 5),
                        // Título y descripción
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Fecha: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: formatDateWithDayAndTimeLocal(
                                  fechaHecho,
                                ), // Descripción
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: colorDescription,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(
                  height: 5,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primer bloque: Ícono + Título + Descripción
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Actividades: ', // Título en verde
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      height: 1.1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '$cantidadActividades', // Descripción
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: colorDescription,
                                      fontFamily: 'Poppins',
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
                    const SizedBox(width: 20), // Espaciado entre bloques
                    // Segundo bloque: Ícono + Título + Descripción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Ícono en color verde
                        SvgPicture.asset(
                          '${assetImgIcon}user_icon.svg',
                          color: Theme.of(
                            context,
                          ).primaryColor, // Color verde para el ícono
                          width: 15,
                        ),
                        const SizedBox(width: 5),
                        // Título y descripción
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Sujetos: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: '$cantidadSujetos', // Descripción
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: colorDescription,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                            ],
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
    );
  }
}
