import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/data/models/user_model.dart';
import 'package:file_cast/domain/typedef.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/widgets/card_actividad.dart';
import 'package:file_cast/presentation/widgets/custom_avatar.dart';
import 'package:file_cast/presentation/widgets/custom_drop_down.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:file_cast/presentation/widgets/text_form_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  bool _showSearch = true;
  bool _isFilterOpen = false;
  ValueTipo? _selectedEstado;
  DateTimeRange? _selectedDateRange;

  List<ValueTipo> _listEstado = [
    ValueTipo(id: 10, value: 'Todos'),
    ValueTipo(id: 0, value: 'Inactivo'),
    ValueTipo(id: 1, value: 'Solicitud'),
    ValueTipo(id: 2, value: 'Aprobado Jefe'),
    ValueTipo(id: 3, value: 'Observado'),
    ValueTipo(id: 4, value: 'Aprobado RRHH'),
    ValueTipo(id: 5, value: 'Rechazado'),
    ValueTipo(id: 6, value: 'Editado'),
    ValueTipo(id: 7, value: 'Anulado'),
  ];

  void _onScrollNotification(BuildContext context) {
    if (_scrollController.position.userScrollDirection ==
            ScrollDirection.reverse &&
        _showSearch) {
      setState(() {
        _showSearch = false;
        _isFilterOpen = false;
      });
    } else if (_scrollController.position.userScrollDirection ==
            ScrollDirection.forward &&
        !_showSearch) {
      setState(() {
        _showSearch = true;
      });
    }
  }

  void _toggleFilter() {
    setState(() {
      _isFilterOpen = !_isFilterOpen;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = UserModel(
      nombreCompleto: 'Alberto Orlando Paredes Mamani',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7178EB), // #7178EB
              violet, // #145388
            ],
            stops: [
              0.0,
              1.0,
            ], // Controla la posición relativa de los colores
            begin: Alignment.topLeft, // Ajusta el ángulo a 45 grados
            end: Alignment.bottomRight, // Ajusta el ángulo a 45 grados
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            setState(() {});
          },
          borderRadius: BorderRadius.circular(50),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildAppBar(context, user),

          if (_isFilterOpen) _buildFilters(context),
          SizedBox(height: AppDimensions.spaceM),

          Expanded(
            child: DeviceInfo.of(context).isMobile
                ? ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceM,
                      vertical: AppDimensions.spaceS,
                    ),
                    itemCount: 50,
                    itemBuilder: _buildListItem,
                  )
                : _buildGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceM,
            vertical: AppDimensions.spaceS,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        CustomMSAvatar(
                          width: AppDimensions.iconXL,
                          height: AppDimensions.iconXL,
                        ),
                        SizedBox(width: AppDimensions.spaceS),
                        Expanded(
                          child: CustomHeading2(
                            title: 'C.I. 14258827,',
                            title2: user.nombreCompleto ?? '',
                            color2: Theme.of(
                              context,
                            ).textTheme.labelSmall!.color!,
                            fonsizeTitle: FontTokens.caption(context),
                            fonsizeTitle2: FontTokens.body(context),
                            color: Theme.of(
                              context,
                            ).textTheme.bodyLarge!.color!,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppDimensions.spaceXS),
                  InkWell(
                    onTap: () => context.pushNamed(Routes.settings),
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: AppDimensions.iconL,
                          width: AppDimensions.iconL,
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            '${assetImgIcon}notification.svg',
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                            width: AppDimensions.iconM,
                          ),
                        ),
                        Positioned(
                          right: -3,
                          top: -6,
                          child: Container(
                            width: AppDimensions.iconS,
                            height: AppDimensions.iconS,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor,
                              border: Border.all(color: Colors.white),
                            ),
                            child: Center(
                              child: Text(
                                '2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: FontTokens.captionS(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                spacing: AppDimensions.spaceS,
                children: [
                  Flexible(child: _buildSearchSection(context)),

                  InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: _toggleFilter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: AppDimensions.buttonHeightS,
                      height: AppDimensions.buttonHeightS,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: !_isFilterOpen
                              ? Theme.of(context).primaryColor
                              : deleteColor,
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        '${assetImgIcon}filterMore.svg',
                        width: 20.r,
                        color: !_isFilterOpen
                            ? Theme.of(context).primaryColor
                            : deleteColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: AppDimensions.spaceS,
        bottom: AppDimensions.spaceS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFieldSearch(
            prefixIcon: 'search.svg',
            labelText: 'Buscar Actividad (descripción)',
            iconHeight: AppDimensions.iconM,
            iconColor: Theme.of(context).primaryColor,
            onChanged: (text) {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppDimensions.spaceS,
        left: AppDimensions.spaceM,
        right: AppDimensions.spaceM,
      ),
      child: Column(
        children: [
          CustomDropDown<ValueTipo>(
            color: Theme.of(context).primaryColor,
            colorText: Theme.of(context).textTheme.bodyLarge!.color,
            prefixIcon: true,
            prefixIconValue: 'estado.svg',
            lista: _listEstado, // Usar la lista dinámica
            valueExtractor: (item) => item,
            textExtractor: (item) => item.value.toString(),
            value: _selectedEstado,
            label: 'Estado',
            onChanged: (value) {
              setState(() => _selectedEstado = value as ValueTipo?);
            },
          ),
          SizedBox(height: AppDimensions.spaceM),
          DateRangePickerFormCustom(
            onChanged: (text) {
              if (text != null) {
                final parts = text.split(' - ');
                if (parts.length == 2) {
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: DateFormat('yyyy-MM-dd').parse(parts[0]),
                      end: DateFormat('yyyy-MM-dd').parse(parts[1]),
                    );
                  });
                }
              }
            },
            prefixIcon: 'calendar.svg',
            labelText: 'Fecha inicio - Fecha fin',
            initialDateRange:
                _selectedDateRange ??
                DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 30)),
                  end: DateTime.now(),
                ),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            iconColor: Theme.of(context).primaryColor,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Elija un rango de fechas';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceM,
        vertical: AppDimensions.spaceS,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: 270,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: 50,
      itemBuilder: _buildListItem,
    );
  }

  Widget _buildListItem(BuildContext context, int index) {
    return CardActividad(
      fecha: '23/08/2023 18:30',
      cud: '12312312',
      nombreCaso: 'Robo agravado en oficina central ${index + 1}',
      estado: index % 3 == 0 ? 'Finalizado' : 'En curso',
      cantidadCapturas: 3 + (index % 3),
      cantidadVideos: 2 + (index % 2),
      onVerDetalle: () => setState(() {}),
    );
  }
}
