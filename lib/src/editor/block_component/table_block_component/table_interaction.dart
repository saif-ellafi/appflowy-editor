import 'package:flutter/material.dart';

const double tableDesktopResizeHitWidth = 12;
const double tableMobileResizeHitWidth = 44;

double tableResizeHitWidth(BuildContext context) {
  return tableIsTouchLayout(context)
      ? tableMobileResizeHitWidth
      : tableDesktopResizeHitWidth;
}

/// Transient interaction state for a table: caret location, and in-progress
/// column resize previews that must not touch the document.
class TableInteractionController extends ChangeNotifier {
  bool _isActive = false;
  int? _activeCol;
  int? _activeRow;
  int? _resizingColIdx;
  double? _previewWidth;
  double? _originalWidth;
  bool _atMinWidth = false;

  bool get isActive => _isActive;

  int? get activeCol => _activeCol;

  int? get activeRow => _activeRow;

  int? get resizingColIdx => _resizingColIdx;

  double? get previewWidth => _previewWidth;

  double? get originalWidth => _originalWidth;

  bool get atMinWidth => _atMinWidth;

  bool get isResizing => _resizingColIdx != null;

  double? previewWidthFor(int colIdx) {
    if (_resizingColIdx == colIdx) {
      return _previewWidth;
    }
    return null;
  }

  void setActive(bool value) {
    setCaret(inTable: value);
  }

  void setCaret({
    required bool inTable,
    int? col,
    int? row,
  }) {
    final nextCol = inTable ? col : null;
    final nextRow = inTable ? row : null;
    if (_isActive == inTable &&
        _activeCol == nextCol &&
        _activeRow == nextRow) {
      return;
    }
    _isActive = inTable;
    _activeCol = nextCol;
    _activeRow = nextRow;
    notifyListeners();
  }

  void beginResize(int colIdx, double originalWidth) {
    _resizingColIdx = colIdx;
    _originalWidth = originalWidth;
    _previewWidth = originalWidth;
    _atMinWidth = false;
    notifyListeners();
  }

  void updatePreview(double width, {required double minWidth}) {
    final clamped = width < minWidth ? minWidth : width;
    final atMin = width <= minWidth;
    if (_previewWidth == clamped && _atMinWidth == atMin) {
      return;
    }
    _previewWidth = clamped;
    _atMinWidth = atMin;
    notifyListeners();
  }

  void endResize() {
    if (_resizingColIdx == null) {
      return;
    }
    _resizingColIdx = null;
    _previewWidth = null;
    _originalWidth = null;
    _atMinWidth = false;
    notifyListeners();
  }
}

class TableInteractionScope extends InheritedNotifier<TableInteractionController> {
  const TableInteractionScope({
    super.key,
    required TableInteractionController controller,
    required super.child,
  }) : super(notifier: controller);

  static TableInteractionController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TableInteractionScope>()
        ?.notifier;
  }

  static TableInteractionController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'TableInteractionScope not found');
    return controller!;
  }
}

bool tableIsTouchLayout(BuildContext context) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}
