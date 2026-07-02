import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomToolbar extends StatelessWidget {
  const CustomToolbar({
    required this.sancion,
    required this.colorSancion,
    super.key,
  });

  final Color colorSancion;
  final String sancion;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorSancion.withOpacity(.05),
        border: Border.all(color: colorSancion, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SvgPicture.asset(
            '${assetImgIcon}world.svg',
            color: colorSancion,
            width: responsive.heightPercent(1.8),
          ),
          const SizedBox(width: 5),
          RichText(
            text: TextSpan(
              children: [
                /*TextSpan(
                                      text: "Sancion: ", // Texto dinámico
                                      style: TextStyle(
                                        fontSize: responsive.heightPercent(1.4),
                                        color: colorSancion,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: "Poppins",
                                        height: 1.1,
                                      ),
                                    ),*/
                TextSpan(
                  text: sancion, // Texto dinámico
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.4),
                    color: colorSancion,
                    fontFamily: 'Poppins',
                    height: 1.1,
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
