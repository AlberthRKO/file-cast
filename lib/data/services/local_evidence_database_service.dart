import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Persistencia local cifrada para evidencias y operaciones pendientes.
/// Guarda metadatos FCE y una caché acotada de miniaturas dentro de SQLCipher.
/// Nunca guarda el archivo original en claro.
class LocalEvidenceDatabaseService {
  LocalEvidenceDatabaseService({required SecureStorageService storage})
    : _storage = storage;

  static const _lockPollInterval = Duration(milliseconds: 100);
  static const _defaultLockWaitTimeout = Duration(seconds: 30);
  // Todas las secciones protegidas son transacciones SQLite cortas. Una lease
  // menor al tiempo máximo de espera permite recuperar en la misma operación
  // el lock si otro isolate murió antes de ejecutar su `finally`.
  static const _lockLeaseDuration = Duration(seconds: 10);
  static const _staleClaimTimeout = Duration(minutes: 15);
  static const _databaseKeyName = 'file_cast_evidence_database_key_v1';
  static const _databaseName = 'file_cast_evidence_v1.db';
  static const _documentsPathPrefix = 'app-documents:';

  Future<String> _storedEncryptedPath(String path) async {
    if (!Platform.isIOS) return path;
    final documentsPath = await getDatabasesPath();
    final prefix = '$documentsPath/';
    if (!path.startsWith(prefix)) return path;
    return '$_documentsPathPrefix${path.substring(prefix.length)}';
  }

  LocalEvidenceRecord _recordFromRow(
    Map<String, Object?> row,
    String? documentsPath,
  ) {
    final storedPath = row['ruta_cifrada'] as String;
    String? relativePath;
    if (documentsPath != null) {
      if (storedPath.startsWith(_documentsPathPrefix)) {
        relativePath = storedPath.substring(_documentsPathPrefix.length);
      } else if (storedPath.contains('/Containers/Data/Application/')) {
        // Las versiones anteriores persistían la ruta absoluta del contenedor.
        // iPadOS puede asignar otro UUID al actualizar la aplicación.
        const marker = '/Documents/';
        final markerIndex = storedPath.lastIndexOf(marker);
        if (markerIndex >= 0) {
          relativePath = storedPath.substring(markerIndex + marker.length);
        }
      }
    }
    if (documentsPath == null ||
        relativePath == null ||
        relativePath.isEmpty ||
        relativePath.startsWith('/') ||
        relativePath.split('/').contains('..')) {
      return LocalEvidenceRecord.fromMap(row);
    }
    return LocalEvidenceRecord.fromMap({
      ...row,
      'ruta_cifrada': '$documentsPath/$relativePath',
    });
  }

  Future<List<LocalEvidenceRecord>> _recordsFromRows(
    List<Map<String, Object?>> rows,
  ) async {
    final documentsPath = Platform.isIOS ? await getDatabasesPath() : null;
    return rows
        .map((row) => _recordFromRow(row, documentsPath))
        .toList(growable: false);
  }

  final SecureStorageService _storage;
  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final current = _database;
    try {
      if (current != null && current.isOpen) return current;
    } on Object {
      // El engine de WorkManager puede haber cerrado el handle nativo. Se
      // descarta la referencia para abrirlo de nuevo en la siguiente línea.
    }
    _database = null;

    final opening = _openingDatabase;
    if (opening != null) return opening;

    final operation = _openDatabase();
    _openingDatabase = operation;
    try {
      final opened = await operation;
      _database = opened;
      return opened;
    } finally {
      if (identical(_openingDatabase, operation)) {
        _openingDatabase = null;
      }
    }
  }

  Future<Database> _openDatabase() async {
    final key = await _databaseKey();
    final migrationAccountId =
        await _storage.getAuthenticatedAccountId() ?? 'legacy-unassigned';
    final path = '${await getDatabasesPath()}/$_databaseName';
    try {
      return await openDatabase(
        path,
        password: key,
        version: 10,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE evidencias_locales (
              id TEXT PRIMARY KEY,
              account_id TEXT NOT NULL,
              requisa_id TEXT NOT NULL,
              sesion_id TEXT NOT NULL,
              nombre_original TEXT NOT NULL,
              nombre_mostrado TEXT,
              mime_type TEXT NOT NULL,
              tipo TEXT NOT NULL,
              metodo_adquisicion TEXT NOT NULL,
              ruta_cifrada TEXT NOT NULL,
              tamano_plano INTEGER NOT NULL,
              tamano_cifrado INTEGER NOT NULL,
              hash_plano TEXT NOT NULL,
              hash_cifrado TEXT NOT NULL,
              algoritmo_cifrado TEXT NOT NULL,
              version_cifrado INTEGER NOT NULL,
              hash_aad TEXT NOT NULL,
              clave_envuelta TEXT NOT NULL,
              version_clave INTEGER NOT NULL,
              estado TEXT NOT NULL,
              ms_archivo_id TEXT,
              ruta_origen TEXT,
              sujeto_person_ids TEXT NOT NULL DEFAULT '[]',
              client_operation_id TEXT NOT NULL,
              creado_at TEXT NOT NULL,
              actualizado_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE outbox_evidencias (
              operation_id TEXT PRIMARY KEY,
              evidencia_id TEXT NOT NULL UNIQUE,
              estado TEXT NOT NULL,
              intentos INTEGER NOT NULL DEFAULT 0,
              ultimo_error TEXT,
              reintento_automatico INTEGER NOT NULL DEFAULT 1,
              actualizado_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX evidencias_locales_requisa_idx '
            'ON evidencias_locales(account_id, requisa_id, creado_at)',
          );
          await db.execute(
            'CREATE INDEX outbox_evidencias_estado_idx '
            'ON outbox_evidencias(estado, actualizado_at)',
          );
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_locks (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              owner TEXT NOT NULL,
              expires_at INTEGER NOT NULL
            )
          ''');
          await _createOfflineTables(db);
          await _createImageThumbnailCache(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await _ensureColumn(
              db,
              table: 'evidencias_locales',
              column: 'metodo_adquisicion',
              definition: "TEXT NOT NULL DEFAULT 'IMPORTED_FILE'",
            );
          }
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS sync_locks (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                owner TEXT NOT NULL,
                expires_at INTEGER NOT NULL
              )
            ''');
          }
          // La migración anterior podía haber agregado la columna y fallar
          // antes de actualizar user_version. Nunca repetir un ALTER TABLE
          // ciego: WorkManager y la app pueden reabrir la misma base después
          // de una actualización o una migración interrumpida.
          await _ensureColumn(
            db,
            table: 'outbox_evidencias',
            column: 'reintento_automatico',
            definition: 'INTEGER NOT NULL DEFAULT 1',
          );
          if (oldVersion < 6) {
            await _ensureColumn(
              db,
              table: 'evidencias_locales',
              column: 'nombre_mostrado',
              definition: 'TEXT',
            );
          }
          if (oldVersion < 7) {
            await _ensureColumn(
              db,
              table: 'evidencias_locales',
              column: 'sujeto_person_ids',
              definition: "TEXT NOT NULL DEFAULT '[]'",
            );
          }
          if (oldVersion < 8) await _createOfflineTables(db);
          if (oldVersion < 9) {
            await _ensureColumn(
              db,
              table: 'evidencias_locales',
              column: 'account_id',
              definition: 'TEXT',
            );
            await db.update(
              'evidencias_locales',
              {'account_id': migrationAccountId},
              where: 'account_id IS NULL OR account_id = ?',
              whereArgs: [''],
            );
            await db.execute('''
              CREATE INDEX IF NOT EXISTS evidencias_locales_account_idx
              ON evidencias_locales(account_id, requisa_id, creado_at)
            ''');
          }
          if (oldVersion < 10) await _createImageThumbnailCache(db);
        },
      );
    } on Object catch (error, stackTrace) {
      throw LocalEvidenceDatabaseException(
        message: _databaseErrorMessage(error),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _createOfflineTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS requisition_list_cache (
        account_id TEXT NOT NULL,
        requisition_id TEXT NOT NULL,
        case_name TEXT NOT NULL,
        registered_at TEXT NOT NULL,
        status TEXT NOT NULL,
        image_count INTEGER NOT NULL,
        video_count INTEGER NOT NULL,
        is_synchronized INTEGER NOT NULL,
        cud TEXT,
        subject_name TEXT,
        latitude REAL,
        longitude REAL,
        location_label TEXT,
        document_count INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL,
        PRIMARY KEY (account_id, requisition_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS requisition_list_cache_account_idx
      ON requisition_list_cache(account_id, registered_at DESC)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS requisition_detail_cache (
        account_id TEXT NOT NULL,
        requisition_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        PRIMARY KEY (account_id, requisition_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_acquisition_sessions (
        local_id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        requisition_id TEXT NOT NULL,
        remote_id TEXT,
        source_platform TEXT NOT NULL,
        transport TEXT NOT NULL,
        client_operation_id TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS local_sessions_requisition_idx
      ON local_acquisition_sessions(account_id, requisition_id, status)
    ''');
  }

  Future<void> _createImageThumbnailCache(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS image_thumbnail_cache (
        account_id TEXT NOT NULL,
        cache_key TEXT NOT NULL,
        png_bytes BLOB NOT NULL,
        byte_length INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (account_id, cache_key)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS image_thumbnail_cache_age_idx
      ON image_thumbnail_cache(account_id, created_at)
    ''');
  }

  Future<String> _requiredAccountId() async {
    final accountId = await _storage.getAuthenticatedAccountId();
    if (accountId == null || accountId.isEmpty) {
      throw StateError(
        'No existe una cuenta autenticada para el trabajo offline.',
      );
    }
    return accountId;
  }

  Future<String> currentAccountId() => _requiredAccountId();

  Future<Uint8List?> readImageThumbnail({
    required String accountId,
    required String cacheKey,
  }) async {
    final rows = await (await database).query(
      'image_thumbnail_cache',
      columns: ['png_bytes'],
      where: 'account_id = ? AND cache_key = ?',
      whereArgs: [accountId, cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['png_bytes'];
    if (value is Uint8List) return value;
    return value is List<int> ? Uint8List.fromList(value) : null;
  }

  Future<void> saveImageThumbnail({
    required String accountId,
    required String cacheKey,
    required Uint8List bytes,
  }) async {
    const maximumBytes = 40 * 1024 * 1024;
    const maximumItems = 128;
    if (bytes.isEmpty || bytes.lengthInBytes > 2 * 1024 * 1024) return;
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'image_thumbnail_cache',
        {
          'account_id': accountId,
          'cache_key': cacheKey,
          'png_bytes': bytes,
          'byte_length': bytes.lengthInBytes,
          'created_at': DateTime.now().toUtc().microsecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final rows = await txn.query(
        'image_thumbnail_cache',
        columns: ['cache_key', 'byte_length'],
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'created_at DESC',
      );
      var retainedBytes = 0;
      for (var index = 0; index < rows.length; index++) {
        final length = rows[index]['byte_length'] as int;
        if (index < maximumItems && retainedBytes + length <= maximumBytes) {
          retainedBytes += length;
          continue;
        }
        await txn.delete(
          'image_thumbnail_cache',
          where: 'account_id = ? AND cache_key = ?',
          whereArgs: [accountId, rows[index]['cache_key']],
        );
      }
    });
  }

  Future<void> saveRequisitionPage({
    required List<LocalRequisitionCacheRecord> records,
    String? accountId,
  }) async {
    if (records.isEmpty) return;
    final ownerAccountId = accountId ?? await _requiredAccountId();
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final record in records) {
        await txn.insert(
          'requisition_list_cache',
          record.toMap(accountId: ownerAccountId, cachedAt: now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceRequisitionCatalog({
    required List<LocalRequisitionCacheRecord> records,
    String? accountId,
  }) async {
    final ownerAccountId = accountId ?? await _requiredAccountId();
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final incomingIds = records.map((record) => record.id).toSet();
      final cachedDetails = await txn.query(
        'requisition_detail_cache',
        columns: ['requisition_id'],
        where: 'account_id = ?',
        whereArgs: [ownerAccountId],
      );
      for (final row in cachedDetails) {
        final requisitionId = row['requisition_id']?.toString() ?? '';
        if (incomingIds.contains(requisitionId)) continue;
        await txn.delete(
          'requisition_detail_cache',
          where: 'account_id = ? AND requisition_id = ?',
          whereArgs: [ownerAccountId, requisitionId],
        );
      }
      await txn.delete(
        'requisition_list_cache',
        where: 'account_id = ?',
        whereArgs: [ownerAccountId],
      );
      for (final record in records) {
        await txn.insert(
          'requisition_list_cache',
          record.toMap(accountId: ownerAccountId, cachedAt: now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<LocalRequisitionCacheRecord>> cachedRequisitions() async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final rows = await db.query(
      'requisition_list_cache',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'registered_at DESC',
    );
    return rows
        .map(LocalRequisitionCacheRecord.fromMap)
        .toList(growable: false);
  }

  Future<void> saveRequisitionDetailSnapshot({
    required String requisitionId,
    required String payloadJson,
    String? accountId,
  }) async {
    final ownerAccountId = accountId ?? await _requiredAccountId();
    final db = await database;
    await db.insert(
      'requisition_detail_cache',
      {
        'account_id': ownerAccountId,
        'requisition_id': requisitionId,
        'payload_json': payloadJson,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<String>> cachedDetailRequisitionIds({String? accountId}) async {
    final ownerAccountId = accountId ?? await _requiredAccountId();
    final db = await database;
    final rows = await db.query(
      'requisition_detail_cache',
      columns: ['requisition_id'],
      where: 'account_id = ?',
      whereArgs: [ownerAccountId],
    );
    return rows
        .map((row) => row['requisition_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<String?> requisitionDetailSnapshot(String requisitionId) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final rows = await db.query(
      'requisition_detail_cache',
      columns: ['payload_json'],
      where: 'account_id = ? AND requisition_id = ?',
      whereArgs: [accountId, requisitionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['payload_json'] as String?;
  }

  Future<LocalAcquisitionSessionRecord> ensureLocalAcquisitionSession({
    required String requisitionId,
    required String sourcePlatform,
    required String transport,
  }) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final existing = await db.query(
      'local_acquisition_sessions',
      where: 'account_id = ? AND requisition_id = ? AND status IN (?, ?)',
      whereArgs: [accountId, requisitionId, 'PENDING', 'REMOTE'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return LocalAcquisitionSessionRecord.fromMap(existing.single);
    }

    final now = DateTime.now().toUtc();
    final localId = 'local-session-${_uuid()}';
    final record = LocalAcquisitionSessionRecord(
      localId: localId,
      requisitionId: requisitionId,
      sourcePlatform: sourcePlatform,
      transport: transport,
      clientOperationId: 'session-${_uuid()}',
      status: 'PENDING',
      createdAt: now,
    );
    await db.insert(
      'local_acquisition_sessions',
      record.toMap(accountId: accountId),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return record;
  }

  Future<LocalAcquisitionSessionRecord?> localAcquisitionSession(
    String localId,
  ) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final rows = await db.query(
      'local_acquisition_sessions',
      where: 'account_id = ? AND local_id = ?',
      whereArgs: [accountId, localId],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LocalAcquisitionSessionRecord.fromMap(rows.single);
  }

  Future<LocalAcquisitionSessionRecord?> activeLocalAcquisitionSession(
    String requisitionId,
  ) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final rows = await db.query(
      'local_acquisition_sessions',
      where: 'account_id = ? AND requisition_id = ? AND status IN (?, ?)',
      whereArgs: [accountId, requisitionId, 'PENDING', 'REMOTE'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LocalAcquisitionSessionRecord.fromMap(rows.single);
  }

  Future<void> markLocalSessionRemote({
    required String localId,
    required String remoteId,
  }) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    await db.update(
      'local_acquisition_sessions',
      {
        'remote_id': remoteId,
        'status': 'REMOTE',
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'account_id = ? AND local_id = ?',
      whereArgs: [accountId, localId],
    );
  }

  Future<void> markLocalSessionError({
    required String localId,
    required String message,
  }) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    await db.update(
      'local_acquisition_sessions',
      {
        'last_error': message.length > 512
            ? message.substring(0, 512)
            : message,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'account_id = ? AND local_id = ?',
      whereArgs: [accountId, localId],
    );
  }

  Future<void> markLocalSessionClosed(String localId) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    await db.update(
      'local_acquisition_sessions',
      {
        'status': 'CLOSED',
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'account_id = ? AND local_id = ?',
      whereArgs: [accountId, localId],
    );
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any(
      (item) => item['name']?.toString() == column,
    );
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  String _databaseErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('SqfliteSqlCipherOpenDatabaseOptions') ||
        raw.contains('SqfliteOpenDatabaseOptions')) {
      return 'La base local cifrada no pudo abrirse por una incompatibilidad '
          'del motor SQLite. Actualiza la aplicación y vuelve a intentar; '
          'la evidencia remota no se eliminó.';
    }
    final normalized = raw.toLowerCase();
    if (normalized.contains('database_close') ||
        normalized.contains('database is closed')) {
      return 'La base local se cerró durante la sincronización. Vuelve a '
          'intentarlo; la evidencia no se marcó como sincronizada.';
    }
    return raw.replaceFirst('Bad state: ', '').trim();
  }

  Future<void> saveEvidence(LocalEvidenceRecord evidence) async {
    // Guardar una captura o un video es una transacción local corta. No debe
    // esperar el lock de sincronización, porque el worker puede conservarlo
    // mientras realiza una subida de red. SQLite ya serializa esta escritura
    // con sus propias transacciones y la outbox queda atómica.
    final accountId = await _requiredAccountId();
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final storedPath = await _storedEncryptedPath(evidence.encryptedPath);
    await db.transaction((txn) async {
      await txn.insert(
        'evidencias_locales',
        {
          ...evidence.toMap(),
          'ruta_cifrada': storedPath,
          'account_id': accountId,
          'actualizado_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'outbox_evidencias',
        {
          'operation_id': evidence.clientOperationId,
          'evidencia_id': evidence.id,
          'estado': 'PENDIENTE',
          'intentos': 0,
          'reintento_automatico': 1,
          'actualizado_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  /// Persiste una evidencia que ya existe en el backend.
  ///
  /// No crea una operación pendiente de subida: el contenido remoto ya fue
  /// confirmado por file-cast-back y solo se está reconstruyendo la copia FCE
  /// local para uso offline.
  Future<void> saveRecoveredEvidence(LocalEvidenceRecord evidence) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final storedPath = await _storedEncryptedPath(evidence.encryptedPath);
    await db.transaction((txn) async {
      await txn.insert(
        'evidencias_locales',
        {
          ...evidence.toMap(),
          'ruta_cifrada': storedPath,
          'account_id': accountId,
          'estado': 'SINCRONIZADA',
          'actualizado_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Si existiera una operación anterior para la misma evidencia, el
      // estado remoto AVAILABLE es la fuente de verdad y no debe volver a
      // entrar al ciclo de subida.
      await txn.delete(
        'outbox_evidencias',
        where: 'evidencia_id = ?',
        whereArgs: [evidence.id],
      );
    });
  }

  Future<void> updateDisplayName({
    required String requisitionId,
    required String evidenceId,
    required String displayName,
  }) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    await db.update(
      'evidencias_locales',
      {
        'nombre_mostrado': displayName,
        'actualizado_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'account_id = ? AND id = ? AND requisa_id = ?',
      whereArgs: [accountId, evidenceId, requisitionId],
    );
  }

  Future<String> persistentEncryptedPath(String evidenceId) async {
    final root = Directory('${await getDatabasesPath()}/evidence_files');
    await root.create(recursive: true);
    return '${root.path}/$evidenceId.fce';
  }

  /// Serializa las sincronizaciones entre el isolate principal y el isolate
  /// de WorkManager. Cada isolate crea su propia instancia del servicio, por
  /// lo que un booleano en memoria no evita que ambos consuman la misma
  /// evidencia pendiente.
  Future<T> withSyncLock<T>(
    Future<T> Function() operation, {
    Duration waitTimeout = _defaultLockWaitTimeout,
  }) async {
    if (waitTimeout <= Duration.zero) {
      throw ArgumentError.value(
        waitTimeout,
        'waitTimeout',
        'Debe ser mayor que cero.',
      );
    }

    final db = await database.timeout(
      waitTimeout,
      onTimeout: () => throw TimeoutException(
        'La base local tardó demasiado en abrirse.',
        waitTimeout,
      ),
    );
    final deadline = DateTime.now().add(waitTimeout);
    final owner =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    var acquired = false;

    while (!acquired) {
      try {
        acquired = await db.transaction<bool>((txn) async {
          final now = DateTime.now().millisecondsSinceEpoch;
          final expiresAt = now + _lockLeaseDuration.inMilliseconds;
          final renewed = await txn.rawUpdate(
            'UPDATE sync_locks SET owner = ?, expires_at = ? '
            'WHERE id = 1 AND expires_at <= ?',
            [owner, expiresAt, now],
          );
          if (renewed == 1) return true;

          try {
            await txn.insert('sync_locks', {
              'id': 1,
              'owner': owner,
              'expires_at': expiresAt,
            });
            return true;
          } on Object {
            return false;
          }
        });
      } on Object catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('database_close') ||
            message.contains('database is closed')) {
          _database = null;
        } else if (!message.contains('locked') && !message.contains('busy')) {
          rethrow;
        }
      }

      if (!acquired) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException(
            'No se pudo adquirir el bloqueo de sincronización local.',
            waitTimeout,
          );
        }
        await Future<void>.delayed(
          remaining < _lockPollInterval ? remaining : _lockPollInterval,
        );
      }
    }

    try {
      return await operation();
    } finally {
      try {
        await db.transaction((txn) async {
          await txn.delete(
            'sync_locks',
            where: 'id = 1 AND owner = ?',
            whereArgs: [owner],
          );
        });
      } on Object catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('database_close') ||
            message.contains('database is closed')) {
          _database = null;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<List<LocalEvidenceRecord>> pending({
    int limit = 10,
    bool automaticOnly = false,
  }) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT e.*
      FROM evidencias_locales e
      INNER JOIN outbox_evidencias o ON o.evidencia_id = e.id
      WHERE o.estado IN ('PENDIENTE', 'ERROR')
        AND e.account_id = ?
        AND e.sesion_id <> ''
        ${automaticOnly ? 'AND o.reintento_automatico = 1' : ''}
      ORDER BY e.creado_at ASC
      LIMIT ?
      ''',
      [accountId, limit],
    );
    return _recordsFromRows(rows);
  }

  /// Reserva un lote pequeño de evidencias para un ciclo de subida.
  ///
  /// El lock solo cubre la selección y el cambio de estado. La red, el
  /// cifrado de claves y la subida del archivo ocurren fuera del lock, así
  /// que una captura nueva nunca queda esperando a que termine un video o un
  /// lote grande de evidencias.
  Future<List<LocalEvidenceRecord>> claimPending({
    int limit = 10,
    bool automaticOnly = false,
    String? requisitionId,
    String? evidenceId,
    Iterable<String> excludedEvidenceIds = const <String>[],
  }) async {
    if (limit <= 0) return const <LocalEvidenceRecord>[];
    final excluded = excludedEvidenceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final accountId = await _requiredAccountId();
    final documentsPath = Platform.isIOS ? await getDatabasesPath() : null;
    return withSyncLock(() async {
      final db = await database;
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      final staleBefore = now.subtract(_staleClaimTimeout).toIso8601String();
      return db.transaction<List<LocalEvidenceRecord>>((txn) async {
        // Recupera trabajos que quedaron reservados si el proceso murió o el
        // worker fue detenido antes de publicar el resultado final.
        await txn.rawUpdate(
          '''
          UPDATE outbox_evidencias
          SET estado = 'ERROR',
              ultimo_error = 'La sincronización anterior no finalizó.',
              actualizado_at = ?
          WHERE estado = 'SUBIENDO' AND actualizado_at <= ?
          ''',
          [nowIso, staleBefore],
        );
        await txn.rawUpdate(
          '''
          UPDATE evidencias_locales
          SET estado = 'ERROR', actualizado_at = ?
          WHERE estado = 'SUBIENDO' AND actualizado_at <= ?
          ''',
          [nowIso, staleBefore],
        );

        final where = <String>[
          "o.estado IN ('PENDIENTE', 'ERROR')",
          'e.account_id = ?',
          "e.sesion_id <> ''",
          if (automaticOnly) 'o.reintento_automatico = 1',
          if (requisitionId?.trim().isNotEmpty == true) 'e.requisa_id = ?',
          if (evidenceId?.trim().isNotEmpty == true) 'o.evidencia_id = ?',
          if (excluded.isNotEmpty)
            'o.evidencia_id NOT IN (${List.filled(excluded.length, '?').join(', ')})',
        ];
        final args = <Object?>[
          accountId,
          if (requisitionId?.trim().isNotEmpty == true) requisitionId!.trim(),
          if (evidenceId?.trim().isNotEmpty == true) evidenceId!.trim(),
          if (excluded.isNotEmpty) ...excluded,
          limit,
        ];
        final rows = await txn.rawQuery(
          '''
          SELECT e.*
          FROM evidencias_locales e
          INNER JOIN outbox_evidencias o ON o.evidencia_id = e.id
          WHERE ${where.join(' AND ')}
          ORDER BY e.creado_at ASC
          LIMIT ?
          ''',
          args,
        );
        if (rows.isEmpty) return const <LocalEvidenceRecord>[];

        for (final row in rows) {
          await txn.update(
            'outbox_evidencias',
            {
              'estado': 'SUBIENDO',
              'actualizado_at': nowIso,
            },
            where: 'evidencia_id = ? AND estado IN (?, ?)',
            whereArgs: [row['id'], 'PENDIENTE', 'ERROR'],
          );
          await txn.update(
            'evidencias_locales',
            {
              'estado': 'SUBIENDO',
              'actualizado_at': nowIso,
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        return rows
            .map((row) => _recordFromRow(row, documentsPath))
            .toList(growable: false);
      });
    });
  }

  Future<List<LocalEvidenceRecord>> forRequisition(String requisitionId) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final rows = await db.query(
      'evidencias_locales',
      where: 'account_id = ? AND requisa_id = ?',
      whereArgs: [accountId, requisitionId],
      orderBy: 'creado_at ASC',
    );
    return _recordsFromRows(rows);
  }

  /// Pausa toda la outbox no confirmada de una requisa. La evidencia permanece
  /// cifrada en el dispositivo y no será reclamada por reintentos automáticos.
  Future<void> pausePendingForRequisition(String requisitionId) async {
    final normalizedId = requisitionId.trim();
    if (normalizedId.isEmpty) return;
    final accountId = await _requiredAccountId();
    await withSyncLock(() async {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((txn) async {
        await txn.rawUpdate(
          '''
          UPDATE outbox_evidencias
          SET estado = 'PENDIENTE', ultimo_error = NULL,
              reintento_automatico = 0, actualizado_at = ?
          WHERE estado <> 'SINCRONIZADA' AND evidencia_id IN (
              SELECT id FROM evidencias_locales
              WHERE account_id = ? AND requisa_id = ?
            )
          ''',
          [now, accountId, normalizedId],
        );
        await txn.rawUpdate(
          '''
          UPDATE evidencias_locales
          SET estado = 'PENDIENTE', actualizado_at = ?
          WHERE estado <> 'SINCRONIZADA'
            AND account_id = ? AND requisa_id = ?
          ''',
          [now, accountId, normalizedId],
        );
      });
    });
  }

  /// Reactiva una outbox pausada o con error para un reintento solicitado por
  /// el usuario. La próxima reclamación mostrará SUBIENDO solo para el archivo
  /// que realmente esté siendo procesado.
  Future<void> resumePendingForRequisition(String requisitionId) async {
    final normalizedId = requisitionId.trim();
    if (normalizedId.isEmpty) return;
    final accountId = await _requiredAccountId();
    await withSyncLock(() async {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((txn) async {
        await txn.rawUpdate(
          '''
          UPDATE outbox_evidencias
          SET estado = 'PENDIENTE', ultimo_error = NULL,
              reintento_automatico = 1, actualizado_at = ?
          WHERE estado <> 'SINCRONIZADA' AND evidencia_id IN (
              SELECT id FROM evidencias_locales
              WHERE account_id = ? AND requisa_id = ?
            )
          ''',
          [now, accountId, normalizedId],
        );
        await txn.rawUpdate(
          '''
          UPDATE evidencias_locales
          SET estado = 'PENDIENTE', actualizado_at = ?
          WHERE estado <> 'SINCRONIZADA'
            AND account_id = ? AND requisa_id = ?
          ''',
          [now, accountId, normalizedId],
        );
      });
    });
  }

  /// Reactiva una única evidencia. El resto de la requisa conserva su estado
  /// pausado para que una acción individual no dispare todo el lote.
  Future<void> resumeEvidenceForUpload({
    required String requisitionId,
    required String evidenceId,
  }) async {
    final normalizedRequisitionId = requisitionId.trim();
    final normalizedEvidenceId = evidenceId.trim();
    if (normalizedRequisitionId.isEmpty || normalizedEvidenceId.isEmpty) {
      return;
    }
    final accountId = await _requiredAccountId();
    await withSyncLock(() async {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((txn) async {
        await txn.rawUpdate(
          '''
          UPDATE outbox_evidencias
          SET estado = 'PENDIENTE', ultimo_error = NULL,
              reintento_automatico = 1, actualizado_at = ?
          WHERE estado <> 'SINCRONIZADA' AND evidencia_id = ?
            AND evidencia_id IN (
              SELECT id FROM evidencias_locales
              WHERE account_id = ? AND requisa_id = ?
            )
          ''',
          [
            now,
            normalizedEvidenceId,
            accountId,
            normalizedRequisitionId,
          ],
        );
        await txn.rawUpdate(
          '''
          UPDATE evidencias_locales
          SET estado = 'PENDIENTE', actualizado_at = ?
          WHERE estado <> 'SINCRONIZADA'
            AND account_id = ? AND id = ? AND requisa_id = ?
          ''',
          [now, accountId, normalizedEvidenceId, normalizedRequisitionId],
        );
      });
    });
  }

  Future<void> markUploaded(String evidenceId, String msFileId) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'evidencias_locales',
        {
          'estado': 'SINCRONIZADA',
          'ms_archivo_id': msFileId,
          'actualizado_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'account_id = ? AND id = ?',
        whereArgs: [accountId, evidenceId],
      );
      await txn.update(
        'outbox_evidencias',
        {
          'estado': 'SINCRONIZADA',
          'ultimo_error': null,
          'actualizado_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'evidencia_id = ?',
        whereArgs: [evidenceId],
      );
    });
  }

  Future<void> markError(
    String evidenceId,
    String message, {
    bool retryable = true,
  }) async {
    final accountId = await _requiredAccountId();
    final db = await database;
    final safeMessage = message.length > 512
        ? message.substring(0, 512)
        : message;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final changed = await txn.rawUpdate(
        '''
        UPDATE outbox_evidencias
        SET estado = 'ERROR', intentos = intentos + 1,
            ultimo_error = ?, reintento_automatico = ?, actualizado_at = ?
        WHERE evidencia_id = ? AND estado <> 'SINCRONIZADA'
        ''',
        [safeMessage, retryable ? 1 : 0, now, evidenceId],
      );
      if (changed == 0) return;
      await txn.update(
        'evidencias_locales',
        {
          'estado': 'ERROR',
          'actualizado_at': now,
        },
        where: 'account_id = ? AND id = ?',
        whereArgs: [accountId, evidenceId],
      );
    });
  }

  /// Elimina una evidencia únicamente mientras no haya recibido un
  /// identificador de ms-files-v2. La operación se serializa con la outbox
  /// para evitar borrar un archivo mientras se está subiendo.
  Future<bool> deletePendingEvidence({
    required String requisitionId,
    required String evidenceId,
  }) async {
    final accountId = await _requiredAccountId();
    final documentsPath = Platform.isIOS ? await getDatabasesPath() : null;
    return withSyncLock(() async {
      final db = await database;
      final rows = await db.query(
        'evidencias_locales',
        where: 'account_id = ? AND id = ? AND requisa_id = ?',
        whereArgs: [accountId, evidenceId, requisitionId],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final record = _recordFromRow(rows.single, documentsPath);
      final outboxRows = await db.query(
        'outbox_evidencias',
        columns: ['estado'],
        where: 'evidencia_id = ?',
        whereArgs: [evidenceId],
        limit: 1,
      );
      final outboxState = outboxRows.isEmpty
          ? null
          : (outboxRows.single['estado'] as String?)?.toUpperCase();
      final isSynchronized =
          record.state.toUpperCase() == 'SINCRONIZADA' ||
          record.msFileId?.trim().isNotEmpty == true ||
          outboxState == 'SINCRONIZADA';
      if (isSynchronized) {
        throw StateError(
          'La evidencia ya está sincronizada y no se puede eliminar.',
        );
      }

      final encryptedFile = File(record.encryptedPath);
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
      await db.transaction((txn) async {
        await txn.delete(
          'outbox_evidencias',
          where: 'evidencia_id = ?',
          whereArgs: [evidenceId],
        );
        await txn.delete(
          'evidencias_locales',
          where: 'account_id = ? AND id = ? AND requisa_id = ?',
          whereArgs: [accountId, evidenceId, requisitionId],
        );
      });
      return true;
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<String> _databaseKey() async {
    final existing = await _storage.read(_databaseKeyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(_databaseKeyName, key);
    return key;
  }
}

final class LocalEvidenceDatabaseException implements Exception {
  const LocalEvidenceDatabaseException({
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

final class LocalRequisitionCacheRecord {
  const LocalRequisitionCacheRecord({
    required this.id,
    required this.caseName,
    required this.registeredAt,
    required this.status,
    required this.imageCount,
    required this.videoCount,
    required this.isSynchronized,
    required this.documentCount,
    this.cud,
    this.subjectName,
    this.latitude,
    this.longitude,
    this.locationLabel,
  });

  final String id;
  final String caseName;
  final DateTime registeredAt;
  final String status;
  final int imageCount;
  final int videoCount;
  final bool isSynchronized;
  final String? cud;
  final String? subjectName;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final int documentCount;

  Map<String, Object?> toMap({
    required String accountId,
    required String cachedAt,
  }) => {
    'account_id': accountId,
    'requisition_id': id,
    'case_name': caseName,
    'registered_at': registeredAt.toUtc().toIso8601String(),
    'status': status,
    'image_count': imageCount,
    'video_count': videoCount,
    'is_synchronized': isSynchronized ? 1 : 0,
    'cud': cud,
    'subject_name': subjectName,
    'latitude': latitude,
    'longitude': longitude,
    'location_label': locationLabel,
    'document_count': documentCount,
    'cached_at': cachedAt,
  };

  factory LocalRequisitionCacheRecord.fromMap(Map<String, Object?> map) {
    return LocalRequisitionCacheRecord(
      id: map['requisition_id']! as String,
      caseName: map['case_name']! as String,
      registeredAt: DateTime.parse(map['registered_at']! as String).toLocal(),
      status: map['status']! as String,
      imageCount: (map['image_count']! as num).toInt(),
      videoCount: (map['video_count']! as num).toInt(),
      isSynchronized: (map['is_synchronized']! as num).toInt() == 1,
      cud: map['cud'] as String?,
      subjectName: map['subject_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationLabel: map['location_label'] as String?,
      documentCount: (map['document_count'] as num?)?.toInt() ?? 0,
    );
  }
}

final class LocalAcquisitionSessionRecord {
  const LocalAcquisitionSessionRecord({
    required this.localId,
    required this.requisitionId,
    required this.sourcePlatform,
    required this.transport,
    required this.clientOperationId,
    required this.status,
    required this.createdAt,
    this.remoteId,
    this.lastError,
  });

  final String localId;
  final String requisitionId;
  final String? remoteId;
  final String sourcePlatform;
  final String transport;
  final String clientOperationId;
  final String status;
  final String? lastError;
  final DateTime createdAt;

  Map<String, Object?> toMap({required String accountId}) => {
    'local_id': localId,
    'account_id': accountId,
    'requisition_id': requisitionId,
    'remote_id': remoteId,
    'source_platform': sourcePlatform,
    'transport': transport,
    'client_operation_id': clientOperationId,
    'status': status,
    'last_error': lastError,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': createdAt.toUtc().toIso8601String(),
  };

  factory LocalAcquisitionSessionRecord.fromMap(Map<String, Object?> map) {
    return LocalAcquisitionSessionRecord(
      localId: map['local_id']! as String,
      requisitionId: map['requisition_id']! as String,
      remoteId: map['remote_id'] as String?,
      sourcePlatform: map['source_platform']! as String,
      transport: map['transport']! as String,
      clientOperationId: map['client_operation_id']! as String,
      status: map['status']! as String,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String).toLocal(),
    );
  }
}

final class LocalEvidenceRecord {
  const LocalEvidenceRecord({
    required this.id,
    required this.requisitionId,
    required this.sessionId,
    required this.originalName,
    required this.mimeType,
    required this.type,
    required this.acquisitionMethod,
    required this.encryptedPath,
    required this.plaintextByteLength,
    required this.ciphertextByteLength,
    required this.plaintextSha256,
    required this.ciphertextSha256,
    required this.encryptionAlgorithm,
    required this.encryptionVersion,
    required this.aadHash,
    required this.wrappedKey,
    required this.keyVersion,
    required this.state,
    required this.clientOperationId,
    required this.createdAt,
    this.sourcePath,
    this.subjectPersonIds = const [],
    this.msFileId,
    this.displayName,
  });

  final String id;
  final String requisitionId;
  final String sessionId;
  final String originalName;
  final String? displayName;
  final String mimeType;
  final String type;
  final String acquisitionMethod;
  final String encryptedPath;
  final int plaintextByteLength;
  final int ciphertextByteLength;
  final String plaintextSha256;
  final String ciphertextSha256;
  final String encryptionAlgorithm;
  final int encryptionVersion;
  final String aadHash;
  final String wrappedKey;
  final int keyVersion;
  final String state;
  final String clientOperationId;
  final DateTime createdAt;
  final String? sourcePath;
  final List<int> subjectPersonIds;
  final String? msFileId;

  Map<String, Object?> toMap() => {
    'id': id,
    'requisa_id': requisitionId,
    'sesion_id': sessionId,
    'nombre_original': originalName,
    'nombre_mostrado': displayName,
    'mime_type': mimeType,
    'tipo': type,
    'metodo_adquisicion': acquisitionMethod,
    'ruta_cifrada': encryptedPath,
    'tamano_plano': plaintextByteLength,
    'tamano_cifrado': ciphertextByteLength,
    'hash_plano': plaintextSha256,
    'hash_cifrado': ciphertextSha256,
    'algoritmo_cifrado': encryptionAlgorithm,
    'version_cifrado': encryptionVersion,
    'hash_aad': aadHash,
    'clave_envuelta': wrappedKey,
    'version_clave': keyVersion,
    'estado': state,
    'ms_archivo_id': msFileId,
    'ruta_origen': sourcePath,
    'sujeto_person_ids': jsonEncode(subjectPersonIds),
    'client_operation_id': clientOperationId,
    'creado_at': createdAt.toUtc().toIso8601String(),
    'actualizado_at': createdAt.toUtc().toIso8601String(),
  };

  factory LocalEvidenceRecord.fromMap(Map<String, Object?> map) {
    return LocalEvidenceRecord(
      id: map['id']! as String,
      requisitionId: map['requisa_id']! as String,
      sessionId: map['sesion_id']! as String,
      originalName: map['nombre_original']! as String,
      displayName: map['nombre_mostrado'] as String?,
      mimeType: map['mime_type']! as String,
      type: map['tipo']! as String,
      acquisitionMethod: map['metodo_adquisicion']! as String,
      encryptedPath: map['ruta_cifrada']! as String,
      plaintextByteLength: map['tamano_plano']! as int,
      ciphertextByteLength: map['tamano_cifrado']! as int,
      plaintextSha256: map['hash_plano']! as String,
      ciphertextSha256: map['hash_cifrado']! as String,
      encryptionAlgorithm: map['algoritmo_cifrado']! as String,
      encryptionVersion: map['version_cifrado']! as int,
      aadHash: map['hash_aad']! as String,
      wrappedKey: map['clave_envuelta']! as String,
      keyVersion: map['version_clave']! as int,
      state: map['estado']! as String,
      clientOperationId: map['client_operation_id']! as String,
      createdAt: DateTime.parse(map['creado_at']! as String),
      sourcePath: map['ruta_origen'] as String?,
      subjectPersonIds: _decodeSubjectPersonIds(
        map['sujeto_person_ids'] as String?,
      ),
      msFileId: map['ms_archivo_id'] as String?,
    );
  }

  static List<int> _decodeSubjectPersonIds(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded.whereType<num>().map((item) => item.toInt()).toList();
    } on FormatException {
      return const [];
    }
  }
}
