import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class CustomAppBarLinks extends StatelessWidget {
  const CustomAppBarLinks({
    super.key,
    this.title = '',
    this.action = false,
    this.viewTitle = false,
    this.actionIcon = 'logout.svg',
    this.iconColor = primary,
    this.backgroundColor = fondoWhite,
    this.brightness,
    this.funcion,
    this.colorScope = primary,
    this.isWidget = false,
    this.child,
  });

  final String title;
  final bool action;
  final bool viewTitle;
  final String actionIcon;
  final Color iconColor;
  final Color backgroundColor;
  final Color colorScope;
  final Brightness? brightness;
  final void Function()? funcion;
  final bool isWidget;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      // indicador de atras
      automaticallyImplyLeading: false,
      primary: false,
      excludeHeaderSemantics: true,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 10,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => context.pop(true),
                    child: Container(
                      height: responsive.widthPercent(10),
                      width: responsive.widthPercent(10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: colorScope),
                        borderRadius: BorderRadius.circular(10),
                        /* boxShadow: [
                          BoxShadow(
                            color: colorScope.withOpacity(0.5),
                            spreadRadius: 0.0,
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          )
                        ], */
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        '${assetImgIcon}arrow_left_icon.svg',
                        // color: textColor,
                        color: colorScope,
                        width: responsive.heightPercent(1),
                      ),
                    ),
                  ),
                  if (viewTitle)
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(2),
                          overflow: TextOverflow.ellipsis,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.color,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    const SizedBox(),
                  if (action)
                    isWidget
                        ? child ??
                              SizedBox(
                                width: responsive.widthPercent(10),
                                height: responsive.widthPercent(10),
                              )
                        : GestureDetector(
                            onTap: funcion,
                            child: Container(
                              height: responsive.widthPercent(10),
                              width: responsive.widthPercent(10),
                              decoration: BoxDecoration(
                                // color: bgActions,
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: bgActions.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                assetImgIcon + actionIcon,
                                width: responsive.heightPercent(2),
                                // color: textColor,
                                color: textWhite,
                              ),
                            ),
                          )
                  else
                    SizedBox(
                      width: responsive.widthPercent(10),
                      height: responsive.widthPercent(10),
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

class CustomAppBarLinks2 extends StatelessWidget {
  const CustomAppBarLinks2({
    super.key,
    this.title = '',
    this.action = false,
    this.actionIcon = 'filter.svg',
    this.iconColor = primary,
    this.backgroundColor = background,
    this.brightness,
    this.funcion,
  });

  final String title;
  final bool action;
  final String actionIcon;
  final Color iconColor;
  final Color backgroundColor;
  final Brightness? brightness;
  final void Function()? funcion;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // brightness: brightness,
      backgroundColor: fondoColor,
      elevation: 0,
      // indicador de atras
      automaticallyImplyLeading: false,
      primary: false,
      excludeHeaderSemantics: true,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    height: 40,
                    width: 40,
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'TiltNeon',
                    ),
                  ),
                  const Spacer(),
                  if (action)
                    InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: funcion,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          // color: bgActions,
                          color: esamPrimary,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: bgActions.withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          assetImgIcon + actionIcon,
                          width: 20,
                          // color: textColor,
                          color: textWhite,
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 40,
                      height: 40,
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
