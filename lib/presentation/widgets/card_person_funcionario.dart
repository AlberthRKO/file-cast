import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardPersonFuncionario extends StatelessWidget {
  const CardPersonFuncionario({
    required this.institucion,
    required this.entidad,
    required this.oficina,
    required this.division,
    required this.cargo,
    super.key,
  });

  final String institucion;
  final String entidad;
  final String oficina;
  final String division;
  final String cargo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      width: responsive.width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: textBlack.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                '${assetImgIcon}entidad.svg',
                color: Theme.of(context).primaryColor,
                width: responsive.heightPercent(1.8),
              ),
              const SizedBox(
                width: 3,
              ),
              Text(
                'Institución: ',
                style: TextStyle(
                  fontSize: responsive.heightPercent(1.4),
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              Flexible(
                child: Text(
                  institucion,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.4),
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                '${assetImgIcon}entidad2.svg',
                color: Theme.of(context).primaryColor,
                width: responsive.heightPercent(1.8),
              ),
              const SizedBox(
                width: 3,
              ),
              Text(
                'Entidad: ',
                style: TextStyle(
                  fontSize: responsive.heightPercent(1.4),
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              Flexible(
                child: Text(
                  entidad,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.4),
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                '${assetImgIcon}entidad.svg',
                color: Theme.of(context).primaryColor,
                width: responsive.heightPercent(1.8),
              ),
              const SizedBox(
                width: 3,
              ),
              Text(
                'Oficina: ',
                style: TextStyle(
                  fontSize: responsive.heightPercent(1.4),
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              Flexible(
                child: Text(
                  oficina,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.4),
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                '${assetImgIcon}entidad2.svg',
                color: Theme.of(context).primaryColor,
                width: responsive.heightPercent(1.8),
              ),
              const SizedBox(
                width: 3,
              ),
              Text(
                'División: ',
                style: TextStyle(
                  fontSize: responsive.heightPercent(1.4),
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              Flexible(
                child: Text(
                  division,
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.4),
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ),
            ],
          ),
          if (cargo != '')
            const SizedBox(
              height: 5,
            ),
          if (cargo != '')
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  '${assetImgIcon}vacation.svg',
                  color: Theme.of(context).primaryColor,
                  width: responsive.heightPercent(1.8),
                ),
                const SizedBox(
                  width: 3,
                ),
                Text(
                  'Cargo: ',
                  style: TextStyle(
                    fontSize: responsive.heightPercent(1.4),
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: Text(
                    cargo,
                    style: TextStyle(
                      fontSize: responsive.heightPercent(1.4),
                      color: Theme.of(context).textTheme.bodySmall!.color,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
