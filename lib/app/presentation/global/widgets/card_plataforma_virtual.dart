import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/complemento.dart';
import 'package:file_cast/app/presentation/global/utils/funciones.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';

class CardPlataformaVirtual extends StatelessWidget {
  const CardPlataformaVirtual({
    required this.title,
    required this.status,
    required this.canEdit,
    required this.canDelete,
    required this.canSend,
    required this.canApprove,
    required this.isSelected,
    required this.onCheckboxChanged,
    required this.actividad,
    required this.fechaCreacion,
    required this.fechaEnvio,
    required this.fechaRespuesta,
    required this.cantidadCompartida,
    required this.cantidadAprobada,
    super.key,
    this.time,
    this.porcentaje = 0,
    this.isProgress = true,
    this.isInfoNota = false,
    this.onEdit,
    this.onSend,
    this.onDelete,
    this.onView,
    this.onApprove,
    this.maxBarWidth = 200,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.colorProgress = violet,
    this.referencia = '',
    this.onCompartidaTap,
    this.onAprobadaTap,
  });

  String getEstado(String estado) {
    switch (estado) {
      case '0':
        return 'Borrador';
      case '1':
        return 'Aprobado digitalmente';
      case '2':
        return 'Enviado';
      case '3':
        return 'Respondido';
      default:
        return '';
    }
  }

  final String title;
  final String actividad;
  final String fechaCreacion;
  final String fechaEnvio;
  final String fechaRespuesta;
  final String referencia;
  final int cantidadCompartida;
  final int cantidadAprobada;
  final String? time;
  final double porcentaje;
  final double maxBarWidth;
  final bool isProgress;
  final bool isInfoNota;
  final void Function()? onEdit;
  final void Function()? onSend;
  final void Function()? onDelete;
  final void Function()? onView;
  final void Function()? onApprove;
  final bool canSend;
  final bool canApprove;
  final bool canEdit;
  final bool canDelete;
  final String status;
  final bool isSelected;
  final ValueChanged<bool?> onCheckboxChanged;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;
  final Color colorProgress;
  final VoidCallback? onCompartidaTap;
  final VoidCallback? onAprobadaTap;

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
                              fontSize: 16,
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
                        getEstado(status),
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.3),
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
                            width: 25,
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
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ver',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).canvasColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canSend)
                            DropdownMenuItem(
                              value: 'Enviar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}paper.svg',
                                    color: Theme.of(context).canvasColor,
                                    width: 25,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Enviar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).canvasColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (canApprove)
                            DropdownMenuItem(
                              value: 'Aprobar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}check.svg',
                                    color: Theme.of(context).canvasColor,
                                    width: 25,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Aprobar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).canvasColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (canEdit)
                            DropdownMenuItem(
                              value: 'Editar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}edit.svg',
                                    color: Theme.of(context).canvasColor,
                                    width: 25,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Editar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).canvasColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (canDelete)
                            DropdownMenuItem(
                              value: 'Eliminar',
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}delete.svg',
                                    color: deleteColor,
                                    width: 25,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      fontSize: 14,
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
                          } else if (value == 'Aprobar') {
                            onApprove!();
                          } else if (value == 'Editar') {
                            onEdit!();
                          } else if (value == 'Enviar') {
                            onSend!();
                          } else if (value == 'Eliminar') {
                            onDelete!();
                          }
                        },
                        iconStyleData: const IconStyleData(
                          icon: Icon(
                            Icons.arrow_forward_ios_outlined,
                          ),
                          iconSize: 14,
                          iconEnabledColor: Colors.yellow,
                          iconDisabledColor: Colors.grey,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 200,
                          width: 150,
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
                    SvgPicture.asset(
                      '${assetImgIcon}file.svg',
                      color: Theme.of(context).primaryColor,
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actividad:', // Texto dinámico
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(
                              actividad, // Texto dinámico
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
                    SvgPicture.asset(
                      '${assetImgIcon}file.svg',
                      color: Theme.of(context).primaryColor,
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Referencia:', // Texto dinámico
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(
                              referencia, // Texto dinámico
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
                    SvgPicture.asset(
                      '${assetImgIcon}calendar.svg',
                      color: Theme.of(context).primaryColor,
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creación:', // Texto dinámico
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(
                              formatDateWithDayAndTimeLocal(
                                fechaCreacion,
                              ), // Texto dinámico
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
                    SvgPicture.asset(
                      '${assetImgIcon}calendar.svg',
                      color: Theme.of(context).primaryColor,
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Envio:', // Texto dinámico
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(
                              fechaEnvio.isNotEmpty
                                  ? formatDateWithDayAndTimeLocal(fechaEnvio)
                                  : 'No enviado', // Texto dinámico
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
                    SvgPicture.asset(
                      '${assetImgIcon}calendar.svg',
                      color: Theme.of(context).primaryColor,
                      width: responsive.heightPercent(1.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Respuesta:', // Texto dinámico
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(
                              fechaRespuesta.isNotEmpty
                                  ? formatDateWithDayAndTimeLocal(
                                      fechaRespuesta,
                                    )
                                  : 'Sin respuesta', // Texto dinámico
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
                    // Primer bloque: Ícono + Título + Descripción
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contenedor con borde que incluye el ícono
                          InkWell(
                            onTap: onCompartidaTap,
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap:
                                  onCompartidaTap, // Callback que llamará a la función que mostrará el modal
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).canvasColor.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // El contenido interno sigue igual
                                    SvgPicture.asset(
                                      '${assetImgIcon}share.svg',
                                      color: Theme.of(context).canvasColor,
                                      width: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Compartida: ',
                                            style: TextStyle(
                                              fontSize: responsive
                                                  .heightPercent(1.3),
                                              color: Theme.of(
                                                context,
                                              ).canvasColor,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Poppins',
                                              height: 1.1,
                                            ),
                                          ),
                                          TextSpan(
                                            text: cantidadCompartida.toString(),
                                            style: TextStyle(
                                              fontSize: responsive
                                                  .heightPercent(1.3),
                                              color: Theme.of(
                                                context,
                                              ).canvasColor,
                                              fontFamily: 'Poppins',
                                              height: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
                        // Contenedor con borde que incluye el ícono
                        InkWell(
                          onTap: onAprobadaTap,
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onTap:
                                onAprobadaTap, // Callback que llamará a la función que mostrará el modal
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 3,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).canvasColor.withOpacity(.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    '${assetImgIcon}check.svg',
                                    color: Theme.of(context).canvasColor,
                                    width: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Aprobada: ',
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.3,
                                            ),
                                            color: Theme.of(
                                              context,
                                            ).canvasColor,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                            height: 1.1,
                                          ),
                                        ),
                                        TextSpan(
                                          text: cantidadAprobada.toString(),
                                          style: TextStyle(
                                            fontSize: responsive.heightPercent(
                                              1.3,
                                            ),
                                            color: Theme.of(
                                              context,
                                            ).canvasColor,
                                            fontFamily: 'Poppins',
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
