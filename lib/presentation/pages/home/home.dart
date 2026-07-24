import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/data/models/user_model.dart';
import 'package:file_cast/domain/typedef.dart';
import 'package:file_cast/presentation/routes/routes.dart';
import 'package:file_cast/presentation/widgets/custom_avatar.dart';
import 'package:file_cast/presentation/widgets/custom_drop_down.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:file_cast/presentation/widgets/text_form_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _duration = Duration(milliseconds: 400);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  bool _showSearch = true;
  bool _isFilterOpen = false;
  ValueType<dynamic>? _selectedEstado;
  DateTimeRange? _selectedDateRange;

  final List<ValueType<dynamic>> _listEstado = <ValueType<dynamic>>[
    ValueType<dynamic>(id: 10, value: 'Todos'),
    ValueType<dynamic>(id: 0, value: 'Inactivo'),
    ValueType<dynamic>(id: 1, value: 'Solicitud'),
    ValueType<dynamic>(id: 2, value: 'Aprobado Jefe'),
    ValueType<dynamic>(id: 3, value: 'Observado'),
    ValueType<dynamic>(id: 4, value: 'Aprobado RRHH'),
    ValueType<dynamic>(id: 5, value: 'Rechazado'),
    ValueType<dynamic>(id: 6, value: 'Editado'),
    ValueType<dynamic>(id: 7, value: 'Anulado'),
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
      body: Column(
        children: [
          _buildAppBar(context, user),
          _buildSearchSection(context),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScrollNotification(context);
                return true;
              },
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceM,
                  vertical: AppDimensions.spaceS,
                ),
                itemCount: 50,
                itemBuilder: _buildListItem,
              ),
            ),
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
          child: Row(
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
                        color2: Theme.of(context).textTheme.labelSmall!.color!,
                        fonsizeTitle: FontTokens.caption(context),
                        fonsizeTitle2: FontTokens.body(context),
                        color: Theme.of(context).textTheme.bodyLarge!.color!,
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
                      right: 3,
                      top: 1,
                      child: Container(
                        width: AppDimensions.iconS,
                        height: AppDimensions.iconS,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).primaryColor,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: FontTokens.caption(context),
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
        ),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return AnimatedSize(
      duration: _duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: _showSearch
          ? Container(
              margin: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM),
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
                    filterMore: true,
                    filterActive: _isFilterOpen,
                    onTapFilterMore: _toggleFilter,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isFilterOpen
                        ? _buildFilters(context)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppDimensions.spaceM),
      child: Column(
        children: [
          CustomDropDown<ValueType<dynamic>>(
            color: Theme.of(context).primaryColor,
            colorText: Theme.of(context).textTheme.bodyLarge?.color,
            prefixIcon: true,
            prefixIconValue: 'estado.svg',
            lista: _listEstado,
            value: _selectedEstado,
            valueExtractor: (item) => item,
            textExtractor: (item) => item.value.toString(),
            label: 'Estado',
            onChanged: (value) {
              setState(() => _selectedEstado = value as ValueType<dynamic>?);
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
            initialDateRange: _selectedDateRange ??
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

  Widget _buildListItem(BuildContext context, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: AppDimensions.spaceS),
      padding: EdgeInsets.all(AppDimensions.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            width: AppDimensions.iconL,
            height: AppDimensions.iconL,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              '${assetImgIcon}file.svg',
              width: AppDimensions.iconM,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actividad #${index + 1}',
                  style: TextStyle(
                    fontSize: FontTokens.body(context),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                SizedBox(height: AppDimensions.spaceXS),
                Text(
                  'Descripción de la actividad número ${index + 1} del sistema',
                  style: TextStyle(
                    fontSize: FontTokens.caption(context),
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .color!
                        .withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SvgPicture.asset(
            '${assetImgIcon}arrow_down.svg',
            width: AppDimensions.iconS,
            color: Theme.of(context)
                .textTheme
                .bodyLarge!
                .color!
                .withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}
