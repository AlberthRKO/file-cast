import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/padding.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';

class ModalSuccess extends StatelessWidget {
  const ModalSuccess({
    required this.messsage,
    super.key,
  });
  final String messsage;

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
              '${assetImgIcon}check.svg',
              color: Theme.of(context).primaryColor,
              width: responsive.heightPercent(6),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              // "An messsage occurred: $messsage.",
              messsage,
              style: TextStyle(
                fontSize: responsive.heightPercent(1.3),
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontWeight: FontWeight.w500,
              ),
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

class ModalSuccessAnimation extends StatelessWidget {
  const ModalSuccessAnimation({
    required this.messsage,
    required this.lottie,
    super.key,
  });
  final String messsage;
  final String lottie;

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
            Lottie.asset(
              '$assetImgIllustration$lottie',
              height: responsive.heightPercent(15),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              // "An messsage occurred: $messsage.",
              messsage,
              style: TextStyle(
                fontSize: responsive.heightPercent(1.3),
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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
