import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomDropDown<T> extends StatelessWidget {
  const CustomDropDown({
    required this.lista,
    required this.onChanged,
    required this.label,
    required this.valueExtractor,
    required this.textExtractor,
    super.key,
    this.color = primary,
    this.colorText = textBlack,
    this.prefixIcon = false,
    this.prefixIconValue,
    this.validator,
    this.value,
  });

  final List<T> lista;
  final String label;
  final bool prefixIcon;
  final String? prefixIconValue;
  final Color color;
  final Color colorText;
  final String? Function(T?)? validator;
  final void Function(dynamic) onChanged;
  final dynamic Function(T) valueExtractor;
  final String Function(T) textExtractor;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return DropdownButtonFormField<T>(
      value: value,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      iconEnabledColor: color,
      dropdownColor: color == Theme.of(context).primaryColor
          ? Theme.of(context).cardColor
          : Theme.of(context).primaryColor,
      style: TextStyle(
        fontSize: responsive.heightPercent(1.2),
        color: color,
        fontWeight: FontWeight.w500,
        letterSpacing: .5,
      ),
      isExpanded: true,
      isDense: false,
      validator: (value) {
        return validator == null
            ? null
            : validator!(value); // Corrección: pasa 'value' directamente
      },
      decoration: InputDecoration(
        prefixIcon: prefixIcon
            ? Container(
                width: responsive.widthPercent(8),
                height: responsive.widthPercent(8),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  assetImgIcon + prefixIconValue!,
                  height: responsive.heightPercent(2.2),
                  color: color,
                ),
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(width: .8, color: color),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(width: .8, color: color),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(15),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(15),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        border: InputBorder.none,
      ),
      hint: Text(
        label,
        style: TextStyle(
          color: colorText.withOpacity(0.5),
          fontWeight: FontWeight.w400,
          fontSize: responsive.heightPercent(1.4),
          fontFamily: 'Poppins',
        ),
      ),
      items: lista.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            textExtractor(item),
            style: TextStyle(
              color: colorText,
              fontSize: responsive.heightPercent(1.4),
              fontFamily: 'Poppins',
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
            height: 20,
            color: color.withOpacity(.3),
          ),
          const SizedBox(
            width: 10,
          ),
          SvgPicture.asset(
            '${assetImgIcon}arrow_down.svg',
            width: responsive.heightPercent(2),
            height: responsive.heightPercent(2),
            color: color,
          ),
        ],
      ),
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
    this.color = primary,
    this.colorText = textBlack,
    this.prefixIcon = false,
    this.prefixIconValue,
    this.validator,
    this.value,
    this.itemBuilder, // Nuevo parámetro para construir widgets personalizados
    this.textExtractor, // Ahora es opcional si se usa itemBuilder
    this.selectedItemBuilder, // NUEVO: Para el item seleccionado
  });

  final List<T> lista;
  final String label;
  final bool prefixIcon;
  final String? prefixIconValue;
  final Color color;
  final Color colorText;
  final String? Function(T?)? validator;
  final void Function(dynamic) onChanged;
  final dynamic Function(T) valueExtractor;
  final String Function(T)? textExtractor; // Ahora es opcional
  final Widget Function(T)? itemBuilder; // Nuevo constructor de items
  final T? value;
  final Widget Function(T)? selectedItemBuilder; // NUEVO parámetro

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return DropdownButtonFormField<T>(
      value: value,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      iconEnabledColor: color,
      dropdownColor: color == Theme.of(context).primaryColor
          ? Theme.of(context).cardColor
          : Theme.of(context).primaryColor,
      style: TextStyle(
        fontSize: responsive.heightPercent(1.2),
        color: color,
        fontWeight: FontWeight.w500,
        letterSpacing: .5,
      ),
      isExpanded: true,
      isDense: false,
      validator: (value) {
        return validator == null
            ? null
            : validator!(value); // Corrección: pasa 'value' directamente
      },
      decoration: InputDecoration(
        prefixIcon: prefixIcon
            ? Container(
                width: responsive.widthPercent(8),
                height: responsive.widthPercent(8),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  assetImgIcon + prefixIconValue!,
                  height: responsive.heightPercent(2.2),
                  color: color,
                ),
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(width: .8, color: color),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(width: .8, color: color),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(15),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(15),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        border: InputBorder.none,
      ),
      hint: Text(
        label,
        style: TextStyle(
          color: colorText.withOpacity(0.5),
          fontWeight: FontWeight.w400,
          fontSize: responsive.heightPercent(1.4),
          fontFamily: 'Poppins',
        ),
      ),
      items: lista.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: itemBuilder != null
              ? itemBuilder!(item) // Usa el widget personalizado
              : Text(
                  // Mantiene compatibilidad con el método antiguo
                  textExtractor!(item),
                  style: TextStyle(
                    color: colorText,
                    fontSize: responsive.heightPercent(1.4),
                    fontFamily: 'Poppins',
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
            height: 20,
            color: color.withOpacity(.3),
          ),
          const SizedBox(width: 10),
          SvgPicture.asset(
            '${assetImgIcon}arrow_down.svg',
            width: responsive.heightPercent(2),
            height: responsive.heightPercent(2),
            color: color,
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
    this.color = Colors.red,
    this.colorText = Colors.blue,
    this.prefixIcon = false,
    this.prefixIconValue,
    this.validator,
    this.value,
  });

  final List<T> lista;
  final String label;
  final bool prefixIcon;
  final String? prefixIconValue;
  final Color color;
  final Color colorText;
  final String? Function(String?)? validator;
  final void Function(dynamic) onChanged;
  final dynamic Function(T) valueExtractor;
  final String Function(T) textExtractor;
  final T? value;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      iconEnabledColor: color,
      dropdownColor: color == Colors.white ? Colors.white : Colors.blue,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
        letterSpacing: .5,
      ),
      isExpanded: true,
      isDense: false,
      validator: (value) {
        return validator == null
            ? null
            : validator!(
                value! as String,
              ); // Corrección: pasa 'value' directamente
      },
      decoration: InputDecoration(
        label: Text(
          label,
          style: TextStyle(
            color: colorText.withOpacity(0.5),
            fontWeight: FontWeight.w400,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        prefixIcon: prefixIcon
            ? Container(
                height: 50,
                width: 40,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  assetImgIcon + prefixIconValue!,
                  height: 20,
                  color: colorText,
                ),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(width: .8, color: color),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(width: .8, color: color),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(15),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: .8, color: Colors.red),
          borderRadius: BorderRadius.circular(15),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        border: InputBorder.none,
      ),
      /*hint: Text(
        label,
        style: TextStyle(
          color: colorText.withOpacity(0.5),
          fontWeight: FontWeight.w400,
          fontSize: 14.0,
          fontFamily: "Poppins",
        ),
      ),*/
      items: lista.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            textExtractor(item),
            style: TextStyle(
              color: color,
              fontFamily: 'Poppins',
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
            height: 20,
            color: color.withOpacity(.3),
          ),
          const SizedBox(
            width: 10,
          ),
          SvgPicture.asset(
            '${assetImgIcon}arrow-down.svg',
            width: 15,
            height: 15,
            color: color,
          ),
        ],
      ),
    );
  }
}
