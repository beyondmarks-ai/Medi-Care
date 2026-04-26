import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medicare_ai/services/app_log_service.dart';

class AppLogsScreen extends StatelessWidget {
  const AppLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            onPressed: () => _copyAllLogs(context),
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy all logs',
          ),
          IconButton(
            onPressed: () {
              AppLogService.instance.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared.')),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: ValueListenableBuilder<List<AppLogEntry>>(
        valueListenable: AppLogService.instance.logs,
        builder: (context, entries, _) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No logs captured yet.\n\nRun the action again and reopen this screen to inspect errors.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[entries.length - 1 - index];
              final stack = entry.stackTrace?.toString();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            entry.level == 'ERROR'
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            color: entry.level == 'ERROR'
                                ? Colors.redAccent
                                : Colors.blueAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.level} • ${entry.timestamp.toLocal()}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(entry.message),
                      if (entry.error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Error: ${entry.error}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                      if (stack != null && stack.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          stack,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _copyAllLogs(context),
        icon: const Icon(Icons.copy_rounded),
        label: const Text('Copy All Logs'),
      ),
    );
  }

  Future<void> _copyAllLogs(BuildContext context) async {
    final content = AppLogService.instance.exportAll();
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All logs copied to clipboard.')),
    );
  }
}
