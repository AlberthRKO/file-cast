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
          width: 0.4.sw,
          child: _buildHeader(context, device),
        ),
        Expanded(child: _buildCardBody(context, device)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DeviceInfo device) {
    final isLandscape = device.isLandscape;
    return Container(
      width: isLandscape ? 0.4.sw : 1.sw,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF312C69),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: SvgPicture.asset(
                '${assetImgIllustration}fileCast.svg',
                width: isLandscape ? 0.3.sw : 0.6.sw,
              ),
            ),
            SizedBox(height: AppDimensions.spaceM),
            Text(
              Config.appName,
              style: TextStyle(
                fontSize: FontTokens.title(context),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBody(BuildContext context, DeviceInfo device) {
    final isLandscape = device.isLandscape;
    const maxFormWidth = 500.0;

    final formContent = Padding(
      padding: EdgeInsets.only(
        top: isLandscape ? 0.2.sh : 0.02.sh,
        left: 0.06.sw,
        right: 0.06.sw,
        bottom: AppDimensions.spaceL,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: FontTokens.title(context),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: AppDimensions.spaceXS),
            Text(
              'Ingresa tus credenciales para continuar',
              style: TextStyle(
                fontSize: FontTokens.caption(context),
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            SizedBox(
              height: isLandscape
                  ? AppDimensions.spaceL
                  : AppDimensions.spaceXL,
            ),
            TextFormCustom(
              onChanged: (text) {},
              iconColor: Theme.of(context).primaryColor,
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
            SizedBox(height: AppDimensions.spaceM),
            TextFormCustom(
              onChanged: (text) {},
              iconColor: Theme.of(context).primaryColor,
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
            SizedBox(height: AppDimensions.spaceXL),

            Center(
              child: CustomButtonBoxStyle(
                title: 'Iniciar Sesión',
                sizeWidth: 0.85.sw,
                sizeHeight: ComponentTokens.buttonHeight(context),
                icon: 'paper.svg',
                iconActive: true,
                fontSize: FontTokens.body(context),
                funcion: () {
                  context.pushNamed(Routes.home);
                },
                isGradient: true,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E50A5),
                    Color(0xFF2662DE),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppDimensions.spaceM),
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
            constraints: const BoxConstraints(maxWidth: maxFormWidth),
            child: formContent,
          ),
        ),
      ],
    );
  }
}
