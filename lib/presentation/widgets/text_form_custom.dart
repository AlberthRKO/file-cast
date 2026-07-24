import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

class TextFormCustom extends StatefulWidget {
  const TextFormCustom({
    required this.prefixIcon,
    required this.labelText,
    required this.onChanged,
    super.key,
    this.controller,
    this.readOnlyField = false,
    this.isPassword = false,
    this.iconHeight = 20.0,
    this.maxLine = 1,
    this.height = 50.0,
    this.keyboardType,
    this.iconColor = primary,
    this.onChageFunction,
    this.validator,
    this.valor,
    this.inputFormatters,
    this.isNumber,
    this.isEmail,
    this.maxLength,
    this.blockedViewPass = false,
    this.enabled = true,
    this.isActionField = false,
    this.isActionFieldVerification = 0,
    this.onActionField,
  });

  final void Function(String) onChanged;
  final String? Function(String?)? validator;
  final String prefixIcon;
  final String? valor;
  final double iconHeight;
  final String labelText;
  final TextEditingController? controller;
  final bool isPassword;
  final bool readOnlyField;
  final int maxLine;
  final double height;
  final TextInputType? keyboardType;
  final Color? iconColor;
  final dynamic onChageFunction;
  final List<TextInputFormatter>? inputFormatters;
  final bool? isNumber;
  final bool? isEmail;
  final int? maxLength;
  final bool blockedViewPass;
  final bool? enabled;
  final bool isActionField;
  final int isActionFieldVerification;
  final void Function()? onActionField;
  @override
  State<TextFormCustom> createState() => _TextFormCustomState();
}

class _TextFormCustomState extends State<TextFormCustom> {
  bool _isViewPass = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      onChanged: (text) {
        widget.onChanged(text);
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: widget.isNumber ?? false
          ? TextInputType.number
          : widget.isEmail ?? false
          ? TextInputType.emailAddress
          : widget.isNumber == false
          ? const TextInputType.numberWithOptions(decimal: true)
          : widget.keyboardType,
      inputFormatters: widget.isNumber ?? false
          ? <TextInputFormatter>[
              FilteringTextInputFormatter
                  .digitsOnly, // Acepta únicamente dígitos
            ]
          : widget.isEmail ?? false
          ? []
          : widget.isNumber == false
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ]
          : widget.inputFormatters,
      readOnly: widget.readOnlyField,
      obscureText: widget.isPassword && (widget.blockedViewPass || _isViewPass),
      controller: widget.controller,
      initialValue: widget.valor,
      maxLines: widget.maxLine == 0 ? null : widget.maxLine,
      style: TextStyle(
        fontSize: AppTokens.fontBody(context),
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      cursorColor: Theme.of(context).textTheme.bodyLarge!.color,
      decoration: InputDecoration(
        prefixIcon: Container(
          height: 37.5.w,
          width: 37.5.w,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            assetImgIcon + widget.prefixIcon,
            height: widget.iconHeight.r,
            color: widget.iconColor,
          ),
        ),
        labelText: widget.labelText,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
          height: 1,
        ),
        suffixIcon: widget.isPassword
            ? (widget.blockedViewPass ? null : _togglePass())
            : (widget.isActionField ? _actionVerification() : null),
        errorMaxLines: 2,
      ),
      validator: (text) {
        return widget.validator == null ? null : widget.validator!(text);
      },
    );
  }

  Widget _togglePass() {
    return InkWell(
      onTap: () {
        setState(() {
          _isViewPass = !_isViewPass;
        });
      },
      child: Container(
        height: 45.w,
        width: 45.w,
        alignment: Alignment.center,
        child: SvgPicture.asset(
          _isViewPass
              ? '${assetImgIcon}eye.svg'
              : '${assetImgIcon}eyeClose.svg',
          height: widget.iconHeight.r,
          color: Theme.of(context).primaryColor.withOpacity(.7),
        ),
      ),
    );
  }

  Widget _actionVerification() {
    return InkWell(
      onTap: widget.onActionField,
      child: Container(
        height: 45.w,
        width: 45.w,
        alignment: Alignment.center,
        child: widget.isActionFieldVerification == 2
            ? Padding(
                padding: const EdgeInsets.all(15),
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                  strokeWidth: 2,
                ),
              )
            : SvgPicture.asset(
                widget.isActionFieldVerification == 1
                    ? '${assetImgIcon}check.svg'
                    : '${assetImgIcon}verificaciones.svg',
                height: AppDimensions.iconM,
                color: Theme.of(context).primaryColor,
              ),
      ),
    );
  }
}

class SwitchCustom extends StatefulWidget {
  const SwitchCustom({
    required this.text,
    required this.onChanged,
    super.key,
    this.valor = false,
  });

  final String text;
  final bool valor;
  final void Function(bool) onChanged;

  @override
  State<SwitchCustom> createState() => _SwitchCustomState();
}

class _SwitchCustomState extends State<SwitchCustom> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.text,
          style: TextStyle(
            color: secondary.withOpacity(0.5),
            fontSize: 12.sp,
          ),
        ),
        Switch(
          activeColor: primary,
          value: widget.valor,
          onChanged: (value) {
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}

class SwitchCustom2 extends StatefulWidget {
  const SwitchCustom2({
    required this.text,
    required this.onChanged,
    super.key,
    this.valor = false,
  });

  final String text;
  final bool valor;
  final void Function(bool) onChanged;

  @override
  State<SwitchCustom2> createState() => _SwitchCustom2State();
}

class _SwitchCustom2State extends State<SwitchCustom2> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              widget.text,
              style: TextStyle(
                color: secondary.withOpacity(0.5),
                fontSize: 12.sp,
              ),
            ),
            Switch(
              activeColor: primary,
              value: widget.valor,
              onChanged: (value) {
                widget.onChanged(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}

// Field para buscar
class TextFieldSearch extends StatelessWidget {
  const TextFieldSearch({
    required this.prefixIcon,
    required this.labelText,
    required this.onChanged,
    super.key,
    this.controller,
    this.readOnlyField = false,
    this.isPassword = false,
    this.iconHeight = 17.0,
    this.maxLine = 1,
    this.height = 50.0,
    this.keyboardType,
    this.iconColor = textWhite,
    this.onChageFunction,
    this.validator,
    this.valor,
    this.inputFormatters,
    this.isNumber,
    this.filterMore = false,
    this.filterActive = false,
    this.onTapFilterMore,
    this.onFieldSubmitted,
  });

  final void Function(String) onChanged;
  final String? Function(String?)? validator;
  final void Function()? onTapFilterMore;
  final void Function()? onFieldSubmitted;

  final String prefixIcon;
  final String? valor;
  final double iconHeight;
  final String labelText;
  final TextEditingController? controller;
  final bool isPassword;
  final bool readOnlyField;
  final int maxLine;
  final double height;
  final TextInputType? keyboardType;
  final Color? iconColor;
  final dynamic onChageFunction;
  final List<TextInputFormatter>? inputFormatters;
  final bool? isNumber;
  final bool filterMore;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: (value) {
        onFieldSubmitted!();
        print(value);
      },
      readOnly: readOnlyField,
      initialValue: valor ?? '',
      style: TextStyle(
        fontSize: AppTokens.fontBody(context),
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      cursorColor: Theme.of(context).textTheme.bodyLarge!.color,
      decoration: InputDecoration(
        prefixIcon: Container(
          height: 37.5.w,
          width: 37.5.w,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            assetImgIcon + prefixIcon,
            height: iconHeight.r,
            color: iconColor,
          ),
        ),
        border: InputBorder.none,
        labelText: labelText,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
        ),
        suffixIcon: filterMore
            ? InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: onTapFilterMore,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 45.w,
                  height: 45.w,
                  decoration: BoxDecoration(
                    color: filterActive
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withOpacity(0.15),
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    '${assetImgIcon}filterMore.svg',
                    width: 20.r,
                    color: filterActive
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /* Widget togglePass() {
    return IconButton(
      onPressed: () {
      },
      icon: _isViewPass ? Icon(Icons.visibility) : Icon(Icons.visibility_off),
      color: primary.withOpacity(.5),
      iconSize: 20,
    );
  } */
}

class TextFormCustomCard extends StatefulWidget {
  const TextFormCustomCard({
    required this.labelText,
    required this.onChanged,
    super.key,
    this.controller,
  });

  final void Function(String) onChanged;
  final String labelText;
  final TextEditingController? controller;
  @override
  State<TextFormCustomCard> createState() => _TextFormCustomCardState();
}

class _TextFormCustomCardState extends State<TextFormCustomCard> {
  bool _isViewPass = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: const InputDecoration(labelText: 'Ingrese un número'),
    );
  }

  Widget togglePass() {
    return IconButton(
      onPressed: () {
        setState(() {
          _isViewPass = !_isViewPass;
        });
      },
      icon: _isViewPass
          ? const Icon(Icons.visibility)
          : const Icon(Icons.visibility_off),
      color: primary.withOpacity(.5),
      iconSize: 20,
    );
  }
}

class DatePickerFormCustom extends StatefulWidget {
  const DatePickerFormCustom({
    required this.prefixIcon,
    required this.labelText,
    required this.onChanged,
    super.key,
    this.controller,
    this.iconHeight = 20.0,
    this.height = 50.0,
    this.iconColor = primary,
    this.validator,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.isFormateado = true,
  });

  final void Function(String) onChanged;
  final String? Function(String?)? validator;
  final String prefixIcon;
  final double iconHeight;
  final String labelText;
  final TextEditingController? controller;
  final double height;
  final Color? iconColor;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final bool isFormateado;

  @override
  State<DatePickerFormCustom> createState() => _DatePickerFormCustomState();
}

class _DatePickerFormCustomState extends State<DatePickerFormCustom> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialDate != null) {
      _controller.text = _formatDate(widget.initialDate!);
    }
  }

  @override
  void didUpdateWidget(covariant DatePickerFormCustom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
      setState(() {
        if (widget.initialDate != null) {
          _controller.text = _formatDate(widget.initialDate!);
          _formatDateForSaving(widget.initialDate!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      controller: _controller,
      readOnly: true,
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime defaultStartDate = DateTime(
          now.year - 10,
        ); // Ajusta el año según lo que necesites

        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: widget.initialDate ?? now,
          firstDate: widget.firstDate ?? defaultStartDate,
          lastDate: widget.lastDate ?? now,
        );
        if (pickedDate != null) {
          _controller.text = _formatDate(pickedDate);
          widget.onChanged(_formatDateForSaving(pickedDate));
        }
      },
      style: TextStyle(
        fontSize: AppTokens.fontBody(context),
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      decoration: InputDecoration(
        prefixIcon: Container(
          height: 37.5.w,
          width: 37.5.w,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            assetImgIcon + widget.prefixIcon,
            height: widget.iconHeight.r,
            color: widget.iconColor,
          ),
        ),
        labelText: widget.labelText,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
          height: 1,
        ),
      ),
      validator: widget.validator,
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDateForSaving(DateTime selectedDate) {
    if (widget.isFormateado) {
      return DateFormat('yyyy-MM-dd').format(selectedDate);
    } else {
      // Combinar la fecha seleccionada con la hora actual
      final currentTime = DateTime.now();
      final dateTimeWithCurrentTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        currentTime.hour,
        currentTime.minute,
        currentTime.second,
        currentTime.millisecond,
      );

      // Formatear para que sea consistente
      return DateFormat(
        'yyyy-MM-dd HH:mm:ss.SSS',
      ).format(dateTimeWithCurrentTime);
    }
  }
}

class TimePickerFormCustom extends StatefulWidget {
  const TimePickerFormCustom({
    required this.prefixIcon,
    required this.labelText,
    required this.onChanged,
    super.key,
    this.controller,
    this.iconHeight = 20.0,
    this.height = 50.0,
    this.iconColor,
    this.validator,
    this.initialTime,
    this.enabled = true,
  });

  final void Function(String) onChanged;
  final String? Function(String?)? validator;
  final String prefixIcon;
  final double iconHeight;
  final String labelText;
  final TextEditingController? controller;
  final double height;
  final Color? iconColor;
  final TimeOfDay? initialTime;
  final bool enabled;

  @override
  State<TimePickerFormCustom> createState() => _TimePickerFormCustomState();
}

class _TimePickerFormCustomState extends State<TimePickerFormCustom> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialTime != null) {
      _controller.text = _formatTime(widget.initialTime!);
    }
  }

  @override
  void didUpdateWidget(covariant TimePickerFormCustom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
      setState(() {
        if (widget.initialTime != null) {
          _controller.text = _formatTime(widget.initialTime!);
          _formatTimeForSaving(widget.initialTime!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      controller: _controller,
      readOnly: true,
      onTap: () async {
        final TimeOfDay now = TimeOfDay.now();
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: widget.initialTime ?? now,
        );
        if (pickedTime != null) {
          _controller.text = _formatTime(pickedTime);
          widget.onChanged(_formatTimeForSaving(pickedTime));
        }
      },
      style: TextStyle(
        fontSize: AppTokens.fontBody(context),
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      decoration: InputDecoration(
        prefixIcon: Container(
          height: 37.5.w,
          width: 37.5.w,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            assetImgIcon + widget.prefixIcon,
            height: widget.iconHeight.r,
            color: widget.iconColor,
          ),
        ),
        labelText: widget.labelText,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
          height: 1,
        ),
      ),
      validator: widget.validator,
    );
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return DateFormat('hh:mm a').format(dateTime);
  }

  String _formatTimeForSaving(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class NumberRangePicker extends StatefulWidget {
  const NumberRangePicker({
    required this.labelText,
    required this.onChanged,
    super.key,
    this.initialValue = 10,
    this.step = 10,
    this.minValue = 0, // Nuevo parámetro minValue
    this.maxValue = 100,
    this.iconHeight = 20.0,
    this.height = 50.0,
    this.iconColor,
    this.validator,
    this.enabled = true,
  });

  final void Function(int) onChanged;
  final String? Function(String?)? validator;
  final String labelText;
  final int initialValue;
  final int step;
  final int minValue; // Nuevo parámetro minValue
  final int maxValue;
  final double iconHeight;
  final double height;
  final Color? iconColor;
  final bool enabled;

  @override
  State<NumberRangePicker> createState() => _NumberRangePickerState();
}

class _NumberRangePickerState extends State<NumberRangePicker> {
  late TextEditingController _controller;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(text: _currentValue.toString());
  }

  @override
  void didUpdateWidget(covariant NumberRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentValue = widget.initialValue;
          _controller.text = _currentValue.toString();
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      controller: _controller,
      readOnly: true,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: AppTokens.fontBody(context),
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      decoration: InputDecoration(
        prefixIcon: GestureDetector(
          onTap: () {
            setState(() {
              _currentValue = (_currentValue - widget.step).clamp(
                widget.minValue,
                widget.maxValue,
              ); // Usar minValue aquí
              _controller.text = _currentValue.toString();
              widget.onChanged(_currentValue);
            });
          },
          child: Container(
            height: 37.5.w,
            width: 37.5.w,
            alignment: Alignment.center,
            child: SvgPicture.asset(
              '${assetImgIcon}arrow-left.svg',
              width: 20.r,
              color: widget.iconColor,
            ),
          ),
        ),
        suffixIcon: GestureDetector(
          onTap: () {
            setState(() {
              _currentValue = (_currentValue + widget.step).clamp(
                widget.minValue,
                widget.maxValue,
              ); // Usar minValue aquí
              _controller.text = _currentValue.toString();
              widget.onChanged(_currentValue);
            });
          },
          child: Container(
            height: 37.5.w,
            width: 37.5.w,
            alignment: Alignment.center,
            child: SvgPicture.asset(
              '${assetImgIcon}arrow-right.svg',
              width: 20.r,
              color: widget.iconColor,
            ),
          ),
        ),
        floatingLabelAlignment: FloatingLabelAlignment.center,
        labelText: widget.labelText,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
          height: 1,
        ),
      ),
      validator: widget.validator,
    );
  }
}

class NumberRangePicker2 extends StatefulWidget {
  const NumberRangePicker2({
    required this.labelText,
    required this.onChanged,
    super.key,
    this.initialValue = 10,
    this.step = 10,
    this.minValue = 0, // Nuevo parámetro minValue
    this.maxValue = 100,
    this.iconHeight = 20.0,
    this.height = 50.0,
    this.iconColor,
    this.validator,
    this.enabled = true,
  });

  final void Function(int) onChanged;
  final String? Function(String?)? validator;
  final String labelText;
  final int initialValue;
  final int step;
  final int minValue; // Nuevo parámetro minValue
  final int maxValue;
  final double iconHeight;
  final double height;
  final Color? iconColor;
  final bool enabled;

  @override
  State<NumberRangePicker2> createState() => _NumberRangePicker2State();
}

class _NumberRangePicker2State extends State<NumberRangePicker2> {
  late TextEditingController _controller;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(text: _currentValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: TextFormField(
        onChanged: (value) {
          setState(() {
            _currentValue = int.tryParse(value) ?? widget.initialValue;
            widget.onChanged(_currentValue);
          });
        },
        enabled: widget.enabled,
        controller: _controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: AppTokens.fontBody(context),
          color: Theme.of(context).textTheme.bodyLarge!.color,
        ),
        decoration: InputDecoration(
          isDense: true,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          border: InputBorder.none,
          prefixIcon: GestureDetector(
            onTap: () {
              setState(() {
                _currentValue = (_currentValue - widget.step).clamp(
                  widget.minValue,
                  widget.maxValue,
                ); // Usar minValue aquí
                _controller.text = _currentValue.toString();
                widget.onChanged(_currentValue);
              });
            },
            child: Container(
              height: 37.5.w,
              width: 37.5.w,
              alignment: Alignment.center,
              child: SvgPicture.asset(
                '${assetImgIcon}arrow-left.svg',
                width: 20.r,
                color: widget.iconColor,
              ),
            ),
          ),
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() {
                _currentValue = (_currentValue + widget.step).clamp(
                  widget.minValue,
                  widget.maxValue,
                ); // Usar minValue aquí
                _controller.text = _currentValue.toString();
                widget.onChanged(_currentValue);
              });
            },
            child: Container(
              height: 37.5.w,
              width: 37.5.w,
              alignment: Alignment.center,
              child: SvgPicture.asset(
                '${assetImgIcon}arrow-right.svg',
                width: 20.r,
                color: widget.iconColor,
              ),
            ),
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}

class DateRangePickerFormCustom extends StatefulWidget {
  const DateRangePickerFormCustom({
    required this.prefixIcon,
    required this.labelText,
    required this.onChanged,
    super.key,
    this.controller,
    this.iconHeight = 20.0,
    this.height = 50.0,
    this.iconColor = primary,
    this.validator,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final void Function(String?) onChanged;
  final String? Function(String?)? validator;
  final String prefixIcon;
  final double iconHeight;
  final String labelText;
  final TextEditingController? controller;
  final double height;
  final Color? iconColor;
  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  State<DateRangePickerFormCustom> createState() =>
      _DateRangePickerFormCustomState();
}

class _DateRangePickerFormCustomState extends State<DateRangePickerFormCustom> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialDateRange != null) {
      _controller.text = _formatDateRange(widget.initialDateRange!);
    }
  }

  @override
  void didUpdateWidget(covariant DateRangePickerFormCustom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
      setState(() {
        if (widget.initialDateRange != null) {
          _controller.text = _formatDateRange(widget.initialDateRange!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      controller: _controller,
      readOnly: true,
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime defaultStartDate = DateTime(
          now.year - 10,
        ); // Ajusta el año según lo que necesites

        final DateTimeRange? pickedDateRange = await showDateRangePicker(
          context: context,
          initialDateRange: widget.initialDateRange,
          firstDate: widget.firstDate ?? defaultStartDate,
          lastDate: widget.lastDate ?? now,
        );
        if (pickedDateRange != null) {
          _controller.text = _formatDateRange(pickedDateRange);
          widget.onChanged(_formatDateRangeForSaving(pickedDateRange));
        }
      },
      style: TextStyle(
        fontSize: AppTokens.fontBody(context),
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      decoration: InputDecoration(
        prefixIcon: Container(
          height: 37.5.w,
          width: 37.5.w,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            assetImgIcon + widget.prefixIcon,
            height: widget.iconHeight.r,
            color: widget.iconColor,
          ),
        ),
        labelText: widget.labelText,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: AppTokens.fontBody(context),
          height: 1,
        ),
      ),
      validator: widget.validator,
    );
  }

  String _formatDateRange(DateTimeRange dateRange) {
    return '${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}';
  }

  String _formatDateRangeForSaving(DateTimeRange dateRange) {
    return '${DateFormat('yyyy-MM-dd').format(dateRange.start)} - ${DateFormat('yyyy-MM-dd').format(dateRange.end)}';
  }
}

class DateRangePickerWidgetFormCustom extends StatefulWidget {
  const DateRangePickerWidgetFormCustom({
    required this.prefixIcon,
    required this.labelText,
    required this.child,
    required this.onChanged,
    super.key,
    this.controller,
    this.iconHeight = 20.0,
    this.height = 50.0,
    this.iconColor = primary,
    this.validator,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final void Function(String?) onChanged;
  final String? Function(String?)? validator;
  final String prefixIcon;
  final double iconHeight;
  final String labelText;
  final Widget child; // Widget personalizado que se mostrará dentro del InkWell
  final TextEditingController? controller;
  final double height;
  final Color? iconColor;
  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  State<DateRangePickerWidgetFormCustom> createState() =>
      _DateRangePickerWidgetFormCustomState();
}

class _DateRangePickerWidgetFormCustomState
    extends State<DateRangePickerWidgetFormCustom> {
  late TextEditingController _controller;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialDateRange != null) {
      _selectedDateRange = widget.initialDateRange;
      _controller.text = _formatDateRange(widget.initialDateRange!);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime defaultStartDate = DateTime(now.year - 10);

    // Primera selección: Elegir fecha inicial
    final DateTime? startDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateRange?.start ?? now,
      firstDate: widget.firstDate ?? defaultStartDate,
      lastDate: widget.lastDate ?? now,
    );

    if (startDate == null) return;

    // Segunda selección: Elegir fecha final (con límite de 7 días)
    final DateTime? endDate = await showDatePicker(
      context: context,
      initialDate: startDate.add(
        const Duration(days: 1),
      ), // Día siguiente por defecto
      firstDate: startDate, // No permitir fechas anteriores a la inicial
      lastDate: DateTime(
        startDate.year,
        startDate.month,
        startDate.day + 7, // Máximo 7 días después
      ),
    );

    if (endDate != null) {
      final newRange = DateTimeRange(start: startDate, end: endDate);
      _controller.text = _formatDateRange(newRange);
      widget.onChanged(_formatDateRangeForSaving(newRange));
      setState(() => _selectedDateRange = newRange);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.enabled ? () => _selectDateRange(context) : null,
      child: widget.child,
    );
  }

  String _formatDateRange(DateTimeRange dateRange) {
    return '${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}';
  }

  String _formatDateRangeForSaving(DateTimeRange dateRange) {
    return '${DateFormat('yyyy-MM-dd').format(dateRange.start)} - ${DateFormat('yyyy-MM-dd').format(dateRange.end)}';
  }
}
