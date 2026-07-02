import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/complemento.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomCardChat extends StatelessWidget {
  const CustomCardChat({
    required this.title,
    required this.orientation,
    required this.nameImageSvg,
    super.key,
    this.color = primary,
    this.onTap,
    this.countGlog = 0,
  });

  final Orientation orientation;
  final String title;
  final String nameImageSvg;
  final int countGlog;
  final Color color;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    const List soporteLinea = [
      {
        'icon': '${assetImgIcon}message.svg',
        'title': 'Chat',
        'color': Colors.green,
        'amount': 3,
      },
      {
        'icon': '${assetImgIcon}mail.svg',
        'title': 'Sugerencias',
        'color': Colors.blue,
        'amount': 0,
      },
    ];
    final responsive = Responsive.of(context);
    return Container(
      alignment: Alignment.center,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: orientation == Orientation.landscape
              ? 150
              : responsive.widthPercent(150) * .28,
          padding: const EdgeInsets.all(10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: textBlack.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    height: responsive.widthPercent(12),
                    width: responsive.widthPercent(12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: SvgPicture.asset(
                      '$assetImgIcon$nameImageSvg',
                      color: color,
                      width: responsive.heightPercent(2.8),
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      fontSize: responsive.heightPercent(1.5),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (countGlog > 0)
                Positioned(
                  top: 1,
                  right: 100,
                  child: Container(
                    height: responsive.widthPercent(5),
                    width: responsive.widthPercent(5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(countGlog.toString()),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
