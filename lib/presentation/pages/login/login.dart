import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/utils/responsive.dart';
import 'package:file_cast/presentation/widgets/custom_button_box.dart';
import 'package:file_cast/presentation/widgets/text_form_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Scaffold(
      body: Column(
        children: [
          // ==================== HEADER CON GRADIENTE ====================
          SizedBox(
            width: responsive.width,
            height: responsive.heightPercent(28),

            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono/logo
                  Container(
                    width: responsive.widthPercent(22),
                    height: responsive.widthPercent(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        '${assetImgIcon}folder.svg',
                        width: responsive.widthPercent(12),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.heightPercent(1.5)),
                  Text(
                    Config.appName,
                    style: TextStyle(
                      fontSize: responsive.heightPercent(2.8),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: responsive.heightPercent(0.5)),
                  Text(
                    'Ingresa tus credenciales',
                    style: TextStyle(
                      fontSize: responsive.heightPercent(1.4),
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================== CARD FOLDER SCROLLEABLE ====================
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Fondo del folder con Hero
                Positioned(
                  child: Hero(
                    tag: 'folder-transition',
                    child: SvgPicture.asset(
                      '${assetImgIcon}folder.svg',
                      width: responsive.width,
                      color: folder1,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SvgPicture.asset(
                    '${assetImgIcon}folder.svg',
                    width: responsive.width,
                    fit: BoxFit.fill,
                    color: folder1,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: responsive.width,
                    height: responsive.heightPercent(12),
                    color: folder1,
                  ),
                ),

                // Contenido del card
                Padding(
                  padding: EdgeInsets.only(
                    top: responsive.heightPercent(6),
                    left: 24,
                    right: 24,
                    bottom: 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: responsive.heightPercent(1)),
                        // Título del card
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: responsive.heightPercent(2.5),
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                        SizedBox(height: responsive.heightPercent(0.5)),
                        Text(
                          'Inicia sesión para continuar',
                          style: TextStyle(
                            fontSize: responsive.heightPercent(1.3),
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: responsive.heightPercent(3)),

                        // Campo: Número de Documento
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
                        SizedBox(height: responsive.heightPercent(2)),

                        // Campo: Contraseña
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
                        SizedBox(height: responsive.heightPercent(1)),

                        // Recordarme + Olvidé contraseña
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recordarme',
                                  style: TextStyle(
                                    fontSize: responsive.heightPercent(1.3),
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
                                  fontSize: responsive.heightPercent(1.3),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.heightPercent(2)),

                        // Botón de inicio de sesión
                        Center(
                          child: CustomButtonBoxStyle(
                            title: 'Iniciar Sesión',
                            sizeWidth: responsive.widthPercent(70),
                            sizeHeight: responsive.heightPercent(6),
                            icon: 'paper.svg',
                            iconActive: true,
                            fontSize: responsive.heightPercent(1.8),
                            funcion: () {
                              context.pushNamed(Routes.home);
                            },
                          ),
                        ),
                        SizedBox(height: responsive.heightPercent(2)),

                        // Separador
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'O',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: responsive.heightPercent(1.4),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.heightPercent(2)),

                        // Link a registro
                        Center(
                          child: TextButton(
                            onPressed: () {},
                            child: RichText(
                              text: TextSpan(
                                text: '¿No tienes cuenta? ',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: responsive.heightPercent(1.3),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Regístrate',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: responsive.heightPercent(1.3),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
