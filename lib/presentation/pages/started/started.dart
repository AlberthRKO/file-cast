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
    final device = DeviceInfo.of(context);

    return Scaffold(
      body: device.isLandscape
          ? _buildLandscape(context, device)
          : _buildPortrait(context, device),
    );
  }

  Widget _buildPortrait(BuildContext context, DeviceInfo device) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final folderHeight = height * 0.12;

        return Stack(
          children: [
            _buildFolders(folderHeight),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceL,
                  vertical: AppDimensions.spaceL,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Config.appName,
                      style: TextStyle(
                        fontSize: FontTokens.title(context),
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
                          fonsizeTitle: FontTokens.title(context),
                          fonsizesubTitle: FontTokens.caption(context),
                          fontWeight: FontWeight.w700,
                          color: textWhite,
                        ),
                        SizedBox(height: AppDimensions.spaceM),
                        Align(
                          alignment: Alignment.centerRight,
                          child: CustomButtonBoxStyle(
                            funcion: () {
                              context.pushNamed(Routes.login);
                            },
                            fontSize: FontTokens.body(context),
                            icon: 'paper.svg',
                            sizeHeight: ComponentTokens.buttonHeight(context),
                            sizeWidth: 0.50.sw,
                            iconActive: true,
                            isShadow: true,
                            titleColor: textColor,
                            color: textWhite,
                            title: 'Empezar',
                          ),
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
    );
  }

  Widget _buildLandscape(BuildContext context, DeviceInfo device) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final folderHeight = height * 0.12;

        return Stack(
          children: [
            _buildFolders(folderHeight),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceL,
                  vertical: AppDimensions.spaceM,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Config.appName,
                            style: TextStyle(
                              fontSize: FontTokens.title(context),
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                          SizedBox(height: AppDimensions.spaceS),
                          CustomHeading(
                            title:
                                'La forma más fácil de registrar evidencias',
                            subTitle:
                                'Registra y monitorea las evidencias que obtienes',
                            color2: Theme.of(context).hintColor,
                            fontWeightSubtitle: FontWeight.w600,
                            fonsizeTitle: FontTokens.title(context),
                            fonsizesubTitle: FontTokens.caption(context),
                            fontWeight: FontWeight.w700,
                            color: textWhite,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppDimensions.spaceL),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CustomButtonBoxStyle(
                            funcion: () {
                              context.pushNamed(Routes.login);
                            },
                            fontSize: FontTokens.body(context),
                            icon: 'paper.svg',
                            sizeHeight: ComponentTokens.buttonHeight(context),
                            sizeWidth: 0.5.sw,
                            iconActive: true,
                            isShadow: true,
                            titleColor: textColor,
                            color: textWhite,
                            title: 'Empezar',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFolders(double folderHeight) {
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
      ],
    );
  }
}
