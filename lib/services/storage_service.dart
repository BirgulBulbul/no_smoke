import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/adaptive_plan.dart';
import '../models/behavior_dashboard.dart';
import '../models/sensor_usage_event.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../models/user_profile_snapshot.dart';
import 'behavior_engine.dart';

class StorageService {
  static const _tableName = 'app_events';
  static const _settingsTable = 'app_settings';
  static const _surveyDetailsTable = 'survey_details';
  static const _profileSnapshotTable = 'user_profile_snapshots';
  static const _languageHistoryTable = 'language_history';
  static const _sensorUsageTable = 'sensor_usage_events';
  static const _behaviorSnapshotTable = 'behavior_snapshots';
  static const _taskFollowUpTable = 'task_followups';
  static const _behaviorDirtyKey = 'behavior_dirty';
  static const _registrationCompletedKey = 'registration_completed';
  static const _isProfileCompletedKey = 'isProfileCompleted';
  static const _surveyTypes = {'initial', 'weekly'};
  final BehaviorEngine _behaviorEngine = BehaviorEngine();
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'no_smoke.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            completedAt TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            name TEXT NOT NULL,
            packsPerDay TEXT,
            dailyCigarettes INTEGER NOT NULL,
            exhaleTestSeconds INTEGER NOT NULL,
            inhaleTestSeconds INTEGER NOT NULL,
            riskScore INTEGER NOT NULL,
            riskLevel TEXT NOT NULL,
            taskTitle TEXT,
            taskResult TEXT,
            consecutiveSmokingHabit TEXT,
            consecutiveSmokingCount TEXT
          )
        ''');
        await _ensureSettingsTable(db);
        await _ensureSurveyDetailsTable(db);
        await _ensureProfileSnapshotTable(db);
        await _ensureLanguageHistoryTable(db);
        await _ensureSensorUsageTable(db);
        await _ensureBehaviorSnapshotTable(db);
        await _ensureTaskFollowUpTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureColumn(db, 'packsPerDay', 'TEXT');
        await _ensureColumn(db, 'taskTitle', 'TEXT');
        await _ensureColumn(db, 'taskResult', 'TEXT');
        await _ensureColumn(db, 'consecutiveSmokingHabit', 'TEXT');
        await _ensureColumn(db, 'consecutiveSmokingCount', 'TEXT');
        await _ensureSettingsTable(db);
        await _ensureSurveyDetailsTable(db);
        await _ensureProfileSnapshotTable(db);
        await _ensureLanguageHistoryTable(db);
        await _ensureSensorUsageTable(db);
        await _ensureBehaviorSnapshotTable(db);
        await _ensureTaskFollowUpTable(db);
      },
    );
  }

  Future<void> _ensureSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureSurveyDetailsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_surveyDetailsTable (
        recordId TEXT PRIMARY KEY,
        triggerJson TEXT,
        healthJson TEXT,
        firstCigaretteRange TEXT,
        smokeFreeRange TEXT,
        profession TEXT,
        sleepTime TEXT,
        wakeTime TEXT,
        stressLevel TEXT,
        quitReason TEXT,
        workStart TEXT,
        workEnd TEXT,
        workplaceSmokingRule TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureProfileSnapshotTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_profileSnapshotTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        riskScore INTEGER NOT NULL,
        packsPerDay TEXT NOT NULL,
        firstCigaretteRange TEXT NOT NULL,
        smokeFreeRange TEXT NOT NULL,
        consecutiveSmokingHabit TEXT NOT NULL,
        consecutiveSmokingCount TEXT,
        triggerJson TEXT NOT NULL,
        healthJson TEXT NOT NULL,
        profession TEXT NOT NULL,
        sleepTime TEXT NOT NULL,
        wakeTime TEXT NOT NULL,
        latestExhaleSeconds INTEGER NOT NULL,
        latestInhaleSeconds INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _ensureLanguageHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_languageHistoryTable (
        id TEXT PRIMARY KEY,
        languageCode TEXT NOT NULL,
        selectedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureSensorUsageTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_sensorUsageTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        activityState TEXT NOT NULL,
        accelerometerMagnitude REAL NOT NULL,
        gyroscopeMagnitude REAL NOT NULL,
        screenUnlockCount INTEGER NOT NULL,
        appUsageMinutes INTEGER NOT NULL,
        idleMinutes INTEGER NOT NULL,
        charging INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _ensureBehaviorSnapshotTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_behaviorSnapshotTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        snapshotJson TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureTaskFollowUpTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_taskFollowUpTable (
        id TEXT PRIMARY KEY,
        taskTitle TEXT NOT NULL,
        scheduledAt TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureColumn(Database db, String columnName, String columnType) async {
    try {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN $columnName $columnType');
    } catch (_) {
      // Column already exists on upgraded databases.
    }
  }

  Future<List<SurveyRecord>> loadSurveyHistory() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'completedAt ASC');
    return rows.map((row) => SurveyRecord.fromJson({...row, 'completedAt': row['completedAt'] as String})).toList();
  }

  Future<void> saveSurveyHistory(List<SurveyRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(_tableName, record.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveSurveyRecord(SurveyRecord record) async {
    try {
      final db = await database;
      await db.insert(_tableName, record.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      await updateLastSurveyDate(record.completedAt);
      await markBehaviorDirty();
    } catch (error, stackTrace) {
      debugPrint('[StorageService] saveSurveyRecord failed: id=${record.id}, type=${record.type}, error=$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> saveSurveyDetail({
    required String recordId,
    required List<String> triggers,
    required List<String> healthConditions,
    String? firstCigaretteRange,
    String? smokeFreeRange,
    String? profession,
    String? sleepTime,
    String? wakeTime,
    String? stressLevel,
    String? quitReason,
    String? workStart,
    String? workEnd,
    String? workplaceSmokingRule,
  }) async {
    try {
      final db = await database;
      await db.insert(
        _surveyDetailsTable,
        {
          'recordId': recordId,
          'triggerJson': jsonEncode(triggers),
          'healthJson': jsonEncode(healthConditions),
          'firstCigaretteRange': firstCigaretteRange,
          'smokeFreeRange': smokeFreeRange,
          'profession': profession,
          'sleepTime': sleepTime,
          'wakeTime': wakeTime,
          'stressLevel': stressLevel,
          'quitReason': quitReason,
          'workStart': workStart,
          'workEnd': workEnd,
          'workplaceSmokingRule': workplaceSmokingRule,
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await markBehaviorDirty();
    } catch (error, stackTrace) {
      debugPrint('[StorageService] saveSurveyDetail failed: recordId=$recordId, error=$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, List<String>>> loadTriggerMapByRecordId() async {
    final db = await database;
    final rows = await db.query(_surveyDetailsTable);
    final result = <String, List<String>>{};
    for (final row in rows) {
      final recordId = row['recordId'] as String;
      final raw = row['triggerJson'] as String?;
      if (raw == null || raw.isEmpty) {
        result[recordId] = const [];
        continue;
      }
      final parsed = (jsonDecode(raw) as List<dynamic>).map((item) => item.toString()).toList();
      result[recordId] = parsed;
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> loadSurveyContextByRecordId() async {
    final db = await database;
    final rows = await db.query(_surveyDetailsTable);
    final result = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final recordId = row['recordId'] as String;
      final healthRaw = row['healthJson'] as String?;
      final healthConditions = healthRaw == null || healthRaw.isEmpty
          ? <String>[]
          : (jsonDecode(healthRaw) as List<dynamic>).map((item) => item.toString()).toList();

      result[recordId] = {
        'profession': row['profession'] as String?,
        'sleepTime': row['sleepTime'] as String?,
        'wakeTime': row['wakeTime'] as String?,
        'healthConditions': healthConditions,
      };
    }

    return result;
  }

  Future<void> saveUserProfileSnapshot(UserProfileSnapshot snapshot) async {
    try {
      final db = await database;
      await db.insert(
        _profileSnapshotTable,
        {
          'id': snapshot.id,
          'createdAt': snapshot.createdAt.toIso8601String(),
          'riskScore': snapshot.riskScore,
          'packsPerDay': snapshot.packsPerDay,
          'firstCigaretteRange': snapshot.firstCigaretteRange,
          'smokeFreeRange': snapshot.smokeFreeRange,
          'consecutiveSmokingHabit': snapshot.consecutiveSmokingHabit,
          'consecutiveSmokingCount': snapshot.consecutiveSmokingCount,
          'triggerJson': jsonEncode(snapshot.triggers),
          'healthJson': jsonEncode(snapshot.healthConditions),
          'profession': snapshot.profession,
          'sleepTime': snapshot.sleepTime,
          'wakeTime': snapshot.wakeTime,
          'latestExhaleSeconds': snapshot.latestExhaleSeconds,
          'latestInhaleSeconds': snapshot.latestInhaleSeconds,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error, stackTrace) {
      debugPrint('[StorageService] saveUserProfileSnapshot failed: id=${snapshot.id}, error=$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> saveLanguageSelectionHistory(String languageCode) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(
      _languageHistoryTable,
      {
        'id': 'lang_${now.microsecondsSinceEpoch}',
        'languageCode': languageCode,
        'selectedAt': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveSensorUsageEvent(SensorUsageEvent event) async {
    final db = await database;
    await db.insert(
      _sensorUsageTable,
      {
        'id': event.id,
        'createdAt': event.createdAt.toIso8601String(),
        'activityState': event.activityState,
        'accelerometerMagnitude': event.accelerometerMagnitude,
        'gyroscopeMagnitude': event.gyroscopeMagnitude,
        'screenUnlockCount': event.screenUnlockCount,
        'appUsageMinutes': event.appUsageMinutes,
        'idleMinutes': event.idleMinutes,
        'charging': event.charging ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await markBehaviorDirty();
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      _settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> loadSetting(String key) async {
    final db = await database;
    final rows = await db.query(_settingsTable, where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  Future<void> markBehaviorDirty() async {
    await saveSetting(_behaviorDirtyKey, '1');
  }

  Future<void> clearBehaviorDirty() async {
    await saveSetting(_behaviorDirtyKey, '0');
  }

  Future<bool> isBehaviorDirty() async {
    final value = await loadSetting(_behaviorDirtyKey);
    if (value == null) {
      return true;
    }
    return value == '1';
  }

  Future<List<SensorUsageEvent>> loadRecentSensorUsage({int limit = 120}) async {
    final db = await database;
    final rows = await db.query(
      _sensorUsageTable,
      orderBy: 'createdAt ASC',
      limit: limit,
    );
    return rows.map((row) {
      return SensorUsageEvent(
        id: row['id'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
        activityState: row['activityState'] as String,
        accelerometerMagnitude: (row['accelerometerMagnitude'] as num).toDouble(),
        gyroscopeMagnitude: (row['gyroscopeMagnitude'] as num).toDouble(),
        screenUnlockCount: (row['screenUnlockCount'] as num).toInt(),
        appUsageMinutes: (row['appUsageMinutes'] as num).toInt(),
        idleMinutes: (row['idleMinutes'] as num).toInt(),
        charging: ((row['charging'] as num?)?.toInt() ?? 0) == 1,
      );
    }).toList();
  }

  Future<List<TaskHistory>> loadTaskHistory() async {
    final records = await loadSurveyHistory();
    return records
        .where((record) => record.type == 'task_result' && (record.taskTitle?.isNotEmpty ?? false))
        .map((record) {
          final resultText = (record.taskResult ?? '').toLowerCase();
          final completed = resultText.contains('success') ||
              resultText.contains('basar') ||
              resultText.contains('tamam');
          return TaskHistory(
            taskId: record.id,
            taskTitle: record.taskTitle ?? 'Task',
            completed: completed,
            date: record.completedAt,
          );
        })
        .toList();
  }

  Future<void> saveBehaviorSnapshot(Map<String, dynamic> snapshot) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(
      _behaviorSnapshotTable,
      {
        'id': 'behavior_${now.microsecondsSinceEpoch}',
        'createdAt': now.toIso8601String(),
        'snapshotJson': jsonEncode(snapshot),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTaskResult({required String taskTitle, required String taskResult, required DateTime completedAt}) async {
    final record = SurveyRecord(
      id: 'task_${completedAt.millisecondsSinceEpoch}',
      completedAt: completedAt,
      type: 'task_result',
      title: 'Görev Sonucu',
      name: '',
      packsPerDay: '1 paketten az',
      exhaleTestSeconds: 0,
      inhaleTestSeconds: 0,
      riskScore: 0,
      riskLevel: 'BİLİNMEYEN',
      taskTitle: taskTitle,
      taskResult: taskResult,
    );
    await saveSurveyRecord(record);
    await markBehaviorDirty();
  }

  Future<void> saveTaskFollowUp({
    required String taskTitle,
    required DateTime scheduledAt,
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(
      _taskFollowUpTable,
      {
        'id': 'followup_${now.microsecondsSinceEpoch}',
        'taskTitle': taskTitle,
        'scheduledAt': scheduledAt.toIso8601String(),
        'status': 'pending',
        'createdAt': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> loadPendingTaskFollowUps() async {
    final db = await database;
    final rows = await db.query(
      _taskFollowUpTable,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'scheduledAt ASC',
    );

    return rows
        .map((row) => {
              'id': row['id'] as String,
              'taskTitle': row['taskTitle'] as String,
              'scheduledAt': DateTime.parse(row['scheduledAt'] as String),
              'status': row['status'] as String,
              'createdAt': DateTime.parse(row['createdAt'] as String),
            })
        .toList();
  }

  Future<void> resolveTaskFollowUpByTitle(String taskTitle) async {
    final db = await database;
    await db.update(
      _taskFollowUpTable,
      {'status': 'resolved'},
      where: 'taskTitle = ? AND status = ?',
      whereArgs: [taskTitle, 'pending'],
    );
  }

  Future<Map<String, String>> loadConsecutiveSmokingSummary() async {
    final records = await _loadRelevantSurveyRecords();
    if (records.isEmpty) {
      return {
        'latest': 'noRecordYet',
        'previous': 'noRecordYet',
        'trend': 'noRecordYet',
        'status': 'noRecordYet',
      };
    }

    final current = records.last;
    final previous = records.length > 1 ? records[records.length - 2] : null;

    final latestLabel = _behaviorEngine.summarizeConsecutiveSmoking(
      habit: current.consecutiveSmokingHabit,
      count: current.consecutiveSmokingCount,
    );
    final previousLabel = previous == null
      ? 'firstEvaluation'
        : _behaviorEngine.summarizeConsecutiveSmoking(
            habit: previous.consecutiveSmokingHabit,
            count: previous.consecutiveSmokingCount,
          );
    final trend = previous == null
      ? 'noRecordYet'
        : _behaviorEngine.evaluateConsecutiveSmokingTrend(
            previousHabit: previous.consecutiveSmokingHabit,
            previousCount: previous.consecutiveSmokingCount,
            currentHabit: current.consecutiveSmokingHabit,
            currentCount: current.consecutiveSmokingCount,
          );

    return {
      'latest': latestLabel,
      'previous': previousLabel,
      'trend': trend,
      'status': _behaviorEngine.evaluateConsecutiveSmokingStatus(
        habit: current.consecutiveSmokingHabit,
        count: current.consecutiveSmokingCount,
      ),
    };
  }

  Future<void> updateLastSurveyDate(DateTime date) async {
    await saveSetting('last_survey_date', date.toIso8601String());
  }

  Future<DateTime?> loadLastSurveyDate() async {
    final value = await loadSetting('last_survey_date');
    if (value == null) {
      return null;
    }
    return DateTime.parse(value);
  }

  Future<void> saveSleepTime(String sleepTime) async {
    await saveSetting('sleep_time', sleepTime);
  }

  Future<void> saveInitialRegistrationCompleted(bool completed) async {
    await saveSetting(_registrationCompletedKey, completed ? '1' : '0');
    await saveSetting(_isProfileCompletedKey, completed ? '1' : '0');
  }

  Future<void> saveIsProfileCompleted(bool completed) async {
    await saveSetting(_isProfileCompletedKey, completed ? '1' : '0');
  }

  Future<bool> loadIsProfileCompleted() async {
    final value = await loadSetting(_isProfileCompletedKey);
    return value == '1';
  }

  Future<bool> loadInitialRegistrationCompleted() async {
    final profileCompleted = await loadIsProfileCompleted();
    if (profileCompleted) {
      return true;
    }

    final value = await loadSetting(_registrationCompletedKey);
    if (value != null) {
      return value == '1';
    }

    final snapshot = await loadLatestBehaviorSnapshot();
    return snapshot != null;
  }

  Future<String?> loadSleepTime() async {
    return loadSetting('sleep_time');
  }

  Future<BehaviorDashboard?> loadLatestBehaviorSnapshot() async {
    final db = await database;
    final rows = await db.query(_behaviorSnapshotTable, orderBy: 'createdAt DESC', limit: 1);
    if (rows.isEmpty) {
      return null;
    }

    final raw = rows.first['snapshotJson'] as String;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final planData = data['plan'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return BehaviorDashboard(
      riskScore: (data['riskScore'] as num?)?.toInt() ?? 0,
      riskyTriggers: (data['riskyTriggers'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      riskyHours: (data['riskyHours'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      breathTrend: data['breathTrend']?.toString() ?? 'Stable',
      progressSummary: data['progressSummary']?.toString() ?? 'Stable',
      todaysTasks: (data['todaysTasks'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      predictedRiskWindow: data['predictedRiskWindow']?.toString() ?? '20:00-22:00',
      predictionConfidence: (data['predictionConfidence'] as num?)?.toInt() ?? 50,
      predictedTrigger: data['predictedTrigger']?.toString() ?? 'Stres',
      plan: AdaptivePlan(
        generatedAt: DateTime.tryParse(planData['generatedAt']?.toString() ?? '') ?? DateTime.now(),
        targetDays: (planData['targetDays'] as num?)?.toInt() ?? 180,
        currentWeek: (planData['currentWeek'] as num?)?.toInt() ?? 1,
        weeklyRiskTarget: (planData['weeklyRiskTarget'] as num?)?.toInt() ?? 50,
        difficulty: planData['difficulty']?.toString() ?? 'medium',
        focusAreas: (planData['focusAreas'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
      ),
    );
  }

  Future<Map<String, double>> loadBreathMetrics() async {
    final records = await loadSurveyHistory();
    final breathRecords = records.where((record) => record.type == 'breath_test').toList();

    if (breathRecords.isEmpty) {
      return {'dailyAverage': 0, 'weeklyAverage': 0, 'monthlyAverage': 0};
    }

    final now = DateTime.now();
    final todayRecords = breathRecords.where((record) => record.completedAt.year == now.year && record.completedAt.month == now.month && record.completedAt.day == now.day).toList();
    final weekRecords = breathRecords.where((record) => record.completedAt.isAfter(now.subtract(const Duration(days: 7)))).toList();
    final monthRecords = breathRecords.where((record) => record.completedAt.isAfter(now.subtract(const Duration(days: 30)))).toList();

    double calculateAverage(List<SurveyRecord> list) {
      if (list.isEmpty) {
        return 0;
      }
      final values = list.map((record) => ((record.exhaleTestSeconds + record.inhaleTestSeconds) / 2)).toList();
      return values.reduce((a, b) => a + b) / values.length;
    }

    return {
      'dailyAverage': calculateAverage(todayRecords),
      'weeklyAverage': calculateAverage(weekRecords),
      'monthlyAverage': calculateAverage(monthRecords),
    };
  }

  Future<SurveyRecord?> loadLatestBreathRecord() async {
    final records = await loadSurveyHistory();
    return records.reversed.where((record) => record.type == 'breath_test').firstOrNull;
  }

  Future<int> calculateAdjustedRiskScore({required int baseScore, required int exhaleSeconds, required int inhaleSeconds}) async {
    final records = await loadSurveyHistory();
    final breathRecords = records.where((record) => record.type == 'breath_test').toList();
    var adjustedScore = baseScore;

    if (breathRecords.isNotEmpty) {
      final previousAverage = ((breathRecords.last.exhaleTestSeconds + breathRecords.last.inhaleTestSeconds) / 2).round();
      final currentAverage = ((exhaleSeconds + inhaleSeconds) / 2).round();
      final difference = currentAverage - previousAverage;
      adjustedScore += difference * 2;
    }

    final latestSurvey = records.reversed.firstWhere(
      (record) => _surveyTypes.contains(record.type),
      orElse: () => SurveyRecord(
        id: 'fallback',
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        type: 'initial',
        title: 'Başlangıç',
        name: '',
        packsPerDay: '1 paketten az',
        exhaleTestSeconds: 0,
        inhaleTestSeconds: 0,
        riskScore: 0,
        riskLevel: 'BİLİNMEYEN',
      ),
    );

    if (latestSurvey.id != 'fallback') {
      adjustedScore += _behaviorEngine.calculatePackRiskContribution(latestSurvey.packsPerDay);
      adjustedScore += _behaviorEngine.calculateConsecutiveSmokingScore(
        habit: latestSurvey.consecutiveSmokingHabit,
        count: latestSurvey.consecutiveSmokingCount,
      );
    }

    return adjustedScore.clamp(0, 100);
  }

  Future<List<SurveyRecord>> _loadRelevantSurveyRecords() async {
    final records = await loadSurveyHistory();
    return records.where((record) => _surveyTypes.contains(record.type)).toList();
  }

  Future<BehaviorDashboard> loadBehaviorDashboard() async {
    final dirty = await isBehaviorDirty();
    if (!dirty) {
      final snapshot = await loadLatestBehaviorSnapshot();
      if (snapshot != null) {
        return snapshot;
      }
    }

    final existingSnapshot = await loadLatestBehaviorSnapshot();

    final records = await loadSurveyHistory();
    final triggerMap = await loadTriggerMapByRecordId();
    final contextMap = await loadSurveyContextByRecordId();
    final sensorEvents = await loadRecentSensorUsage();
    final taskHistory = await loadTaskHistory();

    final surveyRecords = records.where((record) => _surveyTypes.contains(record.type)).toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final breathRecords = records.where((record) => record.type == 'breath_test').toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    final triggerScores = _behaviorEngine.calculateTriggerScoresFromSurveyRecords(
      surveyRecords,
      triggerMap,
    );
    final riskyTriggers = _behaviorEngine.calculateRiskyTriggers(triggerScores);

    final riskyHours = _behaviorEngine.calculateRiskyHoursFromTimestamps(
      surveyTimes: surveyRecords.map((record) => record.completedAt).toList(),
      appUsageTimes: sensorEvents
          .where((event) => event.appUsageMinutes >= 5 || event.screenUnlockCount >= 6)
          .map((event) => event.createdAt)
          .toList(),
      taskFailureTimes: taskHistory
          .where((task) => !task.completed)
          .map((task) => task.date)
          .toList(),
      breathTestTimes: breathRecords.map((record) => record.completedAt).toList(),
    );

    final smokingTrend = _behaviorEngine.calculateSmokingTrendFromRecords(records);
    final breathTrend = _behaviorEngine.calculateBreathTrendFromRecords(records);
    final consecutiveTrend = _behaviorEngine.evaluateConsecutiveSmokingTrendFromRecords(records);
    final baseRisk = records.isEmpty ? 40 : records.last.riskScore;

    final latestSurvey = surveyRecords.isNotEmpty ? surveyRecords.last : null;
    final latestContext = latestSurvey == null ? null : contextMap[latestSurvey.id];
    final profileAdjustment = _behaviorEngine.calculateProfileRiskAdjustment(
      profession: latestContext?['profession'] as String?,
      sleepTime: latestContext?['sleepTime'] as String?,
      wakeTime: latestContext?['wakeTime'] as String?,
      healthConditions:
          (latestContext?['healthConditions'] as List<String>?) ?? const <String>[],
      packsPerDay: latestSurvey?.packsPerDay ?? '1 paketten az',
      consecutiveHabit: latestSurvey?.consecutiveSmokingHabit,
      consecutiveCount: latestSurvey?.consecutiveSmokingCount,
      hasBreathTests: breathRecords.isNotEmpty,
    );

    final dynamicRisk = (_behaviorEngine.calculateDynamicRiskScore(
      baseRiskScore: baseRisk,
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      consecutiveTrend: consecutiveTrend,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
    ) + profileAdjustment)
        .clamp(0, 100);

    final isFirstProfile =
        existingSnapshot == null && surveyRecords.any((record) => record.type == 'initial') && breathRecords.isNotEmpty;

    final taskRates = _behaviorEngine.calculateTaskSuccessRateMap(taskHistory);
    final todaysTasks = _behaviorEngine.generateAdaptiveTasks(
      riskScore: dynamicRisk,
      taskSuccessRates: taskRates,
      isFirstProfile: isFirstProfile,
      count: isFirstProfile ? 1 : 3,
    );

    final startDate = surveyRecords.isNotEmpty
        ? surveyRecords.first.completedAt
        : DateTime.now();
    final adaptivePlan = _behaviorEngine.buildAdaptivePlan180(
      startDate: startDate,
      riskScore: dynamicRisk,
      breathTrend: breathTrend,
      smokingTrend: smokingTrend,
      riskyTriggers: riskyTriggers,
    );

    final prediction = _behaviorEngine.predictNextRisk(
      riskyHours: riskyHours,
      riskyTriggers: riskyTriggers,
      riskScore: dynamicRisk,
      sensorEvents: sensorEvents,
    );

    final dashboard = _behaviorEngine.buildDashboard(
      riskScore: dynamicRisk,
      records: records,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      todaysTasks: todaysTasks,
      prediction: prediction,
      plan: adaptivePlan,
    );

    await saveBehaviorSnapshot({
      'riskScore': dashboard.riskScore,
      'riskyTriggers': dashboard.riskyTriggers,
      'riskyHours': dashboard.riskyHours,
      'breathTrend': dashboard.breathTrend,
      'progressSummary': dashboard.progressSummary,
      'todaysTasks': dashboard.todaysTasks,
      'predictedRiskWindow': dashboard.predictedRiskWindow,
      'predictionConfidence': dashboard.predictionConfidence,
      'predictedTrigger': dashboard.predictedTrigger,
      'plan': {
        'generatedAt': dashboard.plan.generatedAt.toIso8601String(),
        'targetDays': dashboard.plan.targetDays,
        'currentWeek': dashboard.plan.currentWeek,
        'weeklyRiskTarget': dashboard.plan.weeklyRiskTarget,
        'difficulty': dashboard.plan.difficulty,
        'focusAreas': dashboard.plan.focusAreas,
      },
    });
    await clearBehaviorDirty();

    return dashboard;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.delete(_tableName);
    await db.delete(_settingsTable);
    await db.delete(_surveyDetailsTable);
    await db.delete(_profileSnapshotTable);
    await db.delete(_languageHistoryTable);
    await db.delete(_sensorUsageTable);
    await db.delete(_behaviorSnapshotTable);
    await db.delete(_taskFollowUpTable);
  }
}
