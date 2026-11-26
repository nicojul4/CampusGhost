import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Modal interaktif untuk memeriksa dan menyalin riwayat log sistem saat aplikasi
/// berjalan (on-running tracing).
class SystemLogViewerModal extends StatefulWidget {
  const SystemLogViewerModal({super.key});

  /// Menampilkan modal log viewer dalam bentuk BottomSheet atau Dialog.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SystemLogViewerModal(),
    );
  }

  @override
  State<SystemLogViewerModal> createState() => _SystemLogViewerModalState();
}

class _SystemLogViewerModalState extends State<SystemLogViewerModal> {
  LogLevel? _selectedLevel;
  final Set<int> _expandedIndices = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allLogs = logger.getLogs().reversed.toList();
    final filteredLogs = _selectedLevel == null
        ? allLogs
        : allLogs.where((l) => l.level == _selectedLevel).toList();

    final errorCount = allLogs.where((l) => l.level == LogLevel.error).length;
    final warningCount =
        allLogs.where((l) => l.level == LogLevel.warning).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.terminal_rounded,
                      color: colors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Sistem & Tracing',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Total: ${allLogs.length} | Error: $errorCount | Warn: $warningCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: errorCount > 0
                              ? colors.error
                              : colors.onSurfaceVariant,
                          fontWeight: errorCount > 0
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Action Toolbar & Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Semua'),
                          selected: _selectedLevel == null,
                          onSelected: (_) =>
                              setState(() => _selectedLevel = null),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: Text('Error ($errorCount)'),
                          selected: _selectedLevel == LogLevel.error,
                          selectedColor: colors.errorContainer,
                          labelStyle: TextStyle(
                            color: _selectedLevel == LogLevel.error
                                ? colors.onErrorContainer
                                : null,
                          ),
                          onSelected: (_) => setState(
                              () => _selectedLevel = LogLevel.error),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: Text('Warning ($warningCount)'),
                          selected: _selectedLevel == LogLevel.warning,
                          onSelected: (_) => setState(
                              () => _selectedLevel = LogLevel.warning),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Info'),
                          selected: _selectedLevel == LogLevel.info,
                          onSelected: (_) =>
                              setState(() => _selectedLevel = LogLevel.info),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Debug'),
                          selected: _selectedLevel == LogLevel.debug,
                          onSelected: (_) =>
                              setState(() => _selectedLevel = LogLevel.debug),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Salin Seluruh Log',
                  icon: const Icon(Icons.copy_all_rounded, size: 20),
                  onPressed: () async {
                    final text = logger.getFormattedLogs();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Seluruh log berhasil disalin ke clipboard! Siap ditempel ke Issue/Chat.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: 'Bersihkan Log',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  onPressed: () {
                    setState(() {
                      logger.clearLogs();
                      _expandedIndices.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Log List
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 48, color: colors.outline),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada catatan log pada filter ini.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      final isExpanded = _expandedIndices.contains(index);
                      final hasDetails =
                          item.error != null || item.stackTrace != null;

                      final (badgeBg, badgeFg, icon) = switch (item.level) {
                        LogLevel.error => (
                            colors.errorContainer,
                            colors.onErrorContainer,
                            Icons.error_outline_rounded
                          ),
                        LogLevel.warning => (
                            Colors.amber.shade100,
                            Colors.amber.shade900,
                            Icons.warning_amber_rounded
                          ),
                        LogLevel.info => (
                            colors.primaryContainer,
                            colors.primary,
                            Icons.info_outline_rounded
                          ),
                        LogLevel.debug => (
                            colors.surfaceContainerHighest,
                            colors.onSurfaceVariant,
                            Icons.bug_report_outlined
                          ),
                      };

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colors.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        child: InkWell(
                          onTap: hasDetails
                              ? () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedIndices.remove(index);
                                    } else {
                                      _expandedIndices.add(index);
                                    }
                                  });
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(icon, size: 12, color: badgeFg),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.level.name,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: badgeFg,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.module,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      item.timeFormatted,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    if (hasDetails) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        isExpanded
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        size: 16,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  item.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    fontFamily: 'monospace',
                                    color: colors.onSurface,
                                  ),
                                ),
                                if (isExpanded && hasDetails) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      'Error: ${item.error}\n\nStackTrace:\n${item.stackTrace}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        height: 1.4,
                                        fontFamily: 'monospace',
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
