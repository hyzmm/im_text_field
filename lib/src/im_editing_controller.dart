import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef BuildWidgetFunction =
    Widget Function({
      required BuildContext context,
      required dynamic data,
      TextStyle? style,
      required bool withComposing,
    });

class ImTrigger {
  final ValueChanged<String> onTrigger;
  final BuildWidgetFunction builder;

  ImTrigger({required this.onTrigger, required this.builder});
}

class Embedding {
  final dynamic value;
  final BuildWidgetFunction? builder;
  final WidgetSpan? widgetSpan;

  Embedding({this.value, this.builder, this.widgetSpan});
}

class ImEditingController extends TextEditingController {
  final Map<String, ImTrigger> triggers;
  final Map<String, Embedding> data = {};
  var _customUnicode = '\uE000';

  ImEditingController(this.triggers);

  @override
  void clear() {
    _customUnicode = '\uE000';
    super.clear();
  }


  /// Inserts a [WidgetSpan] into the text at the current selection.
  ///
  /// Associates the given [value] with the [widgetSpan].
  /// The [widgetSpan] is embedded into the text at the current selection position,
  ///
  /// [value]: The object to associate with the inserted widget span.
  /// [widgetSpan]: The widget span to insert into the text.
  /// 
  /// Usually used to insert custom widgets like images or icons into the text field.
  void insertWidgetSpan(Object value, WidgetSpan widgetSpan) {
    final unicode = _nextUnicode;
    data[unicode] = Embedding(widgetSpan: widgetSpan, value: value);

    _replaceSelection(unicode);
  }

  /// Inserts a triggered value into the text field at the current cursor position.
  ///
  /// This method is typically used to insert special values or tokens when a trigger
  /// (such as a mention or command) is detected. The value will be inserted at the
  /// current selection or cursor location within the text field.
  /// [removePrefixMatch] indicates whether to delete the matching prefix content before inserting, default is true.
  /// [suffixSpace] indicates whether to add a space after inserting the content, default is true.
  void insertTriggeredValue(
    String triggerChar,
    dynamic value, {
    bool removePrefixMatch = true,
    bool suffixSpace = true,
  }) {
    final trigger = triggers[triggerChar];
    if (trigger == null) return;

    final unicode = _nextUnicode;
    data[unicode] = Embedding(value: value, builder: trigger.builder);

    if (selection.isCollapsed && removePrefixMatch) {
      // Find the [triggerChar] character before the cursor and select it up to the cursor position
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
            if (value.widgetSpan != null) {
              return value.widgetSpan!;
            }

            return WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: value.builder!(
                context: context,
                data: value.value,
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
