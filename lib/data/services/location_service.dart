import 'dart:async';

import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  const LocationService();

  Future<GeoPoint> captureCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceException(
        'Activa la ubicación del dispositivo para capturar el lugar del hecho.',
      );
    }

    final permission = await Permission.locationWhenInUse.status;
    final resolvedPermission = permission.isDenied
        ? await Permission.locationWhenInUse.request()
        : permission;

    if (!resolvedPermission.isGranted) {
      throw LocationServiceException(
        resolvedPermission.isPermanentlyDenied
            ? 'El permiso de ubicación está bloqueado. Habilítalo desde los ajustes del dispositivo.'
            : 'Se necesita permiso de ubicación para capturar el lugar del hecho.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationServiceException(
        'No se pudo obtener la ubicación a tiempo. Intenta nuevamente.',
      );
    } on LocationServiceDisabledException {
      throw const LocationServiceException(
        'Activa la ubicación del dispositivo para continuar.',
      );
    } on PermissionDeniedException {
      throw const LocationServiceException(
        'El permiso de ubicación fue denegado.',
      );
    } catch (_) {
      throw const LocationServiceException(
        'No se pudo obtener la ubicación actual. Intenta nuevamente.',
      );
    }
  }
}

final class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
