import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  const CircleButton({
    required this.callback,
    required this.icon,
    required this.background,
    super.key,
    this.height = 0.0,
    this.color = Colors.white,
    this.width = 0.0,
    this.title = '',
    this.borderRadius = 10,
  });

  final VoidCallback callback;
  final Widget icon;
  final Color color;
  final Color background;

  final double height;
  final double width;
  final double borderRadius;
  final String title;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    // condicion para q si n llega nada de tamaño le de un por defecto y si llega se mantenga el q mando
    final heightCircle = (height == 0.0) ? responsive.heightPercent(6) : height;
    final widthCircle = (width == 0.0) ? responsive.heightPercent(6) : width;
    return Container(
      width: widthCircle,
      height: heightCircle,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: callback,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              if (title != '')
                const SizedBox(
                  height: 2,
                ),
              if (title != '')
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: responsive.heightPercent(1.3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundedButton extends StatelessWidget {
  const RoundedButton({
    required this.callback,
    required this.icon,
    required this.background,
    super.key,
    this.height = 0.0,
    this.width = 0.0,
    this.title = '',
    this.color = Colors.white,
    this.isBorder = false,
  });

  final VoidCallback callback;
  final Widget icon;
  final Color background;
  final Color color;
  final double height;
  final double width;
  final String title;
  final bool isBorder;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    // condicion para q si n llega nada de tamaño le de un por defecto y si llega se mantenga el q mando
    final heightCircle = (height == 0.0) ? responsive.heightPercent(6) : height;
    final widthCircle = (width == 0.0) ? responsive.heightPercent(4.5) : width;
    return Container(
      width: widthCircle,
      height: heightCircle,
      decoration: BoxDecoration(
        color: background,
        //borderRadius: BorderRadius.circular(5),
        border: isBorder
            ? Border(
                bottom: BorderSide(
                  color: color,
                ),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: callback,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              if (title != '')
                const SizedBox(
                  height: 4,
                ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: responsive.heightPercent(1.5),
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircleButton2 extends StatelessWidget {
  const CircleButton2({
    required this.callback,
    required this.icon,
    required this.background,
    super.key,
    this.height = 0.0,
    this.color = Colors.white,
    this.width = 0.0,
    this.title = '',
    this.borderRadius = 10,
    this.isDisabled = false,
  });

  final VoidCallback callback;
  final Widget icon;
  final Color color;
  final Color background;

  final double height;
  final double width;
  final double borderRadius;
  final String title;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    // condicion para q si n llega nada de tamaño le de un por defecto y si llega se mantenga el q mando
    final heightCircle = (height == 0.0) ? responsive.heightPercent(6) : height;
    final widthCircle = (width == 0.0) ? responsive.heightPercent(6) : width;
    return Container(
      width: widthCircle,
      height: heightCircle,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: isDisabled ? () {} : callback,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              if (title != '')
                const SizedBox(
                  height: 2,
                ),
              if (title != '')
                Text(
                  title,
                  style: TextStyle(
                    color: isDisabled ? Colors.grey : color,
                    fontSize: responsive.heightPercent(1.3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
