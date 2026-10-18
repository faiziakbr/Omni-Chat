import 'dart:async';

/// Merges several streams into one; completes when all of them complete.
Stream<T> mergeStreams<T>(List<Stream<T>> streams) {
  late final StreamController<T> controller;
  final subs = <StreamSubscription<T>>[];
  var done = 0;
  controller = StreamController<T>(
    onListen: () {
      for (final s in streams) {
        subs.add(
          s.listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              if (++done == streams.length) controller.close();
            },
          ),
        );
      }
    },
    onPause: () {
      for (final s in subs) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subs) {
        s.resume();
      }
    },
    onCancel: () => Future.wait(subs.map((s) => s.cancel())),
  );
  return controller.stream;
}
