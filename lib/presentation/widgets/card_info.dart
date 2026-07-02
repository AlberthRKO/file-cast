import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CardInfo extends StatelessWidget {
  const CardInfo({
    required this.title,
    required this.img,
    super.key,
    this.subtitle = '',
    this.heightImg,
  });

  final String title;
  final String subtitle;
  final String img;
  final double? heightImg;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Card(
      elevation: 4,
      shadowColor: primary.withOpacity(0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        width: size.width * .9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17.5),
        ),
        child: Column(
          children: [
            SizedBox(
              width: size.width,
              height: heightImg ?? size.height * .3,
              child: ClipRRect(
                child: SvgPicture.asset(
                  '$assetImg$img',
                ),
              ),
            ),
            CustomHeading(
              title: title,
              subTitle: subtitle,
              fonsizesubTitle: 12,
              centro: true,
              color: textBlack,
            ),
            const SizedBox(
              height: miniSpacer,
            ),
          ],
        ),
      ),
    );
  }
}

class CardSinResultados extends StatelessWidget {
  const CardSinResultados({
    required this.title,
    required this.img,
    super.key,
    this.subtitle = '',
    this.heightImg,
    this.background,
    this.isPadding = true,
    this.boxShadow = true,
    this.isSvg = true,
  });

  final String title;
  final String subtitle;
  final String img;
  final double? heightImg;
  final Color? background;
  final bool isPadding;
  final bool boxShadow;
  final bool isSvg;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: isPadding
          ? const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
          : EdgeInsets.zero,
      width: responsive.width * .9,
      decoration: BoxDecoration(
        color: background ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: !boxShadow
            ? []
            : [
                BoxShadow(
                  color: textBlack.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Row(
        children: [
          if (isSvg)
            SvgPicture.asset(
              img,
              width: responsive.widthPercent(22),
            )
          else
            Image.asset(
              img,
              width: responsive.widthPercent(22),
            ),
          const SizedBox(
            width: 10,
          ),
          Flexible(
            child: CustomHeading(
              title: title,
              subTitle: subtitle,
              fonsizeTitle: responsive.heightPercent(1.8),
              fonsizesubTitle: responsive.heightPercent(1.3),
              color: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
          ),
          const SizedBox(
            height: miniSpacer,
          ),
        ],
      ),
    );
  }
}

class CardSinInter extends StatelessWidget {
  const CardSinInter({
    required this.title,
    required this.subtitle,
    super.key,
    this.isImg = false,
    this.img,
    // required this.amount,
    // required this.img,
  });

  final String title;
  final String subtitle;
  final bool isImg;
  final String? img;
  // final int amount;
  // final String img;

  @override
  Widget build(BuildContext context) {
    final ConnectivyRespository connectivyRespository = context.read();
    final responsive = Responsive.of(context);
    return ColoredBox(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ajusta el tamaño al contenido
          children: [
            if (isImg)
              SvgPicture.asset(
                '$assetImgIllustration$img',
              ),
            CustomHeading(
              title: title,
              subTitle: subtitle,
              fonsizeTitle: responsive.heightPercent(2.1),
              fonsizesubTitle: responsive.heightPercent(1.4),
              centro: true,
              color: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
            const SizedBox(
              height: miniSpacer,
            ),
            ElevatedButton(
              onPressed: () async {
                final hasInternet = await connectivyRespository.hasInternet;
                if (!hasInternet) {
                  context.goNamed(Routes.offline);
                } else {
                  context.goNamed(Routes.home);
                }
              },
              child: const Text('Verificar'),
            ),
          ],
        ),
      ),
    );
  }
}

class CardMarcar extends StatelessWidget {
  const CardMarcar({
    required this.title,
    required this.img,
    required this.isButton,
    super.key,
    this.subtitle = '',
    this.heightImg,
    this.background,
    this.isPadding = true,
    this.colorButton = violet,
    this.titleButton,
    this.iconButton,
    this.funcion,
    this.isInChild = false,
  });

  final String title;
  final String subtitle;
  final String img;
  final double? heightImg;
  final Color? background;
  final bool isPadding;
  final bool isButton;
  final Color colorButton;
  final String? titleButton;
  final String? iconButton;
  final void Function()? funcion;
  final bool isInChild;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: isPadding
          ? const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
          : EdgeInsets.zero,
      width: responsive.width,
      decoration: BoxDecoration(
        color: background ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isInChild
            ? []
            : [
                BoxShadow(
                  color: textBlack.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            img,
            width: responsive.widthPercent(22),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              children: [
                CustomHeading(
                  title: title,
                  subTitle: subtitle,
                  fonsizeTitle: responsive.heightPercent(1.5),
                  fonsizesubTitle: responsive.heightPercent(1.3),
                  color: Theme.of(context).textTheme.bodyLarge!.color!,
                ),
                const SizedBox(
                  height: miniSpacer,
                ),
                if (isButton)
                  CustomButtonBoxStyle(
                    funcion: funcion,
                    title: titleButton ?? '',
                    icon: iconButton ?? '',
                    sizeHeight: responsive.widthPercent(8),
                    sizeWidth: responsive.widthPercent(30),
                    fontSize: responsive.heightPercent(1.3),
                    iconActive: true,
                    color: colorButton,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
