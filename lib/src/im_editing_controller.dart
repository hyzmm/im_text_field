import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef BuildWidgetFunction<T> =
    Widget Function({
      required BuildContext context,
      required T data,
      TextStyle? style,
      required bool withComposing,
    });

class ImTrigger<T> {
  final ValueChanged<String> onTrigger;
  final BuildWidgetFunction<T> builder;

  ImTrigger({required this.onTrigger, required this.builder});
}

class ImEditingController<T> extends TextEditingController {
  final Map<String, ImTrigger<T>> triggers;
  final Map<String, (ImTrigger<T>, T)> data = {};
  var _customUnicode = '\uE000';

  ImEditingController(this.triggers);

  @override
  void clear() {
    _customUnicode = '\uE000';
    super.clear();
  }

  void replaceSelectionWithValue(
    String triggerChar,
    T value, {
    // [removePrefixMatch] 表示在插入内容前，是否向前删除匹配的前缀内容，默认为 false。
    bool removePrefixMatch = true,
    // [suffixSpace] 表示在插入内容后，是否添加一个空格，默认为 true。
    bool suffixSpace = true,
  }) {
    final trigger = triggers[triggerChar];
    if (trigger == null) return;

    final unicode = _nextUnicode;
    data[unicode] = (trigger, value);

    if (selection.isCollapsed && removePrefixMatch) {
      // 找到光标前面的 [triggerChar] 字符，并选中它到光标的位置
      final triggerIndexBeforeCursor = text.lastIndexOf(
        triggerChar,
        selection.start - 1,
      );
      if (triggerIndexBeforeCursor != -1) {
        selection = TextSelection(
          baseOffset: triggerIndexBeforeCursor,
          extentOffset: selection.start,
        );
      }

      _replaceSelection(unicode + (suffixSpace ? ' ' : ''));
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final parts = text.characters
        .splitBetween((a, b) => _isCustomUnicode(a) || _isCustomUnicode(b))
        .map((l) => l.join());
    return TextSpan(
      children: parts.map((part) {
        if (_isCustomUnicode(part)) {
          final value = data[part];
          if (value != null) {
            return WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: value.$1.builder(
                context: context,
                data: value.$2,
                style: style,
                withComposing: withComposing,
              ),
            );
          }
        }

        return TextSpan(text: part, style: style);
      }).toList(),
    );
  }

  void _replaceSelection(String text) {
    final selection = this.selection;
    this.text = this.text.replaceRange(selection.start, selection.end, text);
  }

  bool _isCustomUnicode(String text) {
    return text.codeUnitAt(0) >= 0xE000;
  }

  String get _nextUnicode {
    final current = _customUnicode;
    _customUnicode = String.fromCharCode(current.codeUnitAt(0) + 1);
    return current;
  }
}
