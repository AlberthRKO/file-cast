import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            bottom: responsive.heightPercent(36 + 6),
            child: SvgPicture.asset(
              '${assetImgIcon}folder.svg',
              width: responsive.widthPercent(101),
              color: folder4,
            ),
          ),
          Positioned(
            bottom: responsive.heightPercent(24 + 6),
            child: SvgPicture.asset(
              '${assetImgIcon}folder.svg',
              width: responsive.widthPercent(101),
              color: folder3,
            ),
          ),
          Positioned(
            bottom: responsive.heightPercent(12 + 6),
            child: SvgPicture.asset(
              '${assetImgIcon}folder.svg',
              width: responsive.widthPercent(101),
              color: folder2,
            ),
          ),
          Positioned(
            bottom: responsive.heightPercent(6),
            child: SvgPicture.asset(
              '${assetImgIcon}folder.svg',
              width: responsive.widthPercent(101),
              color: folder1,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: responsive.width,
              height: responsive.heightPercent(12),
              color: folder1,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: responsive.heightPercent(6),
              bottom: responsive.heightPercent(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text(
                    Config.appName,
                    style: TextStyle(
                      fontSize: responsive.heightPercent(2.5),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ),
                Column(
                  children: [
                    CustomHeading(
                      title: 'La forma más fácil de registrar evidencias',
                      subTitle:
                          'Registra y monitorea las evidencias que obtienes',
                      color2: Theme.of(context).hintColor,
                      fontWeightSubtitle: FontWeight.w600,
                      fonsizeTitle: responsive.heightPercent(3),
                      fonsizesubTitle: responsive.heightPercent(1.5),
                      fontWeight: FontWeight.w700,
                      color: textWhite,
                    ),
                    const SizedBox(height: miniSpacer),
                    /* TextFormCustom(
                      onChanged: (text) {},
                      iconColor: Theme.of(context).primaryColor,
                      prefixIcon: 'cardEmployee.svg',
                      labelText: 'Número de Documento',
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Número de Documento vacío';
                        }
                        if (text.contains(' ')) {
                          return 'El número de documento no debe contener espacios.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: miniSpacer * 2),
                    TextFormCustom(
                      onChanged: (text) {},
                      iconColor: Theme.of(context).primaryColor,
                      prefixIcon: 'lock.svg',
                      labelText: 'Contraseña',
                      isPassword: true,
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Contraseña Vacía';
                        }
                        if (text.startsWith(' ') || text.endsWith(' ')) {
                          return 'No debe haber espacios en blanco al principio ni al final de la contraseña.';
                        }
                        return null;
                      },
                    ), */
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomButtonBoxStyle(
                          funcion: () async {},
                          fontSize: responsive.heightPercent(1.8),
                          icon: 'paper.svg',
                          sizeHeight: responsive.widthPercent(14),
                          sizeWidth: responsive.widthPercent(50),
                          iconActive: true,
                          isShadow: true,
                          titleColor: textColor,
                          color: textWhite,
                          title: 'Empezar',
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
