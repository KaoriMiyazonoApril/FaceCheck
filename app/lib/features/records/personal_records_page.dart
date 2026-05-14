import 'package:facecheck_app/features/records/personal_records_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalRecordsPage extends ConsumerStatefulWidget {
  const PersonalRecordsPage({super.key});

  @override
  ConsumerState<PersonalRecordsPage> createState() => _PersonalRecordsPageState();
}

class _PersonalRecordsPageState extends ConsumerState<PersonalRecordsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(personalRecordsControllerProvider.notifier).loadRecords(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personalRecordsControllerProvider);
    final controller = ref.read(personalRecordsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance history')),
      body: state.isLoading && state.records.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.loadRecords,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (state.records.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No attendance records yet. Your completed check-ins will appear here.',
                        ),
                      ),
                    ),
                  for (final record in state.records) ...<Widget>[
                    Card(
                      child: ListTile(
                        title: Text(record.sessionName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(_formatTimestamp(record.checkinTime)),
                            if (record.message.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(record.message),
                            ],
                          ],
                        ),
                        isThreeLine: record.message.isNotEmpty,
                        trailing: Chip(label: Text(record.status)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
