import 'package:chatdent/core/observable.dart';

class _Network {
  Map<String, void Function()> onOnline = {};
  Map<String, void Function()> onOffline = {};
  final isOnline = ObservableState(false);

  _Network() {
    isOnline.observe((_) {
      if (isOnline()) {
        for (var cb in onOnline.values) {
          cb();
        }
      } else {
        for (var cb in onOffline.values) {
          cb();
        }
      }
    });
  }
}

final network = _Network();
