import 'package:file_cast/presentation/widgets/appbar.dart';
import 'package:file_cast/presentation/widgets/card_info.dart';
import 'package:flutter/material.dart';

class Offline extends StatelessWidget {
  const Offline({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: getAppbar(Colors.transparent),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 15,
          ),
          child: CardSinInter(
            isImg: true,
            img: 'noInternet.svg',
            title: 'Sin conexión a Internet',
            subtitle:
                'No hay conexión a Internet, conéctese a una red Wi-Fi o datos móviles.',
          ),
        ),
      ),
    );
  }
}
