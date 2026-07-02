// import 'package:elearningui/data/category_json.dart';

import 'package:file_cast/app/presentation/global/controllers/theme_controller.dart';
import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/complemento.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class CustomPlaceHolder extends StatefulWidget {
  const CustomPlaceHolder({
    required this.title,
    required this.icon,
    super.key,
    this.isValided = false,
    this.isSwitch = false,
    this.funcion,
    this.onSwitchChange,
    this.bgIconColor = primary,
    this.iconColor = textWhite,
    this.state = '',
    this.isVerified = false,
    this.initialSwitchValue,
    this.isLoading = false,
  });
  final String title;
  final String icon;
  final String state;
  final bool isVerified;
  final bool isSwitch;
  final bool isValided;
  final Color bgIconColor;
  final Color iconColor;
  final void Function()? funcion;
  final void Function(bool)? onSwitchChange;
  final bool? initialSwitchValue;
  final bool isLoading;

  @override
  _CustomPlaceHolderState createState() => _CustomPlaceHolderState();
}

class _CustomPlaceHolderState extends State<CustomPlaceHolder> {
  late bool switchValue;

  @override
  void initState() {
    super.initState();
    final ThemeController themeController = context.read<ThemeController>();
    switchValue = themeController.darkMode; // Inicializar con el valor guardado
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;

    final responsive = Responsive.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: widget.funcion,
      child: Container(
        width: responsive.width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  height: responsive.widthPercent(10),
                  width: responsive.widthPercent(10),
                  decoration: BoxDecoration(
                    color: widget.isValided
                        ? widget.bgIconColor
                        : Theme.of(context).primaryColor.withOpacity(.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    '$assetImgIcon${widget.icon}',
                    width: responsive.heightPercent(2.2),
                    // color: textColor,
                    color: widget.isValided
                        ? widget.iconColor
                        : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.5),
                    color: Theme.of(context).textTheme.bodySmall!.color,
                    // fontFamily: "Poppins",
                  ),
                ),
              ],
            ),
            if (widget.isLoading)
              CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
                strokeWidth: 2,
                strokeAlign: -7,
              )
            else
              (widget.isSwitch)
                  ? CupertinoSwitch(
                      value: switchValue,
                      activeColor: Theme.of(context).primaryColor,
                      thumbColor: darkMode ? colorCardDark : textWhite,
                      onChanged: (bool newValue) {
                        setState(() {
                          switchValue = newValue;
                        });
                        if (widget.onSwitchChange != null) {
                          widget.onSwitchChange!(newValue);
                        }
                      },
                    )
                  : widget.isValided
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isVerified
                            ? Theme.of(context).primaryColor.withOpacity(.1)
                            : esam.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.state,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.2),
                          color: widget.isVerified
                              ? Theme.of(context).primaryColor
                              : esam,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : InkWell(
                      onTap: widget.funcion,
                      child: Container(
                        height: responsive.widthPercent(10),
                        width: responsive.widthPercent(10),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}arrow-right.svg',
                          width: responsive.heightPercent(2.2),
                          // color: textColor,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

class CustomPlaceHolder2 extends StatefulWidget {
  const CustomPlaceHolder2({
    required this.title,
    required this.icon,
    super.key,
    this.isValided = false,
    this.isSwitch = false,
    this.funcion,
    this.onSwitchChange,
    this.onChangeActivate,
    this.bgIconColor = primary,
    this.iconColor = textWhite,
    this.state = '',
    this.isVerified = false,
    this.initialSwitchValue,
    this.initialValueActivate,
    this.subtitle,
    this.isSelectDefault = false,
    this.isLoading = false,
    this.isSelectDefecto = false,
    this.isButtonArrow = false,
    this.showVerified = true,
    this.isBlocked = false,
  });
  final String title;
  final String? subtitle;
  final String icon;
  final String state;
  final bool isVerified;
  final bool isSwitch;
  final bool isValided;
  final Color bgIconColor;
  final Color iconColor;
  final void Function()? funcion;
  final void Function(bool)? onSwitchChange;
  final void Function(bool)? onChangeActivate;
  final bool? initialSwitchValue;
  final bool? initialValueActivate;
  final bool isSelectDefault;
  final bool isSelectDefecto;
  final bool isButtonArrow;
  final bool showVerified;
  final bool isLoading;
  final bool isBlocked;

  @override
  _CustomPlaceHolder2State createState() => _CustomPlaceHolder2State();
}

class _CustomPlaceHolder2State extends State<CustomPlaceHolder2> {
  late bool switchValue;
  late bool isSelectedActivate;

  @override
  void initState() {
    super.initState();
    switchValue =
        widget.initialSwitchValue ?? false; // Inicializar con el valor guardado
    isSelectedActivate =
        widget.initialValueActivate ??
        false; // Inicializar con el valor guardado
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;

    final responsive = Responsive.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: widget.funcion,
      child: Container(
        width: responsive.width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  height: responsive.widthPercent(10),
                  width: responsive.widthPercent(10),
                  decoration: BoxDecoration(
                    color: widget.isValided
                        ? widget.bgIconColor
                        : Theme.of(context).primaryColor.withOpacity(.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    '$assetImgIcon${widget.icon}',
                    width: responsive.heightPercent(2.2),
                    // color: textColor,
                    color: widget.isValided
                        ? widget.iconColor
                        : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                if (widget.subtitle != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.subtitle!,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: responsive.heightPercent(1.3),
                            ),
                          ),
                          if (widget.isSelectDefecto)
                            Container(
                              margin: const EdgeInsets.only(left: 5),
                              padding: const EdgeInsets.symmetric(
                                vertical: 1,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isVerified
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(.1)
                                    : esam.withOpacity(.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Por defecto',
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.2),
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (widget.showVerified)
                            Container(
                              margin: const EdgeInsets.only(left: 5),
                              padding: const EdgeInsets.symmetric(
                                vertical: 1,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isVerified
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(.1)
                                    : esam.withOpacity(.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.state,
                                style: TextStyle(
                                  fontSize: responsive.heightPercent(1.2),
                                  color: widget.isVerified
                                      ? Theme.of(context).primaryColor
                                      : esam,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: responsive.heightPercent(1.5),
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall!.color,
                          // fontFamily: "Poppins",
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: responsive.heightPercent(1.5),
                      color: Theme.of(context).textTheme.bodySmall!.color,
                      // fontFamily: "Poppins",
                    ),
                  ),
              ],
            ),
            if (widget.isSwitch)
              AbsorbPointer(
                absorbing: widget.isBlocked,
                child: CupertinoSwitch(
                  value: widget.initialSwitchValue ?? false,
                  activeColor: Theme.of(context).primaryColor,
                  thumbColor: darkMode ? colorCardDark : textWhite,
                  onChanged: (bool newValue) {
                    if (widget.onSwitchChange != null) {
                      widget.onSwitchChange!(newValue);
                    }
                  },
                ),
              )
            else
              widget.isSelectDefault
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: widget.initialValueActivate ?? false,
                          onChanged: (newValue) {
                            setState(() {
                              isSelectedActivate = newValue!;
                            });
                            if (widget.onChangeActivate != null) {
                              widget.onChangeActivate!(newValue!);
                            }
                          },
                          checkColor: textWhite,
                          activeColor: Theme.of(context).primaryColor,
                          side: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ],
                    )
                  : widget.isValided
                  ? widget.isButtonArrow
                        ? widget.isLoading
                              ? CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                  strokeWidth: 2,
                                  strokeAlign: -7,
                                ) // Muestra el loader
                              : InkWell(
                                  onTap: widget.funcion,
                                  child: Container(
                                    height: responsive.widthPercent(10),
                                    width: responsive.widthPercent(10),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      '${assetImgIcon}arrow-right.svg',
                                      width: responsive.heightPercent(2.2),
                                      // color: textColor,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                )
                        : const SizedBox()
                  : widget.isLoading
                  ? CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 2,
                      strokeAlign: -7,
                    ) // Muestra el loader
                  : InkWell(
                      onTap: widget.funcion,
                      child: Container(
                        height: responsive.widthPercent(10),
                        width: responsive.widthPercent(10),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          '${assetImgIcon}arrow-right.svg',
                          width: responsive.heightPercent(2.2),
                          // color: textColor,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
