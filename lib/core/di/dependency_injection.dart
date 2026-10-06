import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/data/repositories/remote_auth_repository.dart';
import 'package:file_cast/data/repositories/acquisition_repository_impl.dart';
import 'package:file_cast/data/repositories/remote_requisition_repository.dart';
import 'package:file_cast/data/repositories/remote_requisition_detail_repository.dart';
import 'package:file_cast/data/repositories/requisition_creation_repository_impl.dart';
import 'package:file_cast/data/services/requisition_creation_service.dart';
import 'package:file_cast/data/services/android_acquisition_platform_service.dart';
import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_preview_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/auth_session_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/location_service.dart';
import 'package:file_cast/data/services/remote_document_preview_service.dart';
import 'package:file_cast/data/services/requisition_service.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/ui/core/navigation/app_router.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      ProxyProvider<EvidenceCryptoService, EvidenceDecryptionService>(
        update: (_, crypto, previous) => crypto,
      ),
      ProxyProvider<SecureStorageService, AuthSessionService>(
        update: (_, storage, previous) => AuthSessionService(
          client: http.Client(),
          storage: storage,
          baseUrl: Config.baseUrl,
        ),
      ),
      ProxyProvider<AuthSessionService, AuthRepository>(
        update: (_, sessionService, previous) => RemoteAuthRepository(
          sessionService: sessionService,
        ),
      ),
      ChangeNotifierProvider<AuthSessionController>(
        create: (context) => AuthSessionController(
          authRepository: context.read<AuthRepository>(),
        )..restore(),
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
      ProxyProvider<RequisitionService, RequisitionRepository>(
        update: (_, service, previous) => RemoteRequisitionRepository(
          service: service,
        ),
      ),
      ProxyProvider<Http, RequisitionDetailService>(
        update: (_, http, previous) => RequisitionDetailService(http: http),
      ),
      Provider<EvidencePickerService>(
        create: (_) => EvidencePickerService(),
      ),
      Provider<RemoteDocumentPreviewService>(
        create: (_) => const RemoteDocumentPreviewService(),
      ),
      ProxyProvider3<
        Http,
        EvidenceCryptoService,
        RemoteDocumentPreviewService,
        EvidencePreviewService
      >(
        update: (_, http, crypto, documentPreview, previous) =>
            RemoteEvidencePreviewService(
              http: http,
              crypto: crypto,
              documentPreview: documentPreview,
            ),
      ),
      Provider<LocationService>(create: (_) => const LocationService()),
      ProxyProvider3<
        Http,
        LocalEvidenceDatabaseService,
        EvidenceCryptoService,
        EvidenceSyncService
      >(
        update: (_, http, database, crypto, previous) => EvidenceSyncService(
          http: http,
          database: database,
          crypto: crypto,
        )..start(),
      ),
      ProxyProvider5<
        RequisitionDetailService,
        EvidencePickerService,
        EvidenceCryptoService,
        LocalEvidenceDatabaseService,
        EvidenceSyncService,
        RequisitionDetailRepository
      >(
        update:
            (
              _,
              detailService,
              picker,
              crypto,
              database,
              syncService,
              previous,
            ) => RemoteRequisitionDetailRepository(
              detailService: detailService,
              pickerService: picker,
              cryptoService: crypto,
              database: database,
              syncService: syncService,
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
