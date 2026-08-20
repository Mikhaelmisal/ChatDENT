// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';

class ProcessManager {
  final List<int> _startedProcesses = [];
  bool _actionLock = false;
  Future<void> terminateProcess(int pid) async {
    try {
      final result = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
      if (result.exitCode == 0) {
        print('Successfully terminated process with PID: $pid');
      } else {
        print('Failed to terminate process with PID $pid');
      }
    } catch (e) {
      print('Error terminating process with PID $pid: $e');
    }
  }

  Future<void> terminateAllProcesses() async {
    if (_startedProcesses.isNotEmpty) {
      print('Terminating tracked processes... $_startedProcesses');
      for (var pid in _startedProcesses) {
        await terminateProcess(pid);
      }
      _startedProcesses.clear();
    }
    await terminateChildProcess();
  }

  Future<void> terminateChildProcess() async {
    try {
      final processes = await Process.run('tasklist', []);
      final lines = processes.stdout.toString().split('\n');
      for (var line in lines) {
        if (line.contains('chatdent') || line.contains('flutter')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final pid = int.tryParse(parts[1]);
            if (pid != null) {
              print('Terminating "chatdent" or "flutter" process with PID: $pid');
              await terminateProcess(pid);
            }
          }
        }
      }
    } catch (e) {
      print('Failed to terminate "chatdent" process: $e');
    }
  }

  Future<void> startIntegrationTest() async {
    try {
      print('Starting Flutter integration test process...');
      final process = await Process.start(
        'C:\\flutter\\flutter\\bin\\flutter.bat',
        ['test', 'integration_test/integration.dart', '-d', 'windows'],
        mode: ProcessStartMode.detachedWithStdio,
      );
      _startedProcesses.add(process.pid); // Track the PID
      print('Started process with PID: ${process.pid}');
    } catch (e) {
      print('Failed to start Flutter integration test: $e');
    }
  }
}

void main(List<String> args) async {
  final mode = args.firstOrNull ?? "--regular";
  final file = File("./integration_test/mode");
  await file.writeAsString(mode);

  final processManager = ProcessManager();
  final watcher = Directory("${Directory.current.path}/integration_test")
      .watch(events: FileSystemEvent.create | FileSystemEvent.modify | FileSystemEvent.delete);
  watcher.listen((event) async {
    if (!event.path.endsWith(".dart")) return;
    if (processManager._actionLock) {
      print('Action is already running. Skipping this event.');
      return;
    }
    processManager._actionLock = true;

    try {
      print('Change detected: ${event.type} on ${event.path}');
      await processManager.terminateAllProcesses();
      await processManager.startIntegrationTest();
    } catch (e) {
      print('Error handling file system event: $e');
    } finally {
      processManager._actionLock = false;
    }
  });

  print('File watcher started. Monitoring changes in ${Directory.current.path}.');
  await processManager.startIntegrationTest();
  await Future.delayed(const Duration(days: 365)); // Keep the process running indefinitely
}
