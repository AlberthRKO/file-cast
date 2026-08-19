import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/responsive/device_type.dart';
import 'package:file_cast/core/responsive/responsive_extension.dart';
import 'package:file_cast/core/theme/app_dimensions.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/core/theme/tokens/font_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CardActividad extends StatelessWidget {
  const CardActividad({
    required this.fecha,
    required this.cud,
    required this.nombreCaso,
    required this.estado,
    required this.cantidadCapturas,
    required this.cantidadVideos,
    super.key,
    this.onVerDetalle,
  });

  final String fecha;
  final String cud;
  final String nombreCaso;
  final String estado;
  final int cantidadCapturas;
  final int cantidadVideos;
  final VoidCallback? onVerDetalle;

  bool _isFinalizado(String estado) =>
      estado.toLowerCase().contains('finalizado');

  Color _estadoColor(BuildContext context) {
    if (_isFinalizado(estado)) {
      return Theme.of(context).brightness == Brightness.dark
          ? textSucces2
          : editColor;
    }
    return Theme.of(context).brightness == Brightness.dark ? esam : lunchColor;
  }

  @override
  Widget build(BuildContext context) {
    final device = DeviceInfo.of(context);
    final estadoColor = _estadoColor(context);
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: textBlack.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onVerDetalle,
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      '${assetImgIcon}calendar.svg',
                      width: AppDimensions.iconS,
                      color: textColor.withOpacity(0.5),
                    ),
                    SizedBox(width: AppDimensions.spaceXS),
                    Expanded(
                      child: Text(
                        fecha,
                        style: TextStyle(
                          fontSize: FontTokens.caption(context),
                          color: textColor.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spaceS,
                        vertical: AppDimensions.spaceXXS,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.r,
                            height: 6.r,
                            decoration: BoxDecoration(
                              color: estadoColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: AppDimensions.spaceXS),
                          Text(
                            estado,
                            style: TextStyle(
                              fontSize: FontTokens.captionS(context),
                              color: estadoColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: device.isTablet
                      ? AppDimensions.spaceS
                      : AppDimensions.spaceM,
                ),
                Text(
                  'CUD: $cud',
                  style: TextStyle(
                    fontSize: FontTokens.caption(context),
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: AppDimensions.spaceXS),
                Text(
                  nombreCaso,
                  style: TextStyle(
                    fontSize: FontTokens.body(context),
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(
                  height: device.isTablet
                      ? AppDimensions.spaceXS
                      : AppDimensions.spaceM,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: textColor.withOpacity(0.08),
                ),
                SizedBox(
                  height: device.isTablet
                      ? AppDimensions.spaceXS
                      : AppDimensions.spaceM,
                ),
                Row(
                  children: [
                    _ContadorEvidencia(
                      icono: '${assetImgIcon}camera.svg',
                      cantidad: cantidadCapturas,
                      label: 'Capturas',
                    ),
                    SizedBox(width: AppDimensions.spaceS),
                    _ContadorEvidencia(
                      icono: '${assetImgIcon}video.svg',
                      cantidad: cantidadVideos,
                      label: 'Videos',
                    ),
                    const Spacer(),
                    _BotonVerDetalle(
                      size: device.isTablet
                          ? AppDimensions.buttonHeightS
                          : AppDimensions.buttonHeightS,
                      iconSize: device.isTablet
                          ? AppDimensions.iconM
                          : AppDimensions.iconM,
                      onTap: onVerDetalle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContadorEvidencia extends StatelessWidget {
  const _ContadorEvidencia({
    required this.icono,
    required this.cantidad,
    required this.label,
  });

  final String icono;
  final int cantidad;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceS,
        vertical: AppDimensions.spaceXS,
      ),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icono,
            width: AppDimensions.iconS,
            color: primary,
          ),
          SizedBox(width: AppDimensions.spaceXS),
          Text(
            '$cantidad $label',
            style: TextStyle(
              fontSize: FontTokens.captionS(context),
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonVerDetalle extends StatelessWidget {
  const _BotonVerDetalle({
    required this.size,
    required this.iconSize,
    this.onTap,
  });

  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7178EB), violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: violet.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          size: iconSize * 0.7,
          color: Colors.white,
        ),
      ),
    );
  }
}
