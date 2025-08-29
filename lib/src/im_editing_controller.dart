import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Signature for building inline embedded widgets.
///
/// [data] is the original object passed when inserting (e.g. a user / topic model).
/// [style] is the base text style of the field for consistency.
/// [withComposing] mirrors the argument from [TextEditingController.buildTextSpan].
typedef ImBuildWidgetFunction =
    Widget Function({
      required BuildContext context,
      required dynamic data,
      TextStyle? style,
      required bool withComposing,
    });

/// Encapsulates a trigger definition:
/// - [onTrigger] receives the current keyword (excludes the trigger char) each time text changes while active.
/// - [builder] builds the inline widget once a value is inserted via [ImEditingController.insertTriggeredValue].
class ImTrigger {
  final ValueChanged<String> onTrigger;
  final ImBuildWidgetFunction builder;

  ImTrigger({required this.onTrigger, required this.builder});
}

/// Internal structure storing an embedded segment (either via builder or direct [WidgetSpan]).
class _Embedding {
  final dynamic value; // original data model
  final ImBuildWidgetFunction? builder; // builder for dynamic widget
  final WidgetSpan? widgetSpan; // directly provided span
  final String? plainText; // plain text representation for copying

  _Embedding({this.value, this.builder, this.widgetSpan, this.plainText});
}

/// Custom controller extending [TextEditingController] to support:
/// - Trigger definitions for mention-like behaviors.
/// - Inline rich embeddings represented by private Unicode placeholders.
class ImEditingController extends TextEditingController {
  /// Mapping from trigger character (e.g. '@') to its [ImTrigger].
  final Map<String, ImTrigger> triggers;

  /// Map of placeholder code -> embedding metadata.
  final Map<String, _Embedding> _data = {};

  /// Current advanced private unicode (starts at E000).
  var _customUnicode = '\uE000';

  ImEditingController(this.triggers);

  /// Converts an input string (which may contain custom unicode placeholders)
  /// into its plain text representation by replacing any embedded placeholders
  /// with the corresponding [_Embedding.plainText]. If a placeholder does not
  /// define a [plainText], it is removed from the output.
  String toPlainText(String text) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_isCustomUnicode(ch)) {
        final embedding = _data[ch];
        if (embedding != null) {
          if (embedding.plainText != null) buffer.write(embedding.plainText);
          continue;
        }
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  /// Returns the full plain text for the current controller text.
  String get fullPlainText => toPlainText(text);

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
  /// [plainText] is the plain text representation of the widget span. When copying, [plainText] will be used as the replacement content.
  ///
  /// Usually used to insert custom widgets like images or icons into the text field.
  void insertWidgetSpan(
    Object value,
    WidgetSpan widgetSpan, {
    String? plainText,
  }) {
    final unicode = _nextUnicode;
    _data[unicode] = _Embedding(
      widgetSpan: widgetSpan,
      value: value,
      plainText: plainText,
    );

    _replaceSelection(unicode);
  }

  /// Inserts a triggered value into the text field at the current cursor position.
  ///
  /// This method is typically used to insert special values or tokens when a trigger
  /// (such as a mention or command) is detected. The value will be inserted at the
  /// current selection or cursor location within the text field.
  /// [removePrefixMatch] indicates whether to delete the matching prefix content before inserting, default is true.
  /// [suffixSpace] indicates whether to add a space after inserting the content, default is true.
  /// [plainText] is the plain text representation of the value. When copying, [plainText] will be used as the replacement content.
  void insertTriggeredValue(
    String triggerChar,
    dynamic value, {
    bool removePrefixMatch = true,
    bool suffixSpace = true,
    String? plainText,
  }) {
    final trigger = triggers[triggerChar];
    if (trigger == null) return;

    final unicode = _nextUnicode;
    _data[unicode] = _Embedding(
      value: value,
      builder: trigger.builder,
      plainText: plainText,
    );

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
          final value = _data[part];
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
