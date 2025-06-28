import 'package:flutter/services.dart';

class AppFlowyClipboardData {
  const AppFlowyClipboardData({
    this.text,
    this.html,
  });
  final String? text;
  final String? html;
}

class AppFlowyClipboard {
  static Future<void> setData({
    String? text,
    String? html,
  }) async {
    if (text == null) {
      return;
    }

    return Clipboard.setData(
      ClipboardData(
        text: text,
      ),
    );
  }

  static Future<AppFlowyClipboardData> getData() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return AppFlowyClipboardData(
      text: data?.text,
      html: null,
    );
  }
}
