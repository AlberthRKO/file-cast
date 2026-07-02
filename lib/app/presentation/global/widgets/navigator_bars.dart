import 'package:file_cast/app/data/services/utils/local_providers.dart';
import 'package:file_cast/app/presentation/global/controllers/theme_controller.dart';
import 'package:file_cast/app/presentation/global/theme/colors.dart';
import 'package:file_cast/app/presentation/global/utils/complemento.dart';
import 'package:file_cast/app/presentation/global/utils/responsive.dart';
import 'package:file_cast/app/presentation/global/widgets/circle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

const _duration = Duration(milliseconds: 400);
const double _bottomBarHide = -100;
const double _bottomBarShow = 10;
const double _bottomBarHideSuport = -100;
const double _bottomBarShowSuport = 90;

class NavigationBars extends StatelessWidget {
  const NavigationBars({
    required this.selectedIndex,
    super.key,
    this.showBar = true,
    this.isFiscal = false,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;
  final bool isFiscal;

  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensState>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      bottom: showBar ? _bottomBarShow : _bottomBarHide,
      left: responsive.widthPercent(8),
      right: responsive.widthPercent(8),
      // Contenido del navbar
      child: Container(
        // le damos un tamaño del 8% de la pantalla
        height: responsive.heightPercent(8),
        decoration: BoxDecoration(
          // preguntamos si el tema es dark  para luego consultar en q posicion esta el navbar,
          //si esta en el 1 usamos el color primario y si no esta ahi usamos el secundario que es mas fuerte
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: violet.withOpacity(0.2),
              offset: const Offset(4, 4),
              blurRadius: 20,
            ),
          ],
        ),
        // Seccion de los bars de navegacion
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircleButton(
              title: 'MENÚ',
              callback: () {
                Scaffold.of(context).openDrawer();
              },
              icon: SvgPicture.asset(
                '${assetImgIcon}menu.svg',
                color: Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              color: Theme.of(context).hintColor,
              background: Colors.transparent,
            ),
            CircleButton(
              title: 'HOME',
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                '${assetImgIcon}home.svg',
                color: selectedIndex == 0
                    ? textWhite
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              color: selectedIndex == 0
                  ? textWhite
                  : Theme.of(context).hintColor,
              background: selectedIndex == 0
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
            ),
            if (isFiscal)
              CircleButton(
                title: 'MÉTRICAS',
                callback: () => screenState.page = 1,
                width: responsive.heightPercent(8),
                icon: SvgPicture.asset(
                  '${assetImgIcon}estadistica.svg',
                  color: selectedIndex == 1
                      ? textWhite
                      : Theme.of(context).hintColor,
                  height: responsive.heightPercent(2.5),
                ),
                color: selectedIndex == 1
                    ? textWhite
                    : Theme.of(context).hintColor,
                background: selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
              ),
            CircleButton(
              title: 'PERFIL',
              callback: () => screenState.page = isFiscal ? 2 : 1,
              icon: SvgPicture.asset(
                '${assetImgIcon}user_icon.svg',
                color: isFiscal
                    ? selectedIndex == 2
                          ? textWhite
                          : Theme.of(context).hintColor
                    : selectedIndex == 1
                    ? textWhite
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              color: isFiscal
                  ? selectedIndex == 2
                        ? textWhite
                        : Theme.of(context).hintColor
                  : selectedIndex == 1
                  ? textWhite
                  : Theme.of(context).hintColor,
              background: isFiscal
                  ? selectedIndex == 2
                        ? Theme.of(context).primaryColor
                        : Colors.transparent
                  : selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class SuportButton extends StatelessWidget {
  const SuportButton({
    required this.selectedIndex,
    required this.funcion,
    super.key,
    this.showBar = true,
    this.countGlog = 0,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  final int selectedIndex;
  final int countGlog;
  final void Function()? funcion;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch();
    final bool darkMode = themeController.darkMode;
    final screenState = Provider.of<ScreensStateHomeCiudadania>(context);
    final responsive = Responsive.of(context);
    print('Valor de selectedIndex: $selectedIndex');
    return screenState.page != 1 || selectedIndex != 1
        ? AnimatedPositioned(
            duration: _duration,
            // si es true mostramos el navbar y si no lo ocultamos con las posiciones
            bottom: showBar ? _bottomBarShowSuport : _bottomBarHideSuport,
            right: responsive.widthPercent(10),
            // Contenido del navbar
            child: Container(
              // le damos un tamaño del 8% de la pantalla
              decoration: BoxDecoration(
                // preguntamos si el tema es dark  para luego consultar en q posicion esta el navbar,
                //si esta en el 1 usamos el color primario y si no esta ahi usamos el secundario que es mas fuerte
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(100),
                  bottomLeft: Radius.circular(100),
                  topRight: Radius.circular(100),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    offset: const Offset(4, 4),
                    blurRadius: 20,
                  ),
                ],
              ),
              // Seccion de los bars de navegacion
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleButton(
                        borderRadius: 50,
                        width: responsive.widthPercent(13),
                        height: responsive.widthPercent(13),
                        //title: "CHAT",
                        callback: () {
                          funcion!();
                        },
                        icon: SvgPicture.asset(
                          '${assetImgIcon}message.svg',
                          color: darkMode
                              ? Theme.of(context).textTheme.bodyMedium!.color!
                              : textWhite,
                          height: responsive.heightPercent(3.5),
                        ),
                        color: darkMode
                            ? Theme.of(context).textTheme.bodyMedium!.color!
                            : textWhite,
                        background: Colors.transparent,
                      ),
                    ],
                  ),
                  if (countGlog > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        height: responsive.widthPercent(5),
                        width: responsive.widthPercent(5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: violet.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          countGlog.toString(),
                          style: TextStyle(
                            color: textWhite.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: responsive.heightPercent(1.8),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          )
        : Container();
  }
}

class NavigationBarsHomeCiudadania extends StatelessWidget {
  const NavigationBarsHomeCiudadania({
    required this.selectedIndex,
    super.key,
    this.showBar = true,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStateHomeCiudadania>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      bottom: showBar ? _bottomBarShow : _bottomBarHide,
      left: responsive.widthPercent(10),
      right: responsive.widthPercent(10),
      // Contenido del navbar
      child: Container(
        // le damos un tamaño del 8% de la pantalla
        height: responsive.heightPercent(8),
        decoration: BoxDecoration(
          // preguntamos si el tema es dark  para luego consultar en q posicion esta el navbar,
          //si esta en el 1 usamos el color primario y si no esta ahi usamos el secundario que es mas fuerte
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: violet.withOpacity(0.2),
              offset: const Offset(4, 4),
              blurRadius: 20,
            ),
          ],
        ),
        // Seccion de los bars de navegacion
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircleButton(
              title: 'MENÚ',
              callback: () {
                Scaffold.of(context).openDrawer();
              },
              icon: SvgPicture.asset(
                '${assetImgIcon}menu.svg',
                color: Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              color: Theme.of(context).hintColor,
              background: Colors.transparent,
            ),
            CircleButton(
              title: 'HOME',
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                '${assetImgIcon}home.svg',
                color: selectedIndex == 0
                    ? textWhite
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              color: selectedIndex == 0
                  ? textWhite
                  : Theme.of(context).hintColor,
              background: selectedIndex == 0
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
            ),
            // CircleButton(
            //   title: "AGENDA",
            //   callback: () => screenState.page = 1,
            //   icon: SvgPicture.asset(
            //     '${assetImgIcon}atrasos.svg',
            //     color: selectedIndex == 1
            //         ? textWhite
            //         : Theme.of(context).hintColor,
            //     height: responsive.heightPercent(2.5),
            //   ),
            //   color:
            //       selectedIndex == 1 ? textWhite : Theme.of(context).hintColor,
            //   background: selectedIndex == 1
            //       ? Theme.of(context).primaryColor
            //       : Colors.transparent,
            // ),
            CircleButton(
              title: 'PERFIL',
              callback: () => screenState.page = 1,
              icon: SvgPicture.asset(
                '${assetImgIcon}user_icon.svg',
                color: selectedIndex == 1
                    ? textWhite
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              color: selectedIndex == 1
                  ? textWhite
                  : Theme.of(context).hintColor,
              background: selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationBarsTabs extends StatefulWidget {
  const NavigationBarsTabs({
    required this.selectedIndex,
    super.key,
    this.showBar = true,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;

  @override
  State<NavigationBarsTabs> createState() => _NavigationBarsTabsState();
}

class _NavigationBarsTabsState extends State<NavigationBarsTabs> {
  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStateTabs>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      //top: widget.showBar ? _bottomBarShow : _bottomBarHide,
      top: 0,
      left: responsive.widthPercent(0),
      right: responsive.widthPercent(0),

      // Contenido del navbar
      child: Container(
        padding: EdgeInsets.only(
          left: responsive.widthPercent(2),
          right: responsive.widthPercent(2),
        ),
        width: responsive.widthPercent(100),
        height: responsive.heightPercent(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              RoundedButton(
                title: 'Inicio',
                width: responsive.widthPercent(22.5),
                callback: () => screenState.page = 0,
                icon: SvgPicture.asset(
                  '${assetImgIcon}dash.svg',
                  color: widget.selectedIndex == 0
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
                  height: responsive.heightPercent(2.5),
                ),
                background: widget.selectedIndex == 0
                    ? Colors.transparent
                    : Colors.transparent,
                color: widget.selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                isBorder: widget.selectedIndex == 0,
              ),
              SizedBox(
                width: responsive.widthPercent(2),
              ),
              RoundedButton(
                title: 'Calendario',
                width: responsive.widthPercent(22.5),
                callback: () => screenState.page = 1,
                icon: SvgPicture.asset(
                  '${assetImgIcon}calendar.svg',
                  color: widget.selectedIndex == 1
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
                  height: responsive.heightPercent(2.5),
                ),
                background: widget.selectedIndex == 1
                    ? Colors.transparent
                    : Colors.transparent,
                color: widget.selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                isBorder: widget.selectedIndex == 1,
              ),
              SizedBox(
                width: responsive.widthPercent(2),
              ),
              RoundedButton(
                title: 'Atrasos',
                width: responsive.widthPercent(22.5),
                callback: () => screenState.page = 2,
                icon: SvgPicture.asset(
                  '${assetImgIcon}clock.svg',
                  color: widget.selectedIndex == 2
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
                  height: responsive.heightPercent(2.5),
                ),
                background: widget.selectedIndex == 2
                    ? Colors.transparent
                    : Colors.transparent,
                color: widget.selectedIndex == 2
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                isBorder: widget.selectedIndex == 2,
              ),
              SizedBox(
                width: responsive.widthPercent(2),
              ),
              RoundedButton(
                title: 'Asistencia',
                width: responsive.widthPercent(22.5),
                callback: () => screenState.page = 3,
                icon: SvgPicture.asset(
                  '${assetImgIcon}cardEmployee.svg',
                  color: widget.selectedIndex == 3
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
                  height: responsive.heightPercent(2.5),
                ),
                background: widget.selectedIndex == 3
                    ? Colors.transparent
                    : Colors.transparent,
                color: widget.selectedIndex == 3
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                isBorder: widget.selectedIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavigationBarsPermisos extends StatefulWidget {
  const NavigationBarsPermisos({
    required this.selectedIndex,
    super.key,
    this.showBar = true,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;

  @override
  State<NavigationBarsPermisos> createState() => _NavigationBarsPermisosState();
}

class _NavigationBarsPermisosState extends State<NavigationBarsPermisos> {
  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStatePermisos>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      //top: widget.showBar ? _bottomBarShow : _bottomBarHide,
      top: 0,
      left: responsive.widthPercent(0),
      right: responsive.widthPercent(0),

      // Contenido del navbar
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
        width: responsive.widthPercent(100),
        height: responsive.heightPercent(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedButton(
              title: 'Por Horas',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                '${assetImgIcon}clock.svg',
                color: widget.selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 0
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 0
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 0,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'Por Días',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 1,
              icon: SvgPicture.asset(
                '${assetImgIcon}calendar.svg',
                color: widget.selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 1
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 1,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'Omisiones',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 2,
              icon: SvgPicture.asset(
                '${assetImgIcon}contrato.svg',
                color: widget.selectedIndex == 2
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 2
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 2
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 2,
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationBarsActivos extends StatefulWidget {
  const NavigationBarsActivos({
    required this.selectedIndex,
    required this.isJefe,
    super.key,
    this.showBar = true,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;
  final bool isJefe;

  @override
  State<NavigationBarsActivos> createState() => _NavigationBarsActivosState();
}

class _NavigationBarsActivosState extends State<NavigationBarsActivos> {
  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStateActivos>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      //top: widget.showBar ? _bottomBarShow : _bottomBarHide,
      top: 0,
      left: responsive.widthPercent(0),
      right: responsive.widthPercent(0),

      // Contenido del navbar
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
        width: responsive.widthPercent(100),
        height: responsive.heightPercent(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedButton(
              title: widget.isJefe ? 'Revisiones' : 'Activos',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                widget.isJefe
                    ? '${assetImgIcon}verDoc.svg'
                    : '${assetImgIcon}marca.svg',
                color: widget.selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 0
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 0
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 0,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: widget.isJefe ? 'Autorizaciones' : 'Solicitudes',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 1,
              icon: SvgPicture.asset(
                widget.isJefe
                    ? '${assetImgIcon}contrato.svg'
                    : '${assetImgIcon}atrasos.svg',
                color: widget.selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 1
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 1,
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationBarsAlmacenes extends StatefulWidget {
  const NavigationBarsAlmacenes({
    required this.selectedIndex,
    super.key,
    this.showBar = true,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;

  @override
  State<NavigationBarsAlmacenes> createState() =>
      _NavigationBarsAlmacenesState();
}

class _NavigationBarsAlmacenesState extends State<NavigationBarsAlmacenes> {
  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStateAlmacenes>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      //top: widget.showBar ? _bottomBarShow : _bottomBarHide,
      top: 0,
      left: responsive.widthPercent(0),
      right: responsive.widthPercent(0),

      // Contenido del navbar
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
        width: responsive.widthPercent(100),
        height: responsive.heightPercent(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedButton(
              title: 'Revisiones',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                '${assetImgIcon}verDoc.svg',
                color: widget.selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 0
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 0
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 0,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'Autorizaciones',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 1,
              icon: SvgPicture.asset(
                '${assetImgIcon}contrato.svg',
                color: widget.selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 1
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 1,
            ),
          ],
        ),
      ),
    );
  }
}

class OptionsButtonActividad extends StatelessWidget {
  const OptionsButtonActividad({
    super.key,
    this.showBar = true,
    this.onEdit,
    this.onEnviar,
    this.onPreview,
    this.onGuardar,
    this.onAprobar,
    this.isLoadingEnviar = false,
    this.isLoadingPreview = false,
    this.isLoadingGuardar = false,
    this.isLoadingAprobar = false,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  final void Function()? onEdit;
  final void Function()? onEnviar;
  final bool isLoadingEnviar;
  final void Function()? onPreview;
  final bool isLoadingPreview;
  final void Function()? onGuardar;
  final bool isLoadingGuardar;
  final void Function()? onAprobar;
  final bool isLoadingAprobar;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      bottom: showBar ? _bottomBarShow : _bottomBarHide,
      left: responsive.widthPercent(8),
      right: responsive.widthPercent(8),
      // Contenido del navbar
      child: Container(
        // le damos un tamaño del 8% de la pantalla
        height: responsive.heightPercent(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: violet.withOpacity(0.2),
              offset: const Offset(4, 4),
              blurRadius: 20,
            ),
          ],
        ),
        // Seccion de los bars de navegacion
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            /*CircleButton(
              width: responsive.widthPercent(15),
              title: "EDITAR",
              callback: () => onEdit,
              icon: SvgPicture.asset(
                '${assetImgIcon}edit.svg',
                color: Theme.of(context).textTheme.bodyLarge!.color!,
                height: responsive.heightPercent(2.5),
              ),
              color: Theme.of(context).textTheme.bodyLarge!.color!,
              background: Colors.transparent,
            ),*/
            if (isLoadingGuardar)
              isLoadingWidget(responsive, context)
            else
              CircleButton(
                width: responsive.widthPercent(20),
                title: 'GUARDAR',
                callback: onGuardar!,
                icon: SvgPicture.asset(
                  '${assetImgIcon}save.svg',
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  height: responsive.heightPercent(2.5),
                ),
                color: Theme.of(context).textTheme.bodyLarge!.color!,
                background: Colors.transparent,
              ),
            if (isLoadingPreview)
              isLoadingWidget(responsive, context)
            else
              CircleButton(
                width: responsive.widthPercent(20),
                title: 'VER',
                callback: onPreview!,
                icon: SvgPicture.asset(
                  '${assetImgIcon}eye.svg',
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  height: responsive.heightPercent(2.5),
                ),
                color: Theme.of(context).textTheme.bodyLarge!.color!,
                background: Colors.transparent,
              ),
            /* isLoadingAprobar
                ? isLoadingWidget(responsive, context)
                : CircleButton(
                    width: responsive.widthPercent(20),
                    title: "APROBAR",
                    callback: onAprobar!,
                    icon: SvgPicture.asset(
                      '${assetImgIcon}check.svg',
                      color: Theme.of(context).textTheme.bodyLarge!.color!,
                      height: responsive.heightPercent(2.5),
                    ),
                    color: Theme.of(context).textTheme.bodyLarge!.color!,
                    background: Colors.transparent,
                  ),
            isLoadingEnviar
                ? isLoadingWidget(responsive, context)
                : CircleButton(
                    width: responsive.widthPercent(20),
                    title: "ENVIAR",
                    callback: onEnviar!,
                    icon: SvgPicture.asset(
                      '${assetImgIcon}paper.svg',
                      color: Theme.of(context).textTheme.bodyLarge!.color!,
                      height: responsive.heightPercent(2.5),
                    ),
                    color: Theme.of(context).textTheme.bodyLarge!.color!,
                    background: Colors.transparent,
                  ), */
          ],
        ),
      ),
    );
  }

  Widget isLoadingWidget(Responsive responsive, BuildContext context) {
    return SizedBox(
      width: responsive.widthPercent(20),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class NavigationSelectDashboard extends StatefulWidget {
  const NavigationSelectDashboard({
    required this.selectedIndex,
    super.key,
  });

  // damos valor por defecto de true para que se visualize el navbar
  // valor para saber en q paginacion estamos
  final int selectedIndex;

  @override
  State<NavigationSelectDashboard> createState() =>
      _NavigationSelectDashboardState();
}

class _NavigationSelectDashboardState extends State<NavigationSelectDashboard> {
  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStateAlmacenes>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      //top: widget.showBar ? _bottomBarShow : _bottomBarHide,
      top: 0,
      left: responsive.widthPercent(0),
      right: responsive.widthPercent(0),

      // Contenido del navbar
      child: Container(
        width: responsive.widthPercent(100),
        height: responsive.heightPercent(8),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedButton(
              title: 'Activa',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                '${assetImgIcon}atrasos.svg',
                color: widget.selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 0
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 0,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'Cerrados',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 1,
              icon: SvgPicture.asset(
                '${assetImgIcon}contrato.svg',
                color: widget.selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: Colors.transparent,
              color: widget.selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 1,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'F. Registro',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 2,
              icon: SvgPicture.asset(
                '${assetImgIcon}curso.svg',
                color: widget.selectedIndex == 2
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: Colors.transparent,
              color: widget.selectedIndex == 2
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 2,
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationBarsFirmasPresentaciones extends StatefulWidget {
  const NavigationBarsFirmasPresentaciones({
    required this.selectedIndex,
    super.key,
    this.showBar = true,
  });

  // damos valor por defecto de true para que se visualize el navbar
  final bool showBar;
  // valor para saber en q paginacion estamos
  final int selectedIndex;

  @override
  State<NavigationBarsFirmasPresentaciones> createState() =>
      _NavigationBarsFirmasPresentacionesState();
}

class _NavigationBarsFirmasPresentacionesState
    extends State<NavigationBarsFirmasPresentaciones> {
  @override
  Widget build(BuildContext context) {
    final screenState = Provider.of<ScreensStateFirmasPresentaciones>(context);
    final responsive = Responsive.of(context);

    return AnimatedPositioned(
      duration: _duration,
      // si es true mostramos el navbar y si no lo ocultamos con las posiciones
      //top: widget.showBar ? _bottomBarShow : _bottomBarHide,
      top: 0,
      left: responsive.widthPercent(0),
      right: responsive.widthPercent(0),

      // Contenido del navbar
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
        width: responsive.widthPercent(100),
        height: responsive.heightPercent(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedButton(
              title: 'Asistencias',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 0,
              icon: SvgPicture.asset(
                '${assetImgIcon}calendar.svg',
                color: widget.selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 0
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 0
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 0,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'Modificaciones\ny Licencias',
              width: responsive.widthPercent(28),
              height: responsive.heightPercent(10),
              callback: () => screenState.page = 1,
              icon: SvgPicture.asset(
                '${assetImgIcon}contrato.svg',
                color: widget.selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 1
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 1
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 1,
            ),
            const SizedBox(
              width: 10,
            ),
            RoundedButton(
              title: 'Biométricos',
              width: responsive.widthPercent(28),
              callback: () => screenState.page = 2,
              icon: SvgPicture.asset(
                '${assetImgIcon}finger.svg',
                color: widget.selectedIndex == 2
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
                height: responsive.heightPercent(2.5),
              ),
              background: widget.selectedIndex == 2
                  ? Theme.of(context).cardColor
                  : Colors.transparent,
              color: widget.selectedIndex == 2
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
              isBorder: widget.selectedIndex == 2,
            ),
          ],
        ),
      ),
    );
  }
}
