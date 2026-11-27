import 'dart:async';

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/notifications/local_notification_service.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/data/datasources/remote/internet_checker.dart';
import 'package:file_cast/data/repositories/remote_auth_repository.dart';
import 'package:file_cast/data/repositories/acquisition_repository_impl.dart';
import 'package:file_cast/data/repositories/connectivity_repository_impl.dart';
import 'package:file_cast/data/repositories/offline_first_requisition_repository.dart';
import 'package:file_cast/data/repositories/remote_requisition_detail_repository.dart';
import 'package:file_cast/data/repositories/requisition_creation_repository_impl.dart';
import 'package:file_cast/data/services/requisition_creation_service.dart';
import 'package:file_cast/data/services/android_acquisition_platform_service.dart';
import 'package:file_cast/data/services/android_evidence_video_thumbnail_service.dart';
import 'package:file_cast/data/services/ios_evidence_video_thumbnail_service.dart';
import 'package:file_cast/data/services/just_audio_playback_service.dart';
import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_background_sync_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
import 'package:file_cast/data/services/evidence_image_thumbnail_service.dart';
import 'package:file_cast/data/services/evidence_offline_sync_service.dart';
import 'package:file_cast/data/services/evidence_preview_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/auth_external_link_service.dart';
import 'package:file_cast/data/services/auth_session_service.dart';
import 'package:file_cast/data/services/auth_sms_code_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/location_service.dart';
import 'package:file_cast/data/services/persisted_evidence_video_thumbnail_service.dart';
import 'package:file_cast/data/services/remote_document_preview_service.dart';
import 'package:file_cast/data/services/requisition_service.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_image_thumbnail_service.dart';
import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:file_cast/ui/core/navigation/app_router.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:file_cast/ui/features/connectivity/view_models/connectivity_view_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class DependencyInjection {
  static List<SingleChildWidget> providers() {
    return [
      Provider<FlutterSecureStorage>(
        create: (_) => const FlutterSecureStorage(),
      ),
      ProxyProvider<FlutterSecureStorage, SecureStorageService>(
        update: (_, storage, previous) => SecureStorageService(storage),
      ),
      ProxyProvider<SecureStorageService, EvidenceCryptoService>(
        update: (_, storage, previous) =>
            EvidenceCryptoService(storage: storage),
      ),
      ProxyProvider<SecureStorageService, LocalEvidenceDatabaseService>(
        update: (_, storage, previous) =>
            LocalEvidenceDatabaseService(storage: storage),
      ),
      Provider<Connectivity>(create: (_) => Connectivity()),
      Provider<InternetChecker>(
        create: (_) => InternetChecker(
          client: http.Client(),
          baseUrl: Config.baseUrl,
        ),
      ),
      ProxyProvider2<Connectivity, InternetChecker, ConnectivityRepository>(
        update: (_, connectivity, checker, previous) =>
            previous ??
            ConnectivityRepositoryImpl(
              connectivity: connectivity,
              internetChecker: checker,
            ),
      ),
      ChangeNotifierProxyProvider<
        ConnectivityRepository,
        ConnectivityViewModel
      >(
        create: (context) => ConnectivityViewModel(
          repository: context.read<ConnectivityRepository>(),
        )..initialize(),
        update: (_, repository, previous) =>
            previous ??
            (ConnectivityViewModel(repository: repository)..initialize()),
      ),
      Provider<LocalNotificationService>(
        create: (_) => LocalNotificationService(),
      ),
      Provider<EvidenceBackgroundSyncService>(
        create: (_) => EvidenceBackgroundSyncService(
          baseUrl: Config.baseUrl,
          authBaseUrl: Config.baseUrlAuth,
        ),
      ),
      ProxyProvider<EvidenceCryptoService, EvidenceDecryptionService>(
        update: (_, crypto, previous) => crypto,
      ),
      ProxyProvider<SecureStorageService, AuthSessionService>(
        update: (_, storage, previous) => AuthSessionService(
          client: http.Client(),
          storage: storage,
          baseUrl: Config.baseUrlAuth,
        ),
      ),
      Provider<AuthExternalLinkService>(
        create: (_) => AuthExternalLinkService(),
      ),
      Provider<AuthSmsCodeService>(create: (_) => AuthSmsCodeService()),
      ProxyProvider4<
        AuthSessionService,
        ConnectivityRepository,
        AuthExternalLinkService,
        AuthSmsCodeService,
        AuthRepository
      >(
        update:
            (
              _,
              sessionService,
              connectivity,
              externalLinkService,
              smsCodeService,
              previous,
            ) => RemoteAuthRepository(
              sessionService: sessionService,
              connectivity: connectivity,
              externalLinkService: externalLinkService,
              smsCodeService: smsCodeService,
            ),
      ),
      ChangeNotifierProvider<AuthSessionController>(
        create: (context) => AuthSessionController(
          authRepository: context.read<AuthRepository>(),
        )..restore(),
      ),
      ProxyProvider3<
        EvidenceDecryptionService,
        LocalEvidenceDatabaseService,
        AuthSessionController,
        EvidenceImageThumbnailService
      >(
        update: (_, decryptionService, database, session, previous) {
          final service = previous is EvidenceImageThumbnailServiceImpl
              ? previous
              : EvidenceImageThumbnailServiceImpl(
                  decryptionService: decryptionService,
                  database: database,
                );
          service.setOwnerId(
            session.isAuthenticated
                ? 'authenticated:${session.user?.id ?? session.user?.numeroDocumento ?? session.user?.usuario ?? ''}'
                : null,
          );
          return service;
        },
      ),
      ProxyProvider2<AuthSessionService, AuthSessionController, Http>(
        update: (_, sessionService, sessionController, previous) => Http(
          client: http.Client(),
          baseUrl: Config.baseUrl,
          userAgent: 'FileCast',
          ip: '',
          tokenProvider: sessionService.getValidAccessToken,
          onUnauthorized: sessionService.refreshTokenIfNeeded,
          onSessionExpired: sessionController.unauthenticated,
        ),
      ),
      ProxyProvider<Http, RequisitionService>(
        update: (_, http, previous) => RequisitionService(http: http),
      ),
      ProxyProvider<Http, RequisitionDetailService>(
        update: (_, http, previous) => RequisitionDetailService(http: http),
      ),
      ProxyProvider2<Http, EvidenceCryptoService, EvidenceKeyExchangeService>(
        update: (_, http, crypto, previous) => EvidenceKeyExchangeService(
          http: http,
          crypto: crypto,
        ),
      ),
      ProxyProvider4<
        RequisitionService,
        RequisitionDetailService,
        LocalEvidenceDatabaseService,
        ConnectivityRepository,
        RequisitionRepository
      >(
        update: (_, service, detailService, database, connectivity, previous) =>
            OfflineFirstRequisitionRepository(
              remote: service,
              detailService: detailService,
              local: database,
              connectivity: connectivity,
            ),
      ),
      Provider<EvidencePickerService>(
        create: (_) => EvidencePickerService(),
      ),
      Provider<AudioPlaybackService>(
        create: (_) => JustAudioPlaybackService(),
      ),
      Provider<RemoteDocumentPreviewService>(
        lazy: false,
        create: (_) {
          const service = RemoteDocumentPreviewService();
          unawaited(service.purgeOfficeViewerCache().catchError((Object _) {}));
          return service;
        },
      ),
      ProxyProvider4<
        Http,
        EvidenceCryptoService,
        RemoteDocumentPreviewService,
        EvidenceKeyExchangeService,
        EvidencePreviewService
      >(
        update: (_, http, crypto, documentPreview, keyExchange, previous) =>
            RemoteEvidencePreviewService(
              http: http,
              crypto: crypto,
              keyExchange: keyExchange,
              documentPreview: documentPreview,
            ),
      ),
      Provider<LocationService>(create: (_) => const LocationService()),
      ProxyProvider6<
        Http,
        LocalEvidenceDatabaseService,
        EvidenceCryptoService,
        EvidenceKeyExchangeService,
        LocalNotificationService,
        EvidenceBackgroundSyncService,
        EvidenceSyncService
      >(
        update:
            (
              context,
              http,
              database,
              crypto,
              keyExchange,
              notifications,
              backgroundScheduler,
              previous,
            ) =>
                previous ??
                (EvidenceSyncService(
                  http: http,
                  database: database,
                  crypto: crypto,
                  keyExchange: keyExchange,
                  notifications: notifications,
                  backgroundScheduler: backgroundScheduler,
                  connectivity: context.read<ConnectivityRepository>(),
                )..start()),
      ),
      ProxyProvider6<
        Http,
        LocalEvidenceDatabaseService,
        EvidenceCryptoService,
        EvidenceKeyExchangeService,
        LocalNotificationService,
        EvidenceBackgroundSyncService,
        EvidenceOfflineSyncService
      >(
        update:
            (
              _,
              http,
              database,
              crypto,
              keyExchange,
              notifications,
              backgroundScheduler,
              previous,
            ) =>
                previous ??
                EvidenceOfflineSyncService(
                  http: http,
                  database: database,
                  crypto: crypto,
                  keyExchange: keyExchange,
                  notifications: notifications,
                  backgroundScheduler: backgroundScheduler,
                ),
      ),
      ProxyProvider6<
        RequisitionDetailService,
        EvidencePickerService,
        EvidenceCryptoService,
        LocalEvidenceDatabaseService,
        EvidenceSyncService,
        EvidenceKeyExchangeService,
        RequisitionDetailRepository
      >(
        update:
            (
              context,
              detailService,
              picker,
              crypto,
              database,
              syncService,
              keyExchange,
              previous,
            ) => RemoteRequisitionDetailRepository(
              detailService: detailService,
              pickerService: picker,
              cryptoService: crypto,
              database: database,
              syncService: syncService,
              keyExchange: keyExchange,
              connectivity: context.read<ConnectivityRepository>(),
              offlineSyncService: context.read<EvidenceOfflineSyncService>(),
            ),
      ),
      ProxyProvider<Http, RequisitionCreationService>(
        update: (_, http, previous) => RequisitionCreationService(http: http),
      ),
      ProxyProvider<RequisitionCreationService, RequisitionCreationRepository>(
        update: (_, service, previous) => RequisitionCreationRepositoryImpl(
          service: service,
          enableFallbackFixtures: false,
        ),
      ),
      Provider<AdbClient>(create: (_) => AdbClient()),
      Provider<EvidenceVideoThumbnailService>(
        create: (context) => PersistedEvidenceVideoThumbnailService(
          platformService: defaultTargetPlatform == TargetPlatform.iOS
              ? IosEvidenceVideoThumbnailService()
              : AndroidEvidenceVideoThumbnailService(
                  adbClient: context.read<AdbClient>(),
                ),
          database: context.read<LocalEvidenceDatabaseService>(),
        ),
      ),
      ProxyProvider<AdbClient, AndroidAcquisitionPlatformService>(
        update: (_, adbClient, previousService) =>
            previousService ??
            AndroidAcquisitionPlatformService(adbClient: adbClient),
      ),
      ProxyProvider4<
        AndroidAcquisitionPlatformService,
        RequisitionDetailRepository,
        RemoteDocumentPreviewService,
        EvidenceSyncService,
        AcquisitionRepository
      >(
        update:
            (
              _,
              platformService,
              detailRepository,
              documentPreviewService,
              syncService,
              previousRepository,
            ) =>
                previousRepository ??
                AcquisitionRepositoryImpl(
                  platformService: platformService,
                  detailRepository: detailRepository,
                  documentPreviewService: documentPreviewService,
                  syncService: syncService,
                ),
      ),
      ProxyProvider<AuthSessionController, GoRouter>(
        update: (_, sessionController, previousRouter) =>
            previousRouter ??
            createAppRouter(authSessionController: sessionController),
      ),
      ChangeNotifierProxyProvider<SecureStorageService, ThemeController>(
        create: (context) => ThemeController(
          storage: context.read<SecureStorageService>(),
          initialDarkMode: true,
        )..loadTheme(),
        update: (_, storage, controller) =>
            controller ??
            (ThemeController(storage: storage, initialDarkMode: true)
              ..loadTheme()),
      ),
    ];
  }
}
