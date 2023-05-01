import 'dart:collection';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:logger_flutter_plus/logger_flutter_plus.dart';
import 'package:logger_flutter_plus/src/models/log_rendered_event.dart';
import 'package:logger_flutter_plus/src/utils/ansi_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogConsoleManager extends ChangeNotifier {
  LogConsoleManager({
    required bool isDark,
  }) : _ansiParser = AnsiParser(isDark);

  final ListQueue<OutputEvent> _events = ListQueue();
  final ListQueue<LogRenderedEvent> _buffer = ListQueue();
  final AnsiParser _ansiParser;

  Level? _filterLevel;
  String _filterText = '';

  List<LogRenderedEvent> get logs => _buffer
      .where((element) =>
          _filterLevel == null ? true : element.level == _filterLevel)
      .where((element) => _filterText.isEmpty
          ? true
          : element.lowerCaseText.contains(_filterText))
      .toList();

  void setFilterLevel(Level? level) {
    _filterLevel = level;
    notifyListeners();
  }

  void setFilterText(String filterText) {
    _filterText = filterText;
    notifyListeners();
  }

  void clearLogs() {
    _buffer.clear();
    notifyListeners();
  }

  void addLog(OutputEvent event) {
    _events.add(event);
    final text = event.lines.join('\n');
    _ansiParser.parse(text);

    final logEvent = LogRenderedEvent(
      id: (_buffer.lastOrNull?.id ?? 0) + 1,
      level: event.level,
      span: TextSpan(children: _ansiParser.spans),
      lowerCaseText: text.toLowerCase(),
    );

    _buffer.add(logEvent);
    notifyListeners();
  }

  Future<void> shareLogText() async {
    final buffer = StringBuffer();
    for (final event in _events) {
      buffer.write(event.lines.join('\n'));
      buffer.write('\n');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'log-${DateTime.now().microsecondsSinceEpoch}.txt';
    final filePath = '${tempDir.path}/$fileName';
    final f = File(filePath);
    f.writeAsStringSync(buffer.toString(), flush: true);
    // final xFile = XFile(filePath, mimeType: 'text/plain');
    await Share.shareFilesWithResult(
      [filePath],
      mimeTypes: ['text/plain'],
      subject: 'logfile-${DateTime.now()}',
    );
    f.deleteSync();
  }
}
