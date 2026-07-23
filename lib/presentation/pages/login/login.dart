import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/text_form_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final device = DeviceInfo.of(context);

    return Scaffold(
      body: device.isLandscape
          ? _buildLandscape(context, device)
          : _buildPortrait(context, device),
    );
  }

  Widget _buildPortrait(BuildContext context, DeviceInfo device) {
    return Column(
      children: [
        _buildHeader(context, device),
        Expanded(child: _buildCardBody(context, device)),
      ],
    );
  }

  Widget _buildLandscape(BuildContext context, DeviceInfo device) {
    return Row(
      children: [
        SizedBox(
          width: 0.35.sw,
          child: _buildHeader(context, device),
        ),
        Expanded(child: _buildCardBody(context, device)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DeviceInfo device) {
    final isLandscape = device.isLandscape;
    return Container(
      width: isLandscape ? 0.35.sw : 1.sw,
      height: isLandscape ? 1.sh : 0.28.sh,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [violet, violet2],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isLandscape ? 0.14.sw : 0.22.sw,
              height: isLandscape ? 0.14.sw : 0.22.sw,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  '${assetImgIllustration}upload.svg',
                  width: isLandscape ? 0.07.sw : 0.12.sw,
                ),
              ),
            ),
            SizedBox(height: AppTokens.spaceLg(context)),
            Text(
              Config.appName,
              style: TextStyle(
                fontSize: AppTokens.fontTitle(context),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: AppTokens.spaceSm(context)),
            Text(
              'Ingresa tus credenciales',
              style: TextStyle(
                fontSize: AppTokens.fontCaption(context),
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBody(BuildContext context, DeviceInfo device) {
    final isLandscape = device.isLandscape;
    final maxFormWidth = 500.w;

    final formContent = Padding(
      padding: EdgeInsets.only(
        top: isLandscape ? 0.03.sh : 0.06.sh,
        left: isLandscape ? 0.06.sw : 0.06.sw,
        right: isLandscape ? 0.06.sw : 0.06.sw,
        bottom: AppTokens.spaceXl(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppTokens.spaceLg(context)),
            Text(
              'Bienvenido',
              style: TextStyle(
                fontSize: AppTokens.fontTitle(context),
                fontWeight: FontWeight.bold,
                color: textWhite,
              ),
            ),
            SizedBox(height: AppTokens.spaceXs(context)),
            Text(
              'Inicia sesión para continuar',
              style: TextStyle(
                fontSize: AppTokens.fontCaption(context),
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            SizedBox(
              height: isLandscape
                  ? AppTokens.spaceLg(context)
                  : AppTokens.spaceXl(context),
            ),
            TextFormCustom(
              onChanged: (text) {},
              iconColor: Colors.white,
              prefixIcon: 'cardEmployee.svg',
              labelText: 'Número de Documento',
              validator: (text) {
                if (text == null || text.isEmpty) {
                  return 'Número de Documento vacío';
                }
                if (text.contains(' ')) {
                  return 'El número de documento no debe contener espacios.';
                }
                return null;
              },
            ),
            SizedBox(height: AppTokens.spaceMd(context)),
            TextFormCustom(
              onChanged: (text) {},
              iconColor: Colors.white,
              prefixIcon: 'lock.svg',
              labelText: 'Contraseña',
              isPassword: true,
              validator: (text) {
                if (text == null || text.isEmpty) {
                  return 'Contraseña Vacía';
                }
                if (text.startsWith(' ') || text.endsWith(' ')) {
                  return 'No debe haber espacios en blanco al principio ni al final de la contraseña.';
                }
                return null;
              },
            ),
            SizedBox(height: AppTokens.spaceSm(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white.withOpacity(0.7),
                      size: AppTokens.iconMd(context),
                    ),
                    SizedBox(width: AppTokens.spaceSm(context)),
                    Text(
                      'Recordarme',
                      style: TextStyle(
                        fontSize: AppTokens.fontCaption(context),
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      fontSize: AppTokens.fontCaption(context),
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTokens.spaceMd(context)),
            Center(
              child: CustomButtonBoxStyle(
                title: 'Iniciar Sesión',
                sizeWidth: 0.70.sw,
                sizeHeight: isLandscape
                    ? 40.h
                    : AppTokens.buttonHeightMd(context),
                icon: 'paper.svg',
                iconActive: true,
                fontSize: AppTokens.fontBody(context),
                funcion: () {
                  context.pushNamed(Routes.home);
                },
              ),
            ),
            SizedBox(height: AppTokens.spaceMd(context)),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceMd(context),
                  ),
                  child: Text(
                    'O',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: AppTokens.fontCaption(context),
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            SizedBox(height: AppTokens.spaceMd(context)),
            Center(
              child: TextButton(
                onPressed: () {},
                child: RichText(
                  text: TextSpan(
                    text: '¿No tienes cuenta? ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: AppTokens.fontCaption(context),
                    ),
                    children: [
                      TextSpan(
                        text: 'Regístrate',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTokens.fontCaption(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          child: Hero(
            tag: 'folder-transition',
            child: SvgPicture.asset(
              '${assetImgIcon}folder.svg',
              width: 1.sw,
              color: folder1,
            ),
          ),
        ),
        Positioned.fill(
          child: SvgPicture.asset(
            '${assetImgIcon}folder.svg',
            width: 1.sw,
            fit: BoxFit.fill,
            color: folder1,
          ),
        ),
        Positioned(
          bottom: 0,
          child: Container(
            width: 1.sw,
            height: 0.12.sh,
            color: folder1,
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxFormWidth),
            child: formContent,
          ),
        ),
      ],
    );
  }
}
