import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/data/models/user_model.dart';
import 'package:file_cast/domain/typedef.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/circle_button.dart';
import 'package:file_cast/presentation/widgets/custom_avatar.dart';
import 'package:file_cast/presentation/widgets/custom_drop_down.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:file_cast/presentation/widgets/text_form_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class CustomAppbar extends StatelessWidget {
  const CustomAppbar({
    required this.user,
    super.key,
    this.isCurved = false,
    this.countNoti = 0,
  });

  final bool isCurved;
  final UserModel user;

  final int countNoti;
  @override
  Widget build(BuildContext context) {
    final List<ValueType> listEstado = [
      ValueType(id: 10, value: 'Todos'),
      ValueType(id: 0, value: 'Inactivo'),
      ValueType(id: 1, value: 'Solicitud'),
      ValueType(id: 2, value: 'Aprobado Jefe'),
      ValueType(id: 3, value: 'Observado'),
      ValueType(id: 4, value: 'Aprobado RRHH'),
      ValueType(id: 5, value: 'Rechazado'),
      ValueType(id: 6, value: 'Editado'),
      ValueType(id: 7, value: 'Anulado'),
    ];
    final responsive = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(
          bottom: isCurved
              ? const Radius.circular(25)
              : const Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Column(
            children: [
              const SizedBox(
                height: 60,
              ),
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
                            title: 'C.I. 14258827,',
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
                  const SizedBox(
                    width: 5,
                  ),
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
                                  countNoti > 9 ? '9+' : countNoti.toString(),
                                  style: TextStyle(
                                    color: textWhite,
                                    fontSize: responsive.heightPercent(
                                      1.1,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextFieldSearch(
                        prefixIcon: 'file.svg',
                        labelText: 'Buscar Actividad (descripción)',
                        iconHeight: responsive.heightPercent(2.4),
                        iconColor: Theme.of(context).primaryColor,
                        onChanged: (text) {},
                        filterMore: true,
                        onTapFilterMore: () async {},
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              CustomDropDown<ValueType>(
                color: Theme.of(context).primaryColor,
                colorText: Theme.of(context).textTheme.bodyLarge!.color,
                prefixIcon: true,
                prefixIconValue: 'estado.svg',
                lista: listEstado, // Usar la lista dinámica
                valueExtractor: (item) => item,
                textExtractor: (item) => item.value.toString(),
                label: 'Estado',
                onChanged: (value) {
                  if (value != null) {
                    print('Estado seleccionado: ${value.value}');
                  }
                },
              ),
              const SizedBox(
                height: 20,
              ),
            ],
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
