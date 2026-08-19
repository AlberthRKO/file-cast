import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomDropDown<T> extends StatelessWidget {
  const CustomDropDown({
    required this.lista,
    required this.onChanged,
    required this.label,
    required this.valueExtractor,
    required this.textExtractor,
    super.key,
    this.color,
    this.colorText,
    this.prefixIcon = false,
    this.prefixIconValue,
    this.validator,
    this.value,
  });

  final List<T> lista;
  final String label;
  final bool prefixIcon;
  final String? prefixIconValue;
  final Color? color;
  final Color? colorText;
  final String? Function(T?)? validator;
  final void Function(dynamic) onChanged;
  final dynamic Function(T) valueExtractor;
  final String Function(T) textExtractor;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;
    final effectiveColorText =
        colorText ?? Theme.of(context).textTheme.bodyLarge!.color!;

    return DropdownButtonFormField<T>(
      value: value,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      elevation: 0,
      iconEnabledColor: effectiveColor,
      dropdownColor: effectiveColor == Theme.of(context).primaryColor
          ? Theme.of(context).cardColor
          : Theme.of(context).primaryColor,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge!.color,
        fontSize: AppTokens.fontBody(context),
        fontFamily: 'Montserrat',
      ),
      isExpanded: true,
      validator: (value) {
        return validator == null ? null : validator!(value);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
          height: 1,
        ),
        prefixIcon: prefixIcon
            ? Container(
                width: AppDimensions.iconL,
                height: AppDimensions.iconL,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  assetImgIcon + prefixIconValue!,
                  height: AppDimensions.iconM,
                  color: effectiveColor,
                ),
              )
            : null,
        suffixIcon: prefixIcon
            ? Container(
                margin: EdgeInsets.only(right: AppDimensions.spaceS),
                width: AppDimensions.iconL,
                height: AppDimensions.iconL,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  '${assetImgIcon}arrow_down.svg',
                  height: AppDimensions.iconM,
                  color: effectiveColor,
                ),
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: primaryDark),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: primaryDark),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.grey),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: deleteColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: deleteColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
      ),

      items: lista.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            textExtractor(item),
            style: TextStyle(
              color: effectiveColorText,
              fontSize: AppTokens.fontBody(context),
              fontFamily: 'Montserrat',
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        onChanged(value == null ? null : valueExtractor(value));
      },
    );
  }
}

class CustomDropDown2<T> extends StatelessWidget {
  const CustomDropDown2({
    required this.lista,
    required this.onChanged,
    required this.label,
    required this.valueExtractor,
    super.key,
    this.color,
    this.colorText,
    this.prefixIcon = false,
    this.prefixIconValue,
    this.validator,
    this.value,
    this.itemBuilder,
    this.textExtractor,
    this.selectedItemBuilder,
  });

  final List<T> lista;
  final String label;
  final bool prefixIcon;
  final String? prefixIconValue;
  final Color? color;
  final Color? colorText;
  final String? Function(T?)? validator;
  final void Function(T?) onChanged;
  final T Function(T) valueExtractor;
  final String Function(T)? textExtractor;
  final Widget Function(T)? itemBuilder;
  final T? value;
  final Widget Function(T)? selectedItemBuilder;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;
    final effectiveColorText =
        colorText ?? Theme.of(context).textTheme.bodyLarge!.color!;

    return DropdownButtonFormField<T>(
      value: value,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      elevation: 0,
      iconEnabledColor: effectiveColor,
      dropdownColor: effectiveColor == Theme.of(context).primaryColor
          ? Theme.of(context).cardColor
          : Theme.of(context).primaryColor,
      style: TextStyle(
        fontSize: FontTokens.body(context),
        color: effectiveColor,
        fontWeight: FontWeight.w500,
        letterSpacing: .5,
      ),
      isExpanded: true,
      isDense: false,
      validator: (value) {
        return validator == null ? null : validator!(value);
      },
      decoration: InputDecoration(
        prefixIcon: prefixIcon
            ? Container(
                width: AppDimensions.iconL,
                height: AppDimensions.iconL,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  assetImgIcon + prefixIconValue!,
                  height: AppDimensions.iconM,
                  color: effectiveColor,
                ),
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(width: .8, color: effectiveColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(width: .8, color: effectiveColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceM,
        ),
        border: InputBorder.none,
      ),
      hint: Text(
        label,
        style: TextStyle(
          color: effectiveColorText.withOpacity(0.5),
          fontWeight: FontWeight.w400,
          fontSize: FontTokens.body(context),
          fontFamily: 'Montserrat',
        ),
      ),
      items: lista.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: itemBuilder != null
              ? itemBuilder!(item)
              : Text(
                  textExtractor!(item),
                  style: TextStyle(
                    color: effectiveColorText,
                    fontSize: FontTokens.body(context),
                    fontFamily: 'Montserrat',
                  ),
                ),
        );
      }).toList(),
      selectedItemBuilder: selectedItemBuilder != null
          ? (context) {
              return lista.map((item) {
                return selectedItemBuilder!(item);
              }).toList();
            }
          : null,
      onChanged: (value) {
        onChanged(value == null ? null : valueExtractor(value));
      },
      icon: Row(
        children: [
          Container(
            width: 2,
            height: AppDimensions.iconM,
            color: effectiveColor.withOpacity(.3),
          ),
          SizedBox(width: AppDimensions.spaceS),
          SvgPicture.asset(
            '${assetImgIcon}arrow_down.svg',
            width: AppDimensions.iconM,
            height: AppDimensions.iconM,
            color: effectiveColor,
          ),
        ],
      ),
    );
  }
}

class CustomDropDown3<T> extends StatelessWidget {
  const CustomDropDown3({
    required this.lista,
    required this.onChanged,
    required this.label,
    required this.valueExtractor,
    required this.textExtractor,
    super.key,
    this.color,
    this.colorText,
    this.prefixIcon = false,
    this.prefixIconValue,
    this.validator,
    this.value,
  });

  final List<T> lista;
  final String label;
  final bool prefixIcon;
  final String? prefixIconValue;
  final Color? color;
  final Color? colorText;
  final String? Function(String?)? validator;
  final void Function(dynamic) onChanged;
  final dynamic Function(T) valueExtractor;
  final String Function(T) textExtractor;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;
    final effectiveColorText =
        colorText ?? Theme.of(context).textTheme.bodyLarge!.color!;

    return DropdownButtonFormField<T>(
      value: value,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      elevation: 2,
      iconEnabledColor: effectiveColor,
      dropdownColor: effectiveColor == Colors.white
          ? Colors.white
          : Theme.of(context).primaryColor,
      style: TextStyle(
        fontSize: FontTokens.caption(context),
        color: effectiveColor,
        fontWeight: FontWeight.w500,
        letterSpacing: .5,
      ),
      isExpanded: true,
      isDense: false,
      validator: (value) {
        return validator == null ? null : validator!(value! as String);
      },
      decoration: InputDecoration(
        prefixIcon: prefixIcon
            ? Container(
                height: AppDimensions.inputHeight,
                width: AppDimensions.iconL,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  assetImgIcon + prefixIconValue!,
                  height: AppDimensions.iconM,
                  color: effectiveColorText,
                ),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(width: .8, color: effectiveColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(width: .8, color: effectiveColor),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceM,
        ),
        border: InputBorder.none,
      ),
      hint: Text(
        label,
        style: TextStyle(
          color: effectiveColorText.withOpacity(0.5),
          fontWeight: FontWeight.w400,
          fontSize: FontTokens.body(context),
          fontFamily: 'Montserrat',
        ),
      ),
      items: lista.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            textExtractor(item),
            style: TextStyle(
              color: effectiveColor,
              fontFamily: 'Montserrat',
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        onChanged(value == null ? null : valueExtractor(value));
      },
      icon: Row(
        children: [
          Container(
            width: 2,
            height: AppDimensions.iconM,
            color: effectiveColor.withOpacity(.3),
          ),
          SizedBox(width: AppDimensions.spaceS),
          SvgPicture.asset(
            '${assetImgIcon}arrow-down.svg',
            width: AppDimensions.iconS,
            height: AppDimensions.iconS,
            color: effectiveColor,
          ),
        ],
      ),
    );
  }
}
