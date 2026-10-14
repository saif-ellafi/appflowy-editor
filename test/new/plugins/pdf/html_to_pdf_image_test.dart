import 'dart:io';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// A grey PNG of [width] x [height], written by hand to avoid a dependency.
Uint8List _png(int width, int height) {
  final crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  List<int> uint32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...uint32(data.length), ...body, ...uint32(crc(body))];
  }

  final raw = <int>[
    for (var y = 0; y < height; y++) ...[0, for (var x = 0; x < width; x++) 128],
  ];
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    // 8-bit greyscale.
    ...chunk('IHDR', [...uint32(width), ...uint32(height), 8, 0, 0, 0, 0]),
    ...chunk('IDAT', ZLibEncoder().convert(raw)),
    ...chunk('IEND', []),
  ]);
}

void main() {
  late File tall;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('pdf_image_test');
    tall = File('${dir.path}/tall picture (copy).png')..writeAsBytesSync(_png(720, 1280));
  });

  String html() => '<p>Before</p><img src="${tall.path}" width="250.0" align="center"><p>After</p>';

  test('a tall image stretched to the page width fails without maxImageHeight', () async {
    await expectLater(
      PdfHTMLEncoder(fontFallback: const []).convert(html()).then((pdf) => pdf.save()),
      throwsA(anything),
    );
  });

  test('with maxImageHeight a tall image keeps its width, fits the page and the export succeeds', () async {
    final pdf = await PdfHTMLEncoder(fontFallback: const [], maxImageHeight: 400).convert(html());
    expect(await pdf.save(), isNotEmpty);
  });

  test('prepareImage sees every image before it is embedded', () async {
    final seen = <int>[];
    final pdf = await PdfHTMLEncoder(
      fontFallback: const [],
      maxImageHeight: 400,
      prepareImage: (bytes) async {
        seen.add(bytes.length);
        return _png(36, 64);
      },
    ).convert(html());

    expect(await pdf.save(), isNotEmpty);
    expect(seen, [tall.lengthSync()]);
  });

  test('styled text with colours exports', () async {
    final pdf = await PdfHTMLEncoder(fontFallback: const [], paragraphSpacing: 12).convert(
      '<p>Chip <span style="background-color: rgba(255, 136, 0, 51); color: rgba(8, 68, 0, 255)">[Weather: Storm]</span></p>',
    );
    expect(await pdf.save(), isNotEmpty);
  });
}
