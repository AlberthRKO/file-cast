import 'dart:async';

import 'package:file_cast/app/presentation/global/utils/complemento.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class RelojStream extends StatefulWidget {
  const RelojStream({
    super.key,
    this.isWithDia = false,
  });
  final bool isWithDia;

  @override
  State<RelojStream> createState() => _RelojStreamState();
}

class _RelojStreamState extends State<RelojStream>
    with AutomaticKeepAliveClientMixin {
  // Creamos el Stream estático una sola vez
  static final Stream<DateTime> _dateTimeStream = Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ).asBroadcastStream();

  @override
  bool get wantKeepAlive => true; // Indica que queremos mantener el estado vivo

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'es_ES';
  }

  @override
  Widget build(BuildContext context) {
    super.build(
      context,
    ); // Importante llamar al super.build con AutomaticKeepAliveClientMixin
    final responsive = Responsive.of(context);
    return StreamBuilder<DateTime>(
      stream: _dateTimeStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final DateTime? currentTime = snapshot.data;
          final String? formattedHour = currentTime?.hour.toString().padLeft(
            2,
            '0',
          );
          final String? formattedMinute = currentTime?.minute
              .toString()
              .padLeft(
                2,
                '0',
              );
          final String? formattedSecond = currentTime?.second
              .toString()
              .padLeft(
                2,
                '0',
              );
          final String formattedTime =
              '$formattedHour:$formattedMinute:$formattedSecond';

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    '${assetImgIcon}clock.svg',
                    color: Theme.of(context).primaryColor,
                    width: responsive.heightPercent(2.5),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      fontFamily: 'AlarmClock',
                      fontSize: responsive.heightPercent(2),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (widget.isWithDia) const SizedBox(height: 5),
              if (widget.isWithDia)
                Text(
                  DateFormat(
                    'EEEE, d MMMM',
                    Intl.defaultLocale,
                  ).format(DateTime.now()),
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.6),
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              if (widget.isWithDia)
                const SizedBox(
                  height: 5,
                ),
            ],
          );
        } else {
          return CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          );
        }
      },
    );
  }
}
