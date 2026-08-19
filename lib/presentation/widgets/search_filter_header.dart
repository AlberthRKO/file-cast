import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/core.dart';
import 'package:file_cast/domain/typedef.dart';
import 'package:file_cast/presentation/widgets/custom_avatar.dart';
import 'package:file_cast/presentation/widgets/custom_drop_down.dart';
import 'package:file_cast/presentation/widgets/custom_heading.dart';
import 'package:file_cast/presentation/widgets/text_form_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchFilterHeader extends StatelessWidget {
  const SearchFilterHeader({
    required this.user,
    required this.countNoti,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onDateRangeChanged,
    required this.listEstado,
    super.key,
    this.isFilterOpen = false,
    this.onToggleFilter,
    this.searchQuery = '',
    this.selectedEstado,
    this.dateRange,
  });

  final dynamic user;
  final int countNoti;
  final void Function(String) onSearchChanged;
  final void Function(dynamic) onFilterChanged;
  final void Function(String?) onDateRangeChanged;
  final List<ValueTipo<dynamic>> listEstado;
  final bool isFilterOpen;
  final VoidCallback? onToggleFilter;
  final String searchQuery;
  final ValueTipo<dynamic>? selectedEstado;
  final DateTimeRange? dateRange;

  @override
  Widget build(BuildContext context) {
    final String userName = (user as dynamic).nombreCompleto?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceM,
            vertical: AppDimensions.spaceS,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUserRow(context, userName),
              SizedBox(height: AppDimensions.spaceM),
              _buildSearchBar(context),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isFilterOpen
                    ? _buildFilters(context)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(BuildContext context, String userName) {
    return Row(
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
                  title2: userName,
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
        _buildNotificationButton(context),
      ],
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Container(
      height: AppDimensions.iconL,
      width: AppDimensions.iconL,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            '${assetImgIcon}notification.svg',
            color: Theme.of(context).textTheme.bodyLarge!.color,
            width: AppDimensions.iconM,
          ),
          if (countNoti > 0)
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
                    countNoti > 9 ? '9+' : countNoti.toString(),
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
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextFieldSearch(
      prefixIcon: 'search.svg',
      labelText: 'Buscar Actividad (descripción)',
      iconHeight: AppDimensions.iconM,
      iconColor: Theme.of(context).primaryColor,
      onChanged: onSearchChanged,
      filterMore: true,
      filterActive: isFilterOpen,
      onTapFilterMore: onToggleFilter,
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppDimensions.spaceM),
      child: Column(
        children: [
          CustomDropDown<ValueTipo<dynamic>>(
            color: Theme.of(context).primaryColor,
            colorText: Theme.of(context).textTheme.bodyLarge!.color,
            prefixIcon: true,
            prefixIconValue: 'estado.svg',
            lista: listEstado,
            value: selectedEstado,
            valueExtractor: (item) => item,
            textExtractor: (item) => item.value.toString(),
            label: 'Estado',
            onChanged: onFilterChanged,
          ),
          SizedBox(height: AppDimensions.spaceM),
          DateRangePickerFormCustom(
            onChanged: onDateRangeChanged,
            prefixIcon: 'calendar.svg',
            labelText: 'Fecha inicio - Fecha fin',
            initialDateRange: dateRange,
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
}
