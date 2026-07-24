import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class StartedPage extends StatelessWidget {
  const StartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = DeviceInfo.of(context).isLandscape;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final folderHeight = height * 0.12;

          return Stack(
            children: [
              Positioned(
                bottom: folderHeight * 3.2,
                child: SvgPicture.asset(
                  '${assetImgIcon}folder.svg',
                  width: 1.01.sw,
                  color: folder4,
                ),
              ),
              Positioned(
                bottom: folderHeight * 2.3,
                child: SvgPicture.asset(
                  '${assetImgIcon}folder.svg',
                  width: 1.01.sw,
                  color: folder3,
                ),
              ),
              Positioned(
                bottom: folderHeight * 1.4,
                child: SvgPicture.asset(
                  '${assetImgIcon}folder.svg',
                  width: 1.01.sw,
                  color: folder2,
                ),
              ),
              Positioned(
                bottom: folderHeight * 0.5,
                child: Hero(
                  tag: 'folder-transition',
                  child: SvgPicture.asset(
                    '${assetImgIcon}folder.svg',
                    width: 1.01.sw,
                    color: folder1,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: 1.sw,
                  height: folderHeight,
                  color: folder1,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg(context),
                    vertical: AppTokens.spaceLg(context),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Config.appName,
                        style: TextStyle(
                          fontSize: AppTokens.fontTitle(context),
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
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
                            fonsizeTitle: AppTokens.fontTitle(context),
                            fonsizesubTitle: AppTokens.fontCaption(context),
                            fontWeight: FontWeight.w700,
                            color: textWhite,
                          ),
                          SizedBox(height: AppTokens.spaceMd(context)),
                          Row(
                            mainAxisAlignment: isLandscape
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.end,
                            children: [
                              CustomButtonBoxStyle(
                                funcion: () {
                                  context.pushNamed(Routes.login);
                                },
                                fontSize: AppTokens.fontBody(context),
                                icon: 'paper.svg',
                                sizeHeight: isLandscape
                                    ? 30.h
                                    : AppTokens.buttonHeightMd(context),
                                sizeWidth: isLandscape ? 0.3.sw : 0.50.sw,
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
              ),
            ],
          );
        },
      ),
    );
  }
}
