import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardPermiso extends StatelessWidget {
  const CardPermiso({
    required this.title,
    required this.dirigido,
    required this.status,
    required this.canEdit,
    required this.canDelete,
    required this.canViewDpc,
    required this.isSelected,
    required this.onCheckboxChanged,
    required this.fecha,
    required this.horaIni,
    required this.horaFin,
    required this.tiempo,
    required this.canTrayecto,
    super.key,
    this.time,
    this.porcentaje = 0,
    this.isProgress = true,
    this.isInfoNota = false,
    this.onEdit,
    this.onSend,
    this.onDelete,
    this.onView,
    this.onViewDoc,
    this.onTracking,
    this.onTrackingStop,
    this.onTrackingDestino,
    this.maxBarWidth = 200,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.colorProgress = violet,
    this.onTrayecto,
    this.paraUbicacion = false,
    this.onAprobar,
    this.onObservar,
    this.onRechazar,
    this.canAprobar = false,
    this.canObservar = false,
    this.canRechazar = false,
    this.canTracking = false,
    this.canTrackingStop = false,
    this.canTrackingDestino = false,
    this.canMensajeTrancking = false,
    this.destino,
    this.motivo,
    this.inMap = false,
    this.onVerRespaldo,
    this.canRespaldo = false,
    this.canSubirRespaldo = false,
    this.onSubirRespaldo,
    this.onAmpliar,
    this.canAmpliar = false,
    this.textRespaldo = 'Subir Respaldo',
  });

  final bool paraUbicacion;
  final String title;
  final String dirigido;
  final String fecha;
  final String horaIni;
  final String horaFin;
  final String tiempo;
  final String? time;
  final String? motivo;
  final String? destino;
  final double porcentaje;
  final double maxBarWidth;
  final bool isProgress;
  final bool canMensajeTrancking;
  final bool isInfoNota;
  final void Function()? onEdit;
  final void Function()? onSend;
  final void Function()? onDelete;
  final void Function()? onView;
  final void Function()? onViewDoc;
  final void Function()? onTrayecto;
  final void Function()? onAprobar;
  final void Function()? onObservar;
  final void Function()? onRechazar;
  final void Function()? onTracking;
  final void Function()? onTrackingStop;
  final void Function()? onTrackingDestino;
  final void Function()? onVerRespaldo;
  final void Function()? onAmpliar;
  final bool canEdit;
  final bool canDelete;
  final bool canViewDpc;
  final bool canTrayecto;
  final bool canAprobar;
  final bool canObservar;
  final bool canRechazar;
  final bool canRespaldo;
  final bool canTracking;
  final bool canTrackingStop;
  final bool canTrackingDestino;
  final bool canAmpliar;
  final String status;
  final bool isSelected;
  final ValueChanged<bool?> onCheckboxChanged;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;
  final Color colorProgress;
  final bool inMap;
  final bool canSubirRespaldo;
  final void Function()? onSubirRespaldo;
  final String textRespaldo;

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
            padding: paraUbicacion
                ? const EdgeInsets.symmetric(vertical: 5, horizontal: 15)
                : const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
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
                        color: paraUbicacion
                            ? colorTelegram.withOpacity(.1)
                            : state.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: paraUbicacion
                          ? Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end, // Alineación derecha
                              children: [
                                SvgPicture.asset(
                                  '${assetImgIcon}clock.svg',
                                  color: colorTelegram,
                                  width: responsive.heightPercent(1.6),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tiempo, // Fecha
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
                                    color: colorTelegram,
                                  ),
                                ),
                              ],
                            )
                          : Text(
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
                    if (!paraUbicacion)
                      const SizedBox(
                        width: 10,
                      ),
                    if (!paraUbicacion)
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
                            if (canViewDpc)
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
                            if (canTrayecto)
                              DropdownMenuItem(
                                value: 'Ver Trayecto',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      '${assetImgIcon}trackingNew.svg',
                                      color: Theme.of(context).canvasColor,
                                      width: responsive.heightPercent(2.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ver Trayecto',
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
                                value: 'Editar',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      '${assetImgIcon}edit.svg',
                                      color: Theme.of(context).canvasColor,
                                      width: responsive.heightPercent(2.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Editar',
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.5),
                                        color: Theme.of(context).canvasColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (canAmpliar)
                              DropdownMenuItem(
                                value: 'Ampliar',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      '${assetImgIcon}clock.svg',
                                      color: Theme.of(context).canvasColor,
                                      width: responsive.heightPercent(2.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ampliar',
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.5),
                                        color: Theme.of(context).canvasColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (canDelete)
                              DropdownMenuItem(
                                value: 'Cancelar',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      '${assetImgIcon}close.svg',
                                      color: deleteColor,
                                      width: responsive.heightPercent(2.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.5),
                                        color: deleteColor,
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
                            if (canRespaldo)
                              DropdownMenuItem(
                                value: 'Ver Respaldo',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      '${assetImgIcon}contrato.svg',
                                      color: Theme.of(context).canvasColor,
                                      width: responsive.heightPercent(2.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ver Respaldo',
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.5),
                                        color: Theme.of(context).canvasColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (canSubirRespaldo)
                              DropdownMenuItem(
                                value: 'Subir Respaldo',
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      '${assetImgIcon}upload.svg',
                                      color: Theme.of(context).canvasColor,
                                      width: responsive.heightPercent(2.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      textRespaldo,
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.5),
                                        color: Theme.of(context).canvasColor,
                                        height: 1.1,
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
                            } else if (value == 'Ver Trayecto') {
                              onTrayecto!();
                            } else if (value == 'Editar') {
                              onEdit!();
                            } else if (value == 'Ampliar') {
                              onAmpliar!();
                            } else if (value == 'Enviar') {
                              onSend!();
                            } else if (value == 'Cancelar') {
                              onDelete!();
                            } else if (value == 'Aprobar') {
                              onAprobar!();
                            } else if (value == 'Observar') {
                              onObservar!();
                            } else if (value == 'Rechazar') {
                              onRechazar!();
                            } else if (value == 'Ver Respaldo') {
                              onVerRespaldo!();
                            } else if (value == 'Subir Respaldo') {
                              onSubirRespaldo!();
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
                SizedBox(
                  height: paraUbicacion ? 5 : 10,
                ),
                if (!paraUbicacion)
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
                      const SizedBox(width: 20), // Espaciado entre los bloques
                      // Segundo bloque: Ícono + Texto
                      Row(
                        children: [
                          SvgPicture.asset(
                            '${assetImgIcon}calendar.svg',
                            color: colorDescription,
                            width: responsive.heightPercent(1.6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            fecha, // Fecha
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
                  children: [
                    // Primer bloque: Ícono + Texto
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            '${assetImgIcon}estado.svg',
                            color: colorDescription,
                            width: responsive.heightPercent(1.6),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  horaIni,
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
                                    color: colorDescription,
                                  ),
                                ),
                                Text(
                                  ' - ',
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
                                    color: colorDescription,
                                  ),
                                ),
                                Text(
                                  horaFin,
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
                          paraUbicacion
                              ? '${assetImgIcon}calendar.svg'
                              : '${assetImgIcon}clock.svg',
                          color: colorDescription,
                          width: responsive.heightPercent(1.6),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          paraUbicacion ? fecha : tiempo, // Fecha
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: colorDescription,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (motivo != null && motivo != '')
                  const SizedBox(
                    height: 5,
                  ),
                if (motivo != null && motivo != '')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        '${assetImgIcon}contrato.svg',
                        color: colorDescription,
                        width: responsive.heightPercent(1.6),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Motivo: $motivo', // Texto dinámico
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: colorDescription,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (destino != null && destino != '')
                  const SizedBox(
                    height: 5,
                  ),
                if (destino != null && destino != '')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        '${assetImgIcon}address.svg',
                        color: colorDescription,
                        width: responsive.heightPercent(1.6),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Destino: $destino', // Texto dinámico
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: colorDescription,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (!paraUbicacion)
                  const SizedBox(
                    height: 10,
                  ),
                if (!paraUbicacion)
                  isProgress
                      ? Row(
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
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorProgress.withOpacity(
                                              0.1,
                                            ),
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
                      : const SizedBox(),
                if (canMensajeTrancking)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: colorTelegram.withOpacity(.05),
                      border: Border.all(color: colorTelegram, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          '${assetImgIcon}walking.svg',
                          color: colorTelegram,
                          width: responsive.heightPercent(2),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tiene su tracking en proceso sin finalizar, amplie su permiso para poder finalizar su tracking.',
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.3),
                                        color: colorTelegram,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  margin: EdgeInsets.symmetric(
                    vertical: canTracking || canTrackingStop ? 10 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (canTracking)
                        CustomButtonBoxStyle(
                          funcion: onTracking,
                          title: 'Iniciar Recorrido',
                          icon: 'walking.svg',
                          sizeHeight: responsive.widthPercent(8),
                          sizeWidth: responsive.widthPercent(37),
                          fontSize: responsive.heightPercent(1.2),
                          iconActive: true,
                          color: violet,
                        ),
                      if (canTrackingDestino)
                        CustomButtonBoxStyle(
                          funcion: onTrackingDestino,
                          title: 'Marcar Destino',
                          icon: 'address.svg',
                          sizeHeight: responsive.widthPercent(8),
                          sizeWidth: responsive.widthPercent(37),
                          fontSize: responsive.heightPercent(1.2),
                          iconActive: true,
                          color: Theme.of(context).primaryColor,
                        ),
                      if (canTrackingStop)
                        CustomButtonBoxStyle(
                          funcion: onTrackingStop,
                          title: 'Finalizar Recorrido',
                          icon: 'walking.svg',
                          sizeHeight: responsive.widthPercent(8),
                          sizeWidth: responsive.widthPercent(37),
                          fontSize: responsive.heightPercent(1.2),
                          iconActive: true,
                          titleColor: violet,
                          color: esam,
                        ),
                    ],
                  ),
                ),
                if (paraUbicacion)
                  const SizedBox(
                    height: 10,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
