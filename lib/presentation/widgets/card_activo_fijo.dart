import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/utils/funciones.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/utils/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardActivoFijo extends StatelessWidget {
  const CardActivoFijo({
    required this.title,
    required this.description,
    required this.status,
    required this.canEdit,
    required this.canDelete,
    required this.fechaIncorporacion,
    required this.codigo,
    super.key,
    this.time,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.marca,
    this.modelo,
    this.serie,
    this.vidaUtil,
  });

  final String title;
  final String description;
  final String fechaIncorporacion;
  final String codigo;
  final String? modelo;
  final String? marca;
  final String? serie;
  final String? vidaUtil;
  final String? time;
  final bool canEdit;
  final bool canDelete;
  final String status;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          ExpandableText(
            text: description,
            style: TextStyle(
              fontSize: responsive.heightPercent(1.3),
              color: colorDescription,
            ),
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
                              text: 'Código: ', // Título en verde
                              style: TextStyle(
                                fontSize: responsive.heightPercent(1.3),
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: codigo, // Descripción
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

              // Segundo bloque: Ícono + Título + Descripción
              Flexible(
                child: Row(
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
                              text: 'Incorporación: ', // Título en verde
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
                                fechaIncorporacion,
                              ), // Descripción
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
          const SizedBox(
            height: 5,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primer bloque: Ícono + Título + Descripción
              if (marca != null)
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
                                text: 'Marca: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: marca, // Descripción
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
              if (marca != null)
                const SizedBox(width: 3), // Espaciado entre bloques
              // Segundo bloque: Ícono + Título + Descripción
              if (modelo != null)
                Flexible(
                  child: Row(
                    mainAxisAlignment: marca != null
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
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
                                text: 'Modelo: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: modelo, // Descripción
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
          SizedBox(
            height: marca != null || modelo != null ? 5 : 0,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primer bloque: Ícono + Título + Descripción
              if (serie != null)
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
                                text: 'Serie: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: serie, // Descripción
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
              if (serie != null)
                const SizedBox(width: 3), // Espaciado entre bloques
              // Segundo bloque: Ícono + Título + Descripción
              if (vidaUtil != null)
                Flexible(
                  child: Row(
                    mainAxisAlignment: serie != null
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
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
                                text: 'Vida Util: ', // Título en verde
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: '$vidaUtil años', // Descripción
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
        ],
      ),
    );
  }
}

class CardActivoFijoSmall extends StatelessWidget {
  const CardActivoFijoSmall({
    required this.title,
    required this.description,
    required this.codigo,
    super.key,
    this.background = fondoWhite,
    this.colorDescription = grey,
    this.colorText = textBlack,
    this.state = primary,
    this.onDelete,
  });

  final String title;
  final String description;
  final String codigo;
  final Color background;
  final Color colorText;
  final Color colorDescription;
  final Color state;
  final void Function()? onDelete;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$codigo - $title',
                      style: TextStyle(
                        fontSize: responsive.heightPercent(1.6),
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
                onTap: onDelete,
                child: Container(
                  height: responsive.widthPercent(8),
                  width: responsive.widthPercent(8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: deleteColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: SvgPicture.asset(
                    '${assetImgIcon}delete.svg',
                    color: deleteColor,
                    width: responsive.heightPercent(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          ExpandableText(
            text: description,
            style: TextStyle(
              fontSize: responsive.heightPercent(1.3),
              color: colorDescription,
            ),
          ),
        ],
      ),
    );
  }
}
