import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/utils/complemento.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ModalError extends StatelessWidget {
  const ModalError({
    required this.error,
    super.key,
    this.height,
  });
  final String error;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.all(appPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  '${assetImgIcon}close.svg',
                  color: deleteColor,
                  width: responsive.heightPercent(4),
                ),
                const SizedBox(
                  width: 10,
                ),
                Flexible(
                  child: Text(
                    // "An error occurred: $error.",
                    error,
                    style: TextStyle(
                      fontSize: responsive.heightPercent(1.3),
                      color: deleteColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
