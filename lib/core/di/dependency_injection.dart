import 'package:file_cast/core/adb/adb_client.dart';
import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/data/repositories/in_memory_auth_repository.dart';
import 'package:file_cast/data/repositories/acquisition_repository_impl.dart';
import 'package:file_cast/data/repositories/in_memory_requisition_repository.dart';
import 'package:file_cast/data/repositories/in_memory_requisition_detail_repository.dart';
import 'package:file_cast/data/repositories/requisition_creation_repository_impl.dart';
import 'package:file_cast/data/services/requisition_creation_service.dart';
import 'package:file_cast/data/services/android_acquisition_platform_service.dart';
import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/remote_document_preview_service.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
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
        update: (_, storage, _) => SecureStorageService(storage),
      ),
      Provider<Http>(
        create: (_) => Http(
          client: http.Client(),
          baseUrl: Config.baseUrl,
          userAgent: 'FileCast',
          ip: '',
        ),
      ),
      Provider<AuthRepository>(
        create: (_) => InMemoryAuthRepository(),
      ),
      Provider<RequisitionRepository>(
        create: (_) => const InMemoryRequisitionRepository(),
      ),
      Provider<EvidencePickerService>(
        create: (_) => EvidencePickerService(),
      ),
      Provider<RemoteDocumentPreviewService>(
        create: (_) => const RemoteDocumentPreviewService(),
      ),
      Provider<RequisitionDetailRepository>(
        create: (context) => InMemoryRequisitionDetailRepository(
          pickerService: context.read<EvidencePickerService>(),
        ),
      ),
      ProxyProvider<Http, RequisitionCreationService>(
        update: (_, http, _) => RequisitionCreationService(http: http),
      ),
      ProxyProvider<RequisitionCreationService, RequisitionCreationRepository>(
        update: (_, service, _) => RequisitionCreationRepositoryImpl(
          service: service,
        ),
      ),
      Provider<AdbClient>(create: (_) => AdbClient()),
      ProxyProvider<AdbClient, AndroidAcquisitionPlatformService>(
        update: (_, adbClient, previousService) =>
            previousService ??
            AndroidAcquisitionPlatformService(adbClient: adbClient),
      ),
      ProxyProvider3<
        AndroidAcquisitionPlatformService,
        RequisitionDetailRepository,
        RemoteDocumentPreviewService,
        AcquisitionRepository
      >(
        update:
            (
              _,
              platformService,
              detailRepository,
              documentPreviewService,
              previousRepository,
            ) =>
                previousRepository ??
                AcquisitionRepositoryImpl(
                  platformService: platformService,
                  detailRepository: detailRepository,
                  documentPreviewService: documentPreviewService,
                ),
      ),
      ChangeNotifierProvider<AuthSessionController>(
        create: (_) => AuthSessionController(),
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
