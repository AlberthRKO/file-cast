import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:file_cast/app/presentation/global/theme/padding.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:file_cast/app/presentation/global/widgets/custom_heading.dart';

class ModalProximamente extends StatelessWidget {
  const ModalProximamente({
    required this.title,
    required this.subtitle,
    required this.img,
    super.key,
  });

  final String title;
  final String subtitle;
  final String img;

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
            SvgPicture.asset(
              img,
              width: responsive.heightPercent(22),
            ),
            const SizedBox(
              height: 10,
            ),
            CustomHeading(
              title: title,
              subTitle: subtitle,
              centro: true,
              fonsizeTitle: responsive.heightPercent(2.5),
              fonsizesubTitle: responsive.heightPercent(1.6),
              color: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
            const SizedBox(
              height: miniSpacer,
            ),
            const SizedBox(
              height: smallSpacer,
            ),
          ],
        ),
      ),
    );
  }
}
