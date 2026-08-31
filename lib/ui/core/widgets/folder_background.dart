import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _FolderBackgroundStyle { stacked, panel }

class FolderBackground extends StatelessWidget {
  const FolderBackground.stacked({
    required this.child,
    required this.frontColor,
    required this.middleColor,
    required this.backColor,
    required this.highlightColor,
    required this.compactHeight,
    super.key,
  }) : _style = _FolderBackgroundStyle.stacked,
       showDecoration = true;

  const FolderBackground.panel({
    required this.child,
    required this.frontColor,
    required this.showDecoration,
    super.key,
  }) : _style = _FolderBackgroundStyle.panel,
       middleColor = null,
       backColor = null,
       highlightColor = null,
       compactHeight = false;

  static const _asset = 'assets/images/icons/folder.svg';
  static const _assetAspectRatio = 667 / 600;

  final Widget child;
  final Color frontColor;
  final Color? middleColor;
  final Color? backColor;
  final Color? highlightColor;
  final bool compactHeight;
  final bool showDecoration;
  final _FolderBackgroundStyle _style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (_style) {
          _FolderBackgroundStyle.stacked => _buildStacked(constraints),
          _FolderBackgroundStyle.panel => _buildPanel(constraints),
        };
      },
    );
  }

  Widget _buildStacked(BoxConstraints constraints) {
    final bandHeight = (constraints.maxHeight * (compactHeight ? 0.08 : 0.12))
        .clamp(28.0, 96.0)
        .toDouble();

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (!compactHeight) ...[
          _FolderLayer(
            bottom: bandHeight * 3.2,
            color: highlightColor!,
            width: constraints.maxWidth,
          ),
          _FolderLayer(
            bottom: bandHeight * 2.3,
            color: backColor!,
            width: constraints.maxWidth,
          ),
        ],
        _FolderLayer(
          bottom: bandHeight * (compactHeight ? 1.15 : 1.4),
          color: middleColor!,
          width: constraints.maxWidth,
        ),
        _FolderLayer(
          bottom: bandHeight * (compactHeight ? 0.3 : 0.5),
          color: frontColor,
          width: constraints.maxWidth,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: bandHeight,
          child: ColoredBox(color: frontColor),
        ),
        child,
      ],
    );
  }

  Widget _buildPanel(BoxConstraints constraints) {
    final folderHeight = constraints.maxWidth / _assetAspectRatio;
    final bodyTop = folderHeight * 0.17;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          top: showDecoration ? bodyTop : 0,
          child: ColoredBox(color: frontColor),
        ),
        if (showDecoration)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: folderHeight,
            child: _FolderShape(
              color: frontColor,
              width: constraints.maxWidth,
            ),
          ),
        child,
      ],
    );
  }
}

class _FolderLayer extends StatelessWidget {
  const _FolderLayer({
    required this.bottom,
    required this.color,
    required this.width,
  });

  final double bottom;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      height: width / FolderBackground._assetAspectRatio,
      child: _FolderShape(color: color, width: width),
    );
  }
}

class _FolderShape extends StatelessWidget {
  const _FolderShape({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          width: width,
          height: width / FolderBackground._assetAspectRatio,
          child: SvgPicture.asset(
            FolderBackground._asset,
            fit: BoxFit.fill,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
