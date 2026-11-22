import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:village_outreach/features/requests/photos/request_photo_panel.dart';
import 'package:village_outreach/features/requests/photos/request_photo_repository.dart';

// A memory-only XFile test double. Unlike XFile.fromData, it never
// schedules platform or file-system work in Flutter's fake-async zone.
class MemoryPhotoFile implements XFile {
  MemoryPhotoFile(this._data, {required this.name});

  final Uint8List _data;
  @override
  final String name;

  @override
  Future<Uint8List> readAsBytes() async => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePicker implements RequestPhotoPicker {
  FakePicker(this.value, {this.denied = false});
  final XFile? value;
  final bool denied;
  @override
  Future<XFile?> pick() async {
    if (denied) throw Exception('Permission denied');
    return value;
  }
}

class FakeRepository implements RequestPhotoRepository {
  int calls = 0;
  final List<String> keys = [];
  bool failFirst = false;
  int refreshes = 0;
  @override
  Future<List<RequestPhoto>> list(String requestId) async => [];
  @override
  Future<RequestPhoto> upload({
    required String requestId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String idempotencyKey,
    required void Function(double) onProgress,
  }) async {
    calls++;
    keys.add(idempotencyKey);
    if (failFirst && calls == 1) {
      throw const PhotoUploadException('Network error');
    }
    onProgress(1);
    return RequestPhoto(
      id: 'photo-1',
      requestId: requestId,
      viewUrl: 'https://example.test/private',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<RequestPhoto> refreshViewingUrl(
    String requestId,
    String photoId,
  ) async {
    refreshes++;
    return RequestPhoto(
      id: photoId,
      requestId: requestId,
      viewUrl: 'https://example.test/refreshed',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }
}

void main() {
  test('private photo links refresh before expiry', () {
    final expired = RequestPhoto(
      id: 'p',
      requestId: 'r',
      viewUrl: 'private',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    expect(expired.needsRefresh(DateTime.now()), isTrue);
  });

  testWidgets('denied permission does not crash the request', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestPhotoPanel(
            requestId: 'r',
            picker: FakePicker(null, denied: true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('media permissions'), findsOneWidget);
  });

  testWidgets('invalid file is rejected before upload', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestPhotoPanel(
            requestId: 'r',
            picker: FakePicker(
              XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'bad.txt'),
            ),
            repository: repo,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('JPEG'), findsOneWidget);
    expect(repo.calls, 0);
  });

  testWidgets('retry reuses idempotency key', (tester) async {
    final photo = MemoryPhotoFile(
      Uint8List.fromList([1, 2, 3]),
      name: 'ok.jpg',
    );

    final repo = FakeRepository()..failFirst = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestPhotoPanel(
            requestId: 'r',
            picker: FakePicker(photo),
            repository: repo,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Upload photo'), findsOneWidget);
    await tester.tap(find.text('Upload photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Retry upload'), findsOneWidget);
    await tester.tap(find.text('Retry upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.calls, 2);
    expect(repo.keys, hasLength(2));
    expect(repo.keys[0], repo.keys[1]);
  });
}
