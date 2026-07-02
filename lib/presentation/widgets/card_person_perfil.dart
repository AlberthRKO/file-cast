import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/utils/funciones.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardPersonPerfil extends StatefulWidget {
  const CardPersonPerfil({
    required this.nombre,
    required this.ci,
    required this.telefono,
    required this.correo,
    required this.sexo,
    required this.direccion,
    required this.fechaNacimiento,
    super.key,
  });

  final String nombre;
  final String ci;
  final String telefono;
  final String correo;
  final String sexo;
  final String direccion;
  final String fechaNacimiento;

  @override
  State<CardPersonPerfil> createState() => _CardPersonPerfilState();
}

class _CardPersonPerfilState extends State<CardPersonPerfil> {
  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                color: textBlack.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(
                height: responsive.heightPercent(6),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    '${assetImgIcon}cardEmployee.svg',
                    width: responsive.heightPercent(2),
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(
                    widget.ci,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),
              Text(
                widget.nombre,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: responsive.heightPercent(1.7),
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Container(
                        height: responsive.widthPercent(7),
                        width: responsive.widthPercent(7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}cardEmployee.svg',
                          width: responsive.heightPercent(2),
                          // color: textColor,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(
                        width: 2,
                      ),
                      Text(
                        formatDateWithYear(widget.fechaNacimiento),
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.3),
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                          // fontFamily: "Poppins",
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        height: responsive.widthPercent(7),
                        width: responsive.widthPercent(7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}phone.svg',
                          width: responsive.heightPercent(2),
                          // color: textColor,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(
                        width: 2,
                      ),
                      Text(
                        widget.telefono,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.3),
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                          // fontFamily: "Poppins",
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        height: responsive.widthPercent(7),
                        width: responsive.widthPercent(7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}sexo.svg',
                          width: responsive.heightPercent(2),
                          // color: textColor,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        widget.sexo,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.3),
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                          // fontFamily: "Poppins",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              Wrap(
                spacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize
                        .min, // Para evitar que Row ocupe todo el ancho
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: responsive.widthPercent(7),
                        width: responsive.widthPercent(7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}mail.svg',
                          width: responsive.heightPercent(2),
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        // Se usa para evitar desbordamientos dentro del Row
                        child: Text(
                          widget.correo,
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: responsive.widthPercent(7),
                        width: responsive.widthPercent(7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}address.svg',
                          width: responsive.heightPercent(2),
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          widget.direccion,
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
        Positioned(
          top: -responsive.widthPercent(12), // Ajusta según sea necesario
          child: Container(
            width: responsive.widthPercent(24),
            height: responsive.widthPercent(24),
            padding: const EdgeInsets.all(4), // Espacio para el borde
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).cardColor, // Fondo blanco para que el borde sea visible
              shape: BoxShape.circle,
            ),
            child: const Text('data'),
          ),
        ),
        /*Positioned(
          top: 35, // Ajusta según sea necesario para posicionar correctamente
          child: InkWell(
            onTap: () async {},
            child: Container(
              height: responsive.widthPercent(10),
              width: responsive.widthPercent(10),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: textBlack.withOpacity(0.1),
                    spreadRadius: 0.0,
                    blurRadius: 6.0,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                "${assetImgIcon}camera.svg",
                width: responsive.heightPercent(2.1),
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ),
        ),*/
      ],
    );
  }
}
