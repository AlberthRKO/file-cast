import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomCardDispositivo extends StatelessWidget {
  const CustomCardDispositivo({
    required this.image,
    required this.nombre,
    required this.fechaUltimaAutenticacion,
    required this.fechaExpiracion,
    required this.identificador,
    super.key,
    this.colorIcon = primary,
    this.onCerrarSesion,
  });

  final String image;
  final String fechaUltimaAutenticacion;
  final String fechaExpiracion;
  final String nombre;
  final String identificador;
  final Color colorIcon;
  final VoidCallback? onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          width: responsive.width,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: textBlack.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                child: Row(
                  children: [
                    Container(
                      width: responsive.width * .13,
                      height: responsive.width * .13,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorIcon.withOpacity(.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: SvgPicture.asset(
                        assetImgIcon + image,
                        color: colorIcon,
                        width: 25,
                      ),
                    ),
                    const SizedBox(
                      width: miniSpacer,
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  nombre,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge!.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  identificador,
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
                                    color: Theme.of(context).hintColor,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Row(
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
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            'Ultima autenticación: ', // Título en verde
                                        style: TextStyle(
                                          fontSize: responsive.heightPercent(
                                            1.3,
                                          ),
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                          height: 1.1,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            fechaUltimaAutenticacion, // Descripción
                                        style: TextStyle(
                                          fontSize: responsive.heightPercent(
                                            1.3,
                                          ),
                                          color: Theme.of(context).hintColor,
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
                          const SizedBox(
                            height: 4,
                          ),
                          Row(
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
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            'Fecha expiración: ', // Título en verde
                                        style: TextStyle(
                                          fontSize: responsive.heightPercent(
                                            1.3,
                                          ),
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                          height: 1.1,
                                        ),
                                      ),
                                      TextSpan(
                                        text: fechaExpiracion, // Descripción
                                        style: TextStyle(
                                          fontSize: responsive.heightPercent(
                                            1.3,
                                          ),
                                          color: Theme.of(context).hintColor,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onCerrarSesion != null)
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: onCerrarSesion,
              child: Container(
                width: responsive.heightPercent(3.5),
                height: responsive.heightPercent(3.5),
                decoration: BoxDecoration(
                  color: deleteColor.withOpacity(.9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    '${assetImgIcon}logout.svg',
                    color: textWhite,
                    width: responsive.heightPercent(1.6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
