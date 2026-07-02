import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/utils/funciones.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardOmisiones extends StatelessWidget {
  const CardOmisiones({
    required this.title,
    required this.dirigido,
    required this.status,
    required this.canJustificacion,
    required this.canDelete,
    required this.fecha,
    required this.turno,
    required this.fechaNoti,
    required this.fechaLimite,
    required this.estado,
    super.key,
    this.porcentaje = 0,
    this.isProgress = true,
    this.onJustificacion,
    this.onSend,
    this.onDelete,
    this.onView,
    this.onAprobar,
    this.canAprobar = false,
    this.canView = false,
    this.maxBarWidth = 200,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.colorProgress = violet,
  });

  final String title;
  final String dirigido;
  final String fecha;
  final String turno;
  final String fechaNoti;
  final String fechaLimite;
  final double porcentaje;
  final double maxBarWidth;
  final bool isProgress;
  final void Function()? onJustificacion;
  final void Function()? onSend;
  final void Function()? onDelete;
  final void Function()? onView;
  final void Function()? onAprobar;
  final bool canJustificacion;
  final bool canDelete;
  final bool canView;
  final bool canAprobar;
  final String status;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;
  final Color colorProgress;
  final int estado;

  bool isTimeExpired(String fechaLlegada, int daysToAdd) {
    final DateTime fechaExpiracion = DateTime.parse(
      fechaLlegada,
    ).add(Duration(days: daysToAdd));
    final DateTime fechaActual = DateTime.now();
    return fechaActual.isAfter(fechaExpiracion);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Column(
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
                  if (canAprobar || canView || canJustificacion)
                    const SizedBox(
                      width: 10,
                    ),
                  if (canAprobar || canView || canJustificacion)
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
                          if (canView)
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
                          if (canJustificacion)
                            DropdownMenuItem(
                              value: 'Justificar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}contrato.svg',
                                    color: Theme.of(context).canvasColor,
                                    width: responsive.heightPercent(2.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Justificar',
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
                                    '${assetImgIcon}like.svg',
                                    color: textSucces,
                                    width: responsive.heightPercent(2.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Visto bueno',
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.5),
                                      color: textSucces,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          // Manejo de las opciones seleccionadas
                          if (value == 'Ver Documento') {
                            onView!();
                          } else if (value == 'Justificar') {
                            onJustificacion!();
                          } else if (value == 'Aprobar') {
                            onAprobar!();
                          }
                        },
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 200,
                          width: responsive.widthPercent(45),
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
                          color: colorDescription,
                          width: responsive.heightPercent(1.6),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            dirigido, // Texto dinámico
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: colorDescription,
                              height: 1.1,
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
                  // Primer bloque: Ícono + Texto
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          '${assetImgIcon}calendar.svg',
                          color: colorDescription,
                          width: responsive.heightPercent(1.6),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                fecha,
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: colorDescription,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20), // Espaciado entre los bloques
                  // Segundo bloque: Ícono + Texto
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end, // Alineación derecha
                    children: [
                      SvgPicture.asset(
                        '${assetImgIcon}modelo.svg',
                        color: colorDescription,
                        width: responsive.heightPercent(1.6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Turno: $turno', // Fecha
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.3),
                          color: colorDescription,
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
                  // Primer bloque: Ícono + Texto
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          '${assetImgIcon}calendar.svg',
                          color: colorDescription,
                          width: responsive.heightPercent(1.6),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Notificado: $fechaNoti',
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: colorDescription,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (estado == 1)
                const SizedBox(
                  height: 5,
                ),
              if (estado == 1)
                Row(
                  children: [
                    // Primer bloque: Ícono + Texto
                    Expanded(
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            '${assetImgIcon}calendar.svg',
                            color: colorDescription,
                            width: responsive.heightPercent(1.6),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: isTimeExpired(fechaLimite, 2)
                                ? Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Límite:',
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.3,
                                            ),
                                            color: colorDescription,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: deleteColor2.withOpacity(.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'Tiempo expirado',
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.2,
                                            ),
                                            color: deleteColor2,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Límite: ${formatDateWithDayHourPlusDias(fechaLimite, 2)}',
                                    style: TextStyle(
                                      fontSize: responsive.heightPercent(1.3),
                                      color: colorDescription,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(
                height: 10,
              ),
              if (isProgress)
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
                      width: responsive.widthPercent(15),
                      alignment: Alignment.center,
                      child: Text(
                        '$porcentaje% Aprobación',
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.1),
                          color: colorProgress,
                        ),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(),
            ],
          ),
        ),
      ],
    );
  }
}
