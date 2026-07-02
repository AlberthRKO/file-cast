import 'dart:convert';
import 'dart:typed_data';

import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardDetailInfo extends StatelessWidget {
  const CardDetailInfo({
    required this.name,
    required this.fecha,
    required this.modalidad,
    required this.serie,
    required this.numM,
    required this.cPortal,
    super.key,
  });

  final String name;
  final String modalidad;
  final String serie;
  final String numM;
  final String cPortal;
  final String fecha;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Card(
      elevation: 4, // Controla la intensidad del BoxShadow
      shadowColor: primary.withOpacity(0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        width: size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17.5),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nombre: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: textBlack,
                      fontFamily: 'Exo2',
                    ),
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
                const Text(
                  'Modalidad: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: Text(
                    modalidad,
                    style: const TextStyle(
                      fontSize: 12,
                      color: textBlack,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 5,
            ),
            Row(
              children: [
                Flexible(
                  flex: 5,
                  child: Row(
                    children: [
                      const Text(
                        'Carnet Portal: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Exo2',
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        cPortal,
                        style: const TextStyle(
                          fontSize: 12,
                          color: textBlack,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 5,
                  child: Row(
                    children: [
                      const Text(
                        'Fecha Venta: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Exo2',
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        fecha,
                        style: const TextStyle(
                          fontSize: 12,
                          color: textBlack,
                          fontFamily: 'Exo2',
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
                Flexible(
                  flex: 5,
                  child: Row(
                    children: [
                      const Text(
                        'Serie Matricula: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Exo2',
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        serie,
                        style: const TextStyle(
                          fontSize: 12,
                          color: textBlack,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 5,
                  child: Row(
                    children: [
                      const Text(
                        'Número Matricula: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Exo2',
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        numM,
                        style: const TextStyle(
                          fontSize: 12,
                          color: textBlack,
                          fontFamily: 'Exo2',
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
    );
  }
}

class CardDetailStudent extends StatelessWidget {
  const CardDetailStudent({
    required this.name,
    required this.ciPortal,
    required this.ciIdentidad,
    required this.modalidad,
    super.key,
  });

  final String name;
  final String ciPortal;
  final String ciIdentidad;
  final String modalidad;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        // boxShadow: [
        //   BoxShadow(
        //     color: primary.withOpacity(0.2),
        //     spreadRadius: 0.0,
        //     blurRadius: 6.0,
        //     offset: const Offset(0, 2),
        //   )
        // ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          width: size.width,
          decoration: const BoxDecoration(
            color: textWhite,
            // border: Border(
            //   left: BorderSide(
            //     color: primary,
            //     width: 5.0,
            //   ),
            // ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 25,
                        width: 25,
                        decoration: BoxDecoration(
                          color: colorCard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImg}user_icon.svg',
                          width: 10,
                          // color: textColor,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      const Text(
                        'Estudiante: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              Row(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 25,
                        width: 25,
                        decoration: BoxDecoration(
                          color: colorCard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImg}key_icon.svg',
                          width: 13,
                          // color: textColor,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      const Text(
                        'Acceso al Moodle: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Flexible(
                    child: Text(
                      ciPortal,
                      style: const TextStyle(
                        fontSize: 13,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              Row(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 25,
                        width: 25,
                        decoration: BoxDecoration(
                          color: colorCard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImg}facturaTotal.svg',
                          width: 13,
                          // color: textColor,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      const Text(
                        'Carnet de Identidad: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Flexible(
                    child: Text(
                      ciIdentidad,
                      style: const TextStyle(
                        fontSize: 13,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              Row(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 25,
                        width: 25,
                        decoration: BoxDecoration(
                          color: colorCard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImg}rocket_icon.svg',
                          width: 13,
                          // color: textColor,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      const Text(
                        'Modalidad: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Flexible(
                    child: Text(
                      modalidad,
                      style: const TextStyle(
                        fontSize: 13,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardDetailStudent2 extends StatelessWidget {
  const CardDetailStudent2({
    required this.name,
    required this.ciPortal,
    required this.ciIdentidad,
    super.key,
    this.primerApellido = '',
    this.segundoApellido = '',
    this.photo = '',
  });

  final String name;
  final String primerApellido;
  final String segundoApellido;
  final String ciPortal;
  final String ciIdentidad;
  final String photo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    Widget getUserProfileImage() {
      if (photo != '' && photo.isNotEmpty) {
        try {
          final Uint8List bytes = base64Decode(photo.split(',').last);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 500,
          );
        } catch (e) {
          print('Error al decodificar la imagen: $e');
        }
      }
      // Si no hay imagen válida, se usa la imagen por defecto
      return Image.asset(
        '${assetImg}perfil.png',
        fit: BoxFit.cover,
        width: 500,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          width: responsive.widthPercent(100),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre: ',
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                          child: Text(
                            name.toUpperCase(),
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall!.color,
                            ),
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
                        Text(
                          'Apellido: ',
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                          child: Text(
                            '${primerApellido.toUpperCase()} ${segundoApellido.toUpperCase()}',
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall!.color,
                            ),
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
                        Text(
                          'Carnet Identidad: ',
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                          child: Text(
                            ciIdentidad,
                            style: TextStyle(
                              fontSize: responsive.heightPercent(1.3),
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall!.color,
                            ),
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
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Dirección: ',
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
                                    color: Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ciPortal,
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall!.color,
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
      ),
    );
  }
}
