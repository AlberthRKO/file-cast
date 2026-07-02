import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/app/domain/models/user/user_model.dart';
import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/complemento.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:file_cast/app/presentation/global/widgets/circle_button.dart';
import 'package:file_cast/app/presentation/global/widgets/custom_avatar.dart';
import 'package:file_cast/app/presentation/global/widgets/custom_heading.dart';
import 'package:file_cast/app/presentation/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class CustomAppbar extends StatelessWidget {
  const CustomAppbar({
    required this.user,
    super.key,
    this.isCurved = false,
    this.canFuncionario = false,
    this.canAbogado = false,
    this.canCiudadano = false,
    this.onFuncionario,
    this.onAbogado,
    this.onCiudadano,
    this.isNotificacion = false,
    this.countNoti = 0,
  });

  final bool isCurved;
  final UserModel user;
  final bool canFuncionario;
  final bool canAbogado;
  final bool canCiudadano;
  final bool isNotificacion;
  final void Function()? onFuncionario;
  final void Function()? onAbogado;
  final void Function()? onCiudadano;

  final int countNoti;
  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      height: responsive.heightPercent(25),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(
          bottom: isCurved
              ? const Radius.circular(25)
              : const Radius.circular(25),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: responsive.widthPercent(3),
            child: Column(
              children: [
                SizedBox(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                CustomMSAvatar(
                                  width: responsive.widthPercent(15),
                                  height: responsive.widthPercent(15),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: CustomHeading2(
                                    title: 'C.I. ${user.id ?? ''},',
                                    title2: user.nombreCompleto ?? '',
                                    color2: Theme.of(
                                      context,
                                    ).textTheme.labelSmall!.color!,
                                    fonsizeTitle: responsive.heightPercent(1.5),
                                    fonsizeTitle2: responsive.heightPercent(2),
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge!.color!,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isNotificacion)
                            const SizedBox(
                              width: 5,
                            ),
                          if (isNotificacion)
                            InkWell(
                              onTap: () async {
                                await context.pushNamed(Routes.settings);
                              },
                              borderRadius: BorderRadius.circular(100),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    height: responsive.widthPercent(10),
                                    width: responsive.widthPercent(10),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      '${assetImgIcon}notification.svg',
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                      width: responsive.heightPercent(2.8),
                                    ),
                                  ),
                                  if (countNoti > 0)
                                    Positioned(
                                      right: 3,
                                      top: 1,
                                      child: Container(
                                        width: responsive.widthPercent(4.7),
                                        height: responsive.widthPercent(4.7),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primary,
                                          border: Border.all(
                                            color: textWhite,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            countNoti > 9
                                                ? '9+'
                                                : countNoti.toString(),
                                            style: TextStyle(
                                              color: textWhite,
                                              fontSize: responsive
                                                  .heightPercent(1.1),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (canCiudadano == canFuncionario)
                            const SizedBox(
                              width: 10,
                            ),
                          if (canCiudadano == canFuncionario)
                            DropdownButtonHideUnderline(
                              child: DropdownButton2(
                                customButton: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  alignment: Alignment.center,
                                  child: SvgPicture.asset(
                                    '${assetImgIcon}change.svg',
                                    width: responsive.heightPercent(2.8),
                                    // color: textColor,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge!.color,
                                  ),
                                ),
                                items: [
                                  if (canFuncionario)
                                    DropdownMenuItem(
                                      value: 'Funcionario',
                                      child: Row(
                                        children: [
                                          SvgPicture.asset(
                                            '${assetImgIcon}cardEmployee.svg',
                                            color: Theme.of(
                                              context,
                                            ).canvasColor,
                                            width: responsive.heightPercent(
                                              2.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Funcionario',
                                            style: TextStyle(
                                              fontSize: responsive
                                                  .heightPercent(1.5),
                                              color: Theme.of(
                                                context,
                                              ).canvasColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (canCiudadano)
                                    DropdownMenuItem(
                                      value: 'Ciudadano',
                                      child: Row(
                                        children: [
                                          SvgPicture.asset(
                                            '${assetImgIcon}user_icon.svg',
                                            color: Theme.of(
                                              context,
                                            ).canvasColor,
                                            width: responsive.heightPercent(
                                              2.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Ciudadano',
                                            style: TextStyle(
                                              fontSize: responsive
                                                  .heightPercent(1.5),
                                              color: Theme.of(
                                                context,
                                              ).canvasColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  // Manejo de las opciones seleccionadas
                                  if (value == 'Funcionario') {
                                    onFuncionario!();
                                  } else if (value == 'Ciudadano') {
                                    onCiudadano!();
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
                                    thickness:
                                        MaterialStateProperty.all<double>(6),
                                    thumbVisibility:
                                        MaterialStateProperty.all<bool>(true),
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

// Widget para el appbar
class Appbar extends StatelessWidget {
  const Appbar({
    required this.perfil,
    super.key,
  });

  final String perfil;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Padding(
      padding: EdgeInsets.only(top: responsive.heightPercent(1)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleButton(
            callback: () => debugPrint('Facebook'),
            icon: FittedBox(
              fit: BoxFit.none,
              child: Image.asset(
                '${assetImgIcon}perfil.png',
                width: responsive.widthPercent(9),
              ),
            ),
            background: Colors.white,
            height: responsive.widthPercent(8.5),
            width: responsive.widthPercent(8.5),
          ),
          // le damos tamaño a este widget y con expanded hacemos q los iconos ocupen todo el tamaño y empujen el avatar a la orilla
          SizedBox(
            width: responsive.widthPercent(50),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleButton(
                        callback: () => debugPrint('Search'),
                        icon: SvgPicture.asset(
                          '${assetImgIcon}home.svg',
                          color: violet,
                          height: responsive.heightPercent(2.5),
                        ),
                        background: fondoWhite,
                        width: responsive.widthPercent(8),
                        height: responsive.widthPercent(8),
                      ),
                      Stack(
                        children: [
                          CircleButton(
                            callback: () => debugPrint('Notification'),
                            icon: SvgPicture.asset(
                              '${assetImgIcon}message.svg',
                              color: violet,
                              height: responsive.heightPercent(2.5),
                            ),
                            background: fondoWhite,
                            height: responsive.widthPercent(8),
                            width: responsive.widthPercent(8),
                          ),
                          Positioned(
                            right: 5,
                            top: 4,
                            child: Container(
                              width: responsive.heightPercent(.9),
                              height: responsive.heightPercent(.9),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xffee305e),
                              ),
                            ),
                          ),
                        ],
                      ),
                      CircleButton(
                        callback: () => debugPrint('Message'),
                        icon: SvgPicture.asset(
                          '${assetImgIcon}home.svg',
                          color: violet,
                          height: responsive.heightPercent(2.5),
                        ),
                        background: fondoWhite,
                        height: responsive.widthPercent(8),
                        width: responsive.widthPercent(8),
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
