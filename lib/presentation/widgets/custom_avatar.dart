import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_cast/core/constants/complemento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:path_provider/path_provider.dart';

class CustomAvatar extends StatelessWidget {
  const CustomAvatar({
    required this.width,
    required this.height,
    required this.perfil,
    required this.child,
    super.key,
    this.border = 2.0,
    this.borderColor = const Color(0xfff4f6f8),
  });

  final double width;
  final double height;
  final double border;
  final Color borderColor;
  final String perfil;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(perfil),
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: border,
        ),
      ),
      child: child,
    );
  }
}

class CustomMSAvatar extends StatefulWidget {
  const CustomMSAvatar({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius = 100.0,
    this.msFileId,
  });

  final double width;
  final double height;
  final double borderRadius;
  final String? msFileId;

  // Método estático para generar la clave de caché
  static String _generateCacheKey(String? msFileId) {
    return 'ms_avatar_${msFileId ?? 'default'}';
  }

  @override
  State<CustomMSAvatar> createState() => _CustomMSAvatarState();
}

class _CustomMSAvatarState extends State<CustomMSAvatar> {
  Uint8List? _profileImage;
  String? _cacheKey;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cacheKey = CustomMSAvatar._generateCacheKey(widget.msFileId);
    _loadCachedImage();
  }

  Future<void> _loadCachedImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$_cacheKey';
    final file = File(imagePath);

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _profileImage = bytes;
        });
      }
      // No necesitamos fetchImage si la imagen está en caché
    } else {
      await _fetchImage();
    }
  }

  Future<void> _cacheImage(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$_cacheKey';
    final file = File(imagePath);
    await file.writeAsBytes(bytes);
  }

  Future<void> _fetchImage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget getUserProfileImage() {
      //if (_isLoading) return _buildLoadingIndicator();
      if (_profileImage != null) {
        try {
          return Image.memory(
            _profileImage!,
            fit: BoxFit.cover,
            width: widget.width,
            height: widget.height,
          );
        } catch (e) {
          print('Error al mostrar la imagen: $e');
          return _buildLoadingIndicator();
        }
      }
      return SvgPicture.asset(
        '${assetImg}profile.svg',
        fit: BoxFit.cover,
        width: 500,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: getUserProfileImage(),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}

class CustomMSAvatar2 extends StatefulWidget {
  const CustomMSAvatar2({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius = 100.0,
    this.msFileId,
  });

  final double width;
  final double height;
  final double borderRadius;
  final String? msFileId;

  static String _generateCacheKey(String? msFileId) {
    return 'ms_avatar_${msFileId ?? 'default'}';
  }

  @override
  State<CustomMSAvatar2> createState() => _CustomMSAvatar2State();
}

class _CustomMSAvatar2State extends State<CustomMSAvatar2> {
  Uint8List? _profileImage;
  String? _currentCacheKey;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.msFileId);
  }

  @override
  void didUpdateWidget(CustomMSAvatar2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msFileId != widget.msFileId) {
      _loadImage(widget.msFileId);
    }
  }

  Future<void> _loadImage(String? msFileId) async {
    // Si msFileId es nulo o vacío, muestra el widget de error/por defecto
    if (msFileId == null || msFileId.isEmpty) {
      if (mounted) {
        setState(() {
          _profileImage =
              null; // Reinicia la imagen para que se muestre el widget por defecto
          _isLoading = false;
          _currentCacheKey = CustomMSAvatar2._generateCacheKey(msFileId);
        });
      }
      return; // Sal del método, no hay nada que cargar
    }

    // El resto de la lógica de carga y caché de la imagen, como la tenías
    final newCacheKey = CustomMSAvatar2._generateCacheKey(msFileId);
    if (newCacheKey == _currentCacheKey) return;

    // ... (el resto de tu lógica para cargar la imagen desde caché o red)
    _currentCacheKey = newCacheKey;
    _profileImage = null;

    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$_currentCacheKey';
    final file = File(imagePath);

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _profileImage = bytes;
        });
      }
    } else {
      await _fetchImage(msFileId);
    }
  }

  Future<void> _cacheImage(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$_currentCacheKey';
    final file = File(imagePath);
    await file.writeAsBytes(bytes);
  }

  Future<void> _fetchImage(String? msFileId) async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget getUserProfileImage() {
      // 1. Si la imagen está lista, la mostramos.
      if (_profileImage != null) {
        try {
          return Image.memory(
            _profileImage!,
            fit: BoxFit.cover,
            width: widget.width,
            height: widget.height,
            errorBuilder: (context, error, stackTrace) {
              // Si la imagen no se puede decodificar, mostramos el error.
              return _buildErrorWidget();
            },
          );
        } catch (e) {
          // Si hay una excepción al crear el widget, mostramos el error.
          return _buildErrorWidget();
        }
      }

      // 2. Si la imagen no está lista y el widget está cargando, mostramos el indicador.
      // La variable _isLoading debe ser gestionada en tus métodos _loadImage y _fetchImage.
      if (_isLoading) {
        return _buildLoadingIndicator2();
      }

      // 3. En cualquier otro caso (la carga ha terminado pero _profileImage es nulo),
      // se asume que hubo un error y mostramos el widget de error.
      return _buildErrorWidget();
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: getUserProfileImage(),
      ),
    );
  }

  Widget _buildLoadingIndicator2() {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).primaryColor,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(
                  context,
                ).textTheme.bodyLarge?.color?.withOpacity(0.2) ??
                Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        '${assetImg}profile.svg',
        width:
            widget.width, // Asegúrate de que el tamaño sea relativo a la imagen
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.person,
        size: widget.width * 0.6,
        color: Colors.grey[400],
      ),
    );
  }
}

class CustomMsV2Photo extends StatefulWidget {
  const CustomMsV2Photo({
    required this.width,
    required this.height,
    required this.msFileId,
    super.key,
    this.borderRadius = 100.0,
  });

  final double width;
  final double height;
  final double borderRadius;
  final String msFileId;

  @override
  State<CustomMsV2Photo> createState() => _CustomMsV2PhotoState();
}

class _CustomMsV2PhotoState extends State<CustomMsV2Photo> {
  bool _isLoading = false;

  String? urlPhoto;

  @override
  void initState() {
    super.initState();
    _fetchImage(widget.msFileId);
  }

  Future<void> _fetchImage(String msFileId) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
  }

  static final customCacheManager = CacheManager(
    Config(
      'customCacheKey',
      stalePeriod: const Duration(days: 15),
      maxNrOfCacheObjects: 150,
    ),
  );

  Widget _buildPlaceholder() {
    return Center(
      child: SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(
                  context,
                ).textTheme.bodyLarge?.color?.withOpacity(0.2) ??
                Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        '${assetImg}profile.svg',
        width: 90,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || urlPhoto == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: _buildPlaceholder(),
      );
    }

    if (urlPhoto!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: _buildErrorWidget(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: ColoredBox(
        color: Theme.of(context).cardColor,
        child: CachedNetworkImage(
          cacheManager: customCacheManager,
          imageUrl: urlPhoto!,
          fit: BoxFit.cover,
          width: widget.width,
          height: widget.height,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildErrorWidget(),
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 300),
          memCacheHeight:
              (widget.height * MediaQuery.of(context).devicePixelRatio).toInt(),
          memCacheWidth:
              (widget.width * MediaQuery.of(context).devicePixelRatio).toInt(),
        ),
      ),
    );
  }
}
