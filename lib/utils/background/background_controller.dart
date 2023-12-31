import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:background_fetch/background_fetch.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:sleep_tracker/logger/logger.dart';
import 'package:sleep_tracker/utils/background/background_state.dart';

/// Returns a controller that stores background accelerometer information
/// when the app is minimized or terminated.
abstract class BackgroundController {
  static BackgroundState state = const BackgroundState();
  static int status = 0;
  static const Duration epoch = Duration(seconds: 30);
  // static const String _backgroundFetchDefaultId = 'flutter_background_fetch';

  static Future<bool> restoreFromStorage() async {
    try {
      AppLogger.I.i('Restoring BackgroundState from SecureStorage.');
      final s = await state.fromStorage();
      if (s == null) {
        return false;
      }
      AppLogger.I.i('BackgroundState found in SecureStorage');

      state = s;
      return true;
    } catch (e, s) {
      AppLogger.I.e('Error restoring BackgroundState from SecureStorage', error: e, stackTrace: s);

      return false;
    }
  }

  /// Initialize the background_fetch platform service to
  /// retrieve accelerometer's data.
  static Future<void> init() async {
    await restoreFromStorage();
    if (status != 2) {
      try {
        status = await BackgroundFetch.configure(
            BackgroundFetchConfig(
              minimumFetchInterval: 15,
              forceAlarmManager: false,
              stopOnTerminate: false,
              startOnBoot: true,
              enableHeadless: Platform.isAndroid,
              requiresBatteryNotLow: false,
              requiresCharging: false,
              requiresStorageNotLow: false,
              requiresDeviceIdle: false,
              requiredNetworkType: NetworkType.NONE,
            ),
            _onBackgroundFetch,
            _onBackgroundFetchTimeout);
        AppLogger.I.i('Configure BackgroundFetch $status');

        AppLogger.I.i('Schedule BackgroundFetch Custom');
      } catch (e, s) {
        AppLogger.I.e('Error configure BackgroundFetch', error: e, stackTrace: s);
      }
    }
  }

  static Future<void> clear() async {
    state = state.copyWith(events: {});
    await state.localSave();
  }

  /// Runs when the app is running (with UI and components on screen).
  static void _onBackgroundFetch(String taskId) async {
    // This is the fetch-event callback.
    AppLogger.I.i("[BackgroundFetch] Event received: $taskId");

    final StreamSubscription accelerometerSubscription = userAccelerometerEvents.listen((event) {
      DateTime timestamp = DateTime.now();

      final double magnitude =
          math.max(math.sqrt(math.pow(event.x, 2) + math.pow(event.y, 2) + math.pow(event.z, 2)) - 1, 0.0);
      state = state.copyWith(events: {...state.events, timestamp: magnitude});
    });
    await Future.delayed(epoch, () {
      accelerometerSubscription.cancel();
    });
    await state.localSave();

    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish(taskId);
  }

  /// This event fires shortly before your task is about to timeout.  You must finish any outstanding work and call BackgroundFetch.finish(taskId).
  static void _onBackgroundFetchTimeout(String taskId) {
    AppLogger.I.i("[BackgroundFetch] TIMEOUT: $taskId");
    BackgroundFetch.finish(taskId);
  }

  /// This "Headless Task" is run when app is terminated.
  @pragma('vm:entry-point')
  static void backgroundFetchHeadlessTask(HeadlessTask task) async {
    var taskId = task.taskId;
    var timeout = task.timeout;
    if (timeout) {
      AppLogger.I.i("[BackgroundFetch] Headless task timed-out: $taskId");
      BackgroundFetch.finish(taskId);
      return;
    }

    AppLogger.I.i("[BackgroundFetch] Headless event received: $taskId");

    final StreamSubscription accelerometerSubscription = userAccelerometerEvents.listen((event) async {
      DateTime timestamp = DateTime.now();

      final double magnitude =
          math.max(math.sqrt(math.pow(event.x, 2) + math.pow(event.y, 2) + math.pow(event.z, 2)) - 1, 0.0);
      state = state.copyWith(events: {...state.events, timestamp: magnitude});
    });

    await Future.delayed(epoch, () {
      accelerometerSubscription.cancel();
    });
    await state.localSave();

    AppLogger.I.i("[BackgroundFetch] Headless event($taskId) schedules another subscription");

    BackgroundFetch.finish(taskId);
  }
}
