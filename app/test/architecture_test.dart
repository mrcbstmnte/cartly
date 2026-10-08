import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the api client imports package:http', () {
    final offenders = <String>[];

    for (final path in ['lib/ui', 'lib/state', 'lib/data/models']) {
      final directory = Directory(path);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains('package:http/')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Widgets and state must go through CartlyApiClient, '
          'not call http directly.',
    );
  });

  test('the app never talks to firebase directly', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:firebase') ||
          source.contains('package:cloud_firestore')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The app must reach Firestore only through the NestJS API.',
    );
  });
}
