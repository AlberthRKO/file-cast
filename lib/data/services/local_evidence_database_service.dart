import 'dart:convert';
import 'dart:math';

import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Persistencia local cifrada para evidencias y operaciones pendientes.
/// Nunca guarda el contenido plano; solo la ruta FCE y sus metadatos.
class LocalEvidenceDatabaseService {
  LocalEvidenceDatabaseService({required SecureStorageService storage})
      : _storage = storage;

  static const _databaseKeyName = 'file_cast_evidence_database_key_v1';
  static const _databaseName = 'file_cast_evidence_v1.db';

  final SecureStorageService _storage;
  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;

    final key = await _databaseKey();
    final path = '${await getDatabasesPath()}/$_databaseName';
    final opened = await openDatabase(
      path,
      password: key,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE evidencias_locales (
            id TEXT PRIMARY KEY,
            requisa_id TEXT NOT NULL,
            sesion_id TEXT NOT NULL,
            nombre_original TEXT NOT NULL,
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
            actualizado_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX evidencias_locales_requisa_idx '
          'ON evidencias_locales(requisa_id, creado_at)',
        );
        await db.execute(
          'CREATE INDEX outbox_evidencias_estado_idx '
          'ON outbox_evidencias(estado, actualizado_at)',
        );
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE evidencias_locales ADD COLUMN metodo_adquisicion "
            "TEXT NOT NULL DEFAULT 'IMPORTED_FILE'",
          );
        }
      },
    );
    _database = opened;
    return opened;
  }

  Future<void> saveEvidence(LocalEvidenceRecord evidence) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert(
        'evidencias_locales',
        {
          ...evidence.toMap(),
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
          'actualizado_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<List<LocalEvidenceRecord>> pending({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT e.*
      FROM evidencias_locales e
      INNER JOIN outbox_evidencias o ON o.evidencia_id = e.id
      WHERE o.estado IN ('PENDIENTE', 'ERROR')
        AND e.sesion_id <> ''
      ORDER BY e.creado_at ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(LocalEvidenceRecord.fromMap).toList(growable: false);
  }

  Future<List<LocalEvidenceRecord>> forRequisition(String requisitionId) async {
    final db = await database;
    final rows = await db.query(
      'evidencias_locales',
      where: 'requisa_id = ?',
      whereArgs: [requisitionId],
      orderBy: 'creado_at ASC',
    );
    return rows.map(LocalEvidenceRecord.fromMap).toList(growable: false);
  }

  Future<void> markUploaded(String evidenceId, String msFileId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'evidencias_locales',
        {
          'estado': 'SINCRONIZADA',
          'ms_archivo_id': msFileId,
          'actualizado_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [evidenceId],
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

  Future<void> markError(String evidenceId, String message) async {
    final db = await database;
    final safeMessage =
        message.length > 512 ? message.substring(0, 512) : message;
    await db.rawUpdate(
      '''
      UPDATE outbox_evidencias
      SET estado = 'ERROR', intentos = intentos + 1,
          ultimo_error = ?, actualizado_at = ?
      WHERE evidencia_id = ?
      ''',
      [safeMessage, DateTime.now().toUtc().toIso8601String(), evidenceId],
    );
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
    this.msFileId,
  });

  final String id;
  final String requisitionId;
  final String sessionId;
  final String originalName;
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
  final String? msFileId;

  Map<String, Object?> toMap() => {
        'id': id,
        'requisa_id': requisitionId,
        'sesion_id': sessionId,
        'nombre_original': originalName,
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
      msFileId: map['ms_archivo_id'] as String?,
    );
  }
}
