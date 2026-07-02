import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/utils/funciones.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardFaltaSancion extends StatelessWidget {
  const CardFaltaSancion({
    required this.title,
    required this.description,
    required this.status,
    required this.canEdit,
    required this.canDelete,
    required this.isSelected,
    required this.onCheckboxChanged,
    required this.sancion,
    required this.victima,
    required this.normativa,
    required this.fechaHecho,
    super.key,
    this.time,
    this.porcentaje = 0,
    this.isProgress = true,
    this.isInfoNota = false,
    this.onEdit,
    this.onSend,
    this.onDelete,
    this.onView,
    this.maxBarWidth = 200,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.colorSancion = lunchAction,
    this.colorProgress = violet,
    this.descriptionFalta,
    this.tipo = '',
  });

  final String title;
  final String description;
  final String sancion;
  final String victima;
  final String normativa;
  final String fechaHecho;
  final String? time;
  final String? descriptionFalta;
  final double porcentaje;
  final double maxBarWidth;
  final bool isProgress;
  final bool isInfoNota;
  final void Function()? onEdit;
  final void Function()? onSend;
  final void Function()? onDelete;
  final void Function()? onView;
  final bool canEdit;
  final bool canDelete;
  final String status;
  final bool isSelected;
  final ValueChanged<bool?> onCheckboxChanged;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;
  final Color colorSancion;
  final Color colorProgress;
  final String tipo;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onView,
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
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
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
                        status,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.2),
                          color: state,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    /*const SizedBox(
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
                            "${assetImgIcon}ellipsisH.svg",
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
                                  "${assetImgIcon}eye.svg",
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
                          if (canEdit)
                            DropdownMenuItem(
                              value: 'Descargar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    "${assetImgIcon}PdfDownloadIcon.svg",
                                    color: Theme.of(context).canvasColor,
                                    width: responsive.heightPercent(2.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Descargar',
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
                          } else if (value == 'Editar') {
                            onEdit!();
                          } else if (value == 'Enviar') {
                            onSend!();
                          } else if (value == 'Eliminar') {
                            onDelete!();
                          }
                        },
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 200,
                          width: responsive.widthPercent(35),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .canvasColor
                                    .withOpacity(.1),
                                spreadRadius: 0.0,
                                blurRadius: 6.0,
                                offset: const Offset(0, 2),
                              )
                            ],
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context).cardColor,
                          ),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(40),
                            thickness: MaterialStateProperty.all<double>(6),
                            thumbVisibility:
                                MaterialStateProperty.all<bool>(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 40,
                          padding: EdgeInsets.only(left: 14, right: 14),
                        ),
                      ),
                    ),*/
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primer bloque: Ícono + Texto
                    Expanded(
                      child: Row(
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
                                          text:
                                              'Funcionario: ', // Título en verde
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.3,
                                            ),
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                            height: 1.1,
                                          ),
                                        ),
                                        TextSpan(
                                          text: victima, // Descripción
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.3,
                                            ),
                                            color: colorDescription,
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
                    ),
                  ],
                ),
                const SizedBox(
                  height: 5,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      '${assetImgIcon}contrato.svg',
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
                                    text:
                                        'Motivo de falta o conducta: ', // Título en verde
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      height: 1.1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: descriptionFalta, // Descripción
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: colorDescription,
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
                const SizedBox(
                  height: 5,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      '${assetImgIcon}cvAll.svg',
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
                                    text: 'Disposición: ', // Título en verde
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      height: 1.1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: description, // Descripción
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: colorDescription,
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
                            '${assetImgIcon}atrasos.svg',
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
                                    text: 'Normativa: ', // Título en verde
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      height: 1.1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: normativa, // Descripción
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
                            '${assetImgIcon}atrasos.svg',
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
                    const SizedBox(width: 20), // Espaciado entre bloques
                    // Segundo bloque: Ícono + Título + Descripción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
                                text: formatDateWithYear(
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
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colorSancion.withOpacity(.05),
                    border: Border.all(color: colorSancion, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        '${assetImgIcon}userFaltas.svg',
                        color: colorSancion,
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
                                      text: 'Sancion: ', // Texto dinámico
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.4),
                                        color: colorSancion,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        height: 1.1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: sancion, // Texto dinámico
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.4),
                                        color: colorSancion,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
