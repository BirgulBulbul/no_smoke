import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class TaskFollowUpPage extends StatefulWidget {
  const TaskFollowUpPage({super.key});

  @override
  State<TaskFollowUpPage> createState() => _TaskFollowUpPageState();
}

class _TaskFollowUpPageState extends State<TaskFollowUpPage> {
  final StorageService _storageService = StorageService();
  bool _loading = true;
  List<Map<String, dynamic>> _pending = const [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await _storageService.loadPendingTaskFollowUps();
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _saveOutcome({
    required String taskTitle,
    required bool success,
  }) async {
    if (!success) {
      await _storageService.saveProtocolViolation(
        type: 'followup_failed',
        severity: 'medium',
        source: 'app_flow',
        taskTitle: taskTitle,
        details: 'Task follow-up marked as unsuccessful.',
      );
    }
    await _storageService.saveTaskResult(
      taskTitle: taskTitle,
      taskResult: success ? 'willpower_success' : 'willpower_weakness',
      completedAt: DateTime.now(),
    );
    await _storageService.resolveTaskFollowUpByTitle(taskTitle);
    await _loadPending();
  }

  Future<void> _deferAgain(String taskTitle) async {
    await _storageService.saveProtocolViolation(
      type: 'followup_deferred',
      severity: 'low',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'User deferred follow-up from dedicated follow-up screen.',
    );
    final nextTime = DateTime.now().add(const Duration(minutes: 10));
    await _storageService.saveTaskFollowUp(taskTitle: taskTitle, scheduledAt: nextTime);
    await NotificationService.scheduleTaskFollowUpReminder(
      taskTitle: taskTitle,
      delay: const Duration(minutes: 10),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('taskDeferredTenMinutes'))),
    );
    await _loadPending();
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('taskFollowUpTitle')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? Center(
                  child: Text(context.t('taskFollowUpEmpty')),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = _pending[index];
                    final taskTitle = row['taskTitle'] as String;
                    final scheduledAt = row['scheduledAt'] as DateTime;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              taskTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${context.t('taskFollowUpScheduledAt')}: ${_formatDateTime(scheduledAt)}'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _saveOutcome(taskTitle: taskTitle, success: true),
                                  child: Text(context.t('taskOutcomeYes')),
                                ),
                                OutlinedButton(
                                  onPressed: () => _saveOutcome(taskTitle: taskTitle, success: false),
                                  child: Text(context.t('taskOutcomeNo')),
                                ),
                                TextButton(
                                  onPressed: () => _deferAgain(taskTitle),
                                  child: Text(context.t('taskNotNowButton')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
