import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:im_text_field/im_text_field.dart';
import 'package:im_text_field/src/string_extension.dart';

const _kUnusedUnicodeStart = 0xe000;

/// Signature for building inline embedded widgets.
///
/// [data] is the original dynamic passed when inserting (e.g. a user / topic model).
/// [style] is the base text style of the field for consistency.
/// [withComposing] mirrors the argument from [TextEditingController.buildTextSpan].
typedef ImBuildWidgetFunction<T> =
    Widget Function(
      BuildContext context,
      T data,
      TextStyle? style,
      bool withComposing,
    );

/// Encapsulates a trigger definition:
/// - [onTrigger] receives the current keyword (excludes the trigger char) each time text changes while active.
/// - [builder] builds the inline widget once a value is inserted via [ImEditingController.insertTriggeredValue].
class ImTrigger<T> {
  final ValueChanged<String> onTrigger;
  final ImBuildWidgetFunction<T> builder;
  final String Function(T data) markupBuilder;

  ImTrigger({
    required this.onTrigger,
    required this.builder,
    required this.markupBuilder,
  });
}

/// Internal structure storing an embedded segment (either via builder or direct [WidgetSpan]).
class _Embedding {
  final dynamic value; // original data model
  final Widget Function(
    BuildContext context,
    TextStyle? style,
    bool withComposing,
  )?
  builder; // builder for dynamic widget
  final WidgetSpan? widgetSpan; // directly provided span
  final String? display; // plain text representation for copying
  final String? triggerChar; // the trigger character used for this embedding

  _Embedding({
    this.value,
    this.builder,
    this.widgetSpan,
    this.display,
    this.triggerChar,
  });
}

/// Custom controller extending [TextEditingController] to support:
/// - Trigger definitions for mention-like behaviors.
/// - Inline rich embeddings represented by private Unicode placeholders.
class ImEditingController extends TextEditingController {
  /// Maximum length of the match to search for before the cursor.
  final int maxMatchLength;

  /// Called when the user finishes matching
  final VoidCallback onFinishMatching;

  /// Mapping from trigger character (e.g. '@') to its [ImTrigger].
  final TypedMap triggers;

  /// Map of placeholder code -> embedding metadata.
  final Map<String, _Embedding> _data = {};

  /// Current advanced private unicode (starts at F0000).
  var _customUnicode = _kUnusedUnicodeStart;

  Function(TextPosition position)? bringIntoView;
  final VoidCallback? onInsertEmbedding;

  ImEditingController({
    required Map<String, dynamic> triggers,
    this.maxMatchLength = 50,
    required this.onFinishMatching,
    this.onInsertEmbedding,
  }) : triggers = TypedMap(triggers) {
    addListener(_onChanged);
  }

  String get markupText {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_isCustomUnicode(ch)) {
        final embedding = _data[ch];
        if (embedding?.triggerChar != null) {
          final trigger = triggers.get<dynamic>(embedding!.triggerChar!);
          if (trigger != null) {
            buffer.write(trigger.markupBuilder(embedding.value));
            continue;
          }
        } else {
          if (embedding?.display != null) {
            buffer.write(embedding!.display);
            continue;
          }
        }
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  /// Converts an input string (which may contain custom unicode placeholders)
  /// into its plain text representation by replacing any embedded placeholders
  /// with the corresponding [_Embedding.display]. If a placeholder does not
  /// define a [display], it is removed from the output.
  String toPlainText(String text) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_isCustomUnicode(ch)) {
        final embedding = _data[ch];
        if (embedding != null) {
          // Add space before if previous char is not space and not at start
          if (buffer.isNotEmpty &&
              buffer.toString().codeUnitAt(buffer.length - 1) != 0x20) {
            buffer.write(' ');
          }
          if (embedding.display != null) buffer.write(embedding.display);
          // Add space after if next char is not space and not at end
          if (i + 1 < text.length && text.codeUnitAt(i + 1) != 0x20) {
            buffer.write(' ');
          }
          continue;
        }
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  String get plainText => toPlainText(text);

  @override
  void clear() {
    _customUnicode = _kUnusedUnicodeStart;
    super.clear();
  }

  /// Inserts a [WidgetSpan] into the text at the current selection.
  ///
  /// Associates the given [value] with the [widgetSpan].
  /// The [widgetSpan] is embedded into the text at the current selection position,
  ///
  /// [value]: The dynamic to associate with the inserted widget span.
  /// [display] is the plain text representation of the widget span. When copying, [display] will be used as the replacement content.
  ///
  /// Usually used to insert custom widgets like images or icons into the text field.
  void insertWidgetSpan(String? display, WidgetSpan widgetSpan) {
    final unicode = _nextUnicode;
    _data[unicode] = _Embedding(widgetSpan: widgetSpan, display: display);

    replaceSelection(unicode);
    bringIntoView?.call(selection.extent);
    onInsertEmbedding?.call();
  }

  /// Inserts a triggered value into the text field at the current cursor position.
  ///
  /// This method is typically used to insert special values or tokens when a trigger
  /// (such as a mention or command) is detected. The value will be inserted at the
  /// current selection or cursor location within the text field.
  /// [removePrefixMatch] indicates whether to delete the matching prefix content before inserting, default is true.
  /// [suffixSpace] indicates whether to add a space after inserting the content, default is true.
  /// [display] is the plain text representation of the value. When copying, [display] will be used as the replacement content.
  void insertTriggeredValue<T>(
    String triggerChar,
    T value, {
    bool removePrefixMatch = false,
    bool suffixSpace = true,
    String? display,
  }) {
    final trigger = triggers.get<ImTrigger<T>>(triggerChar);
    if (trigger == null) return;

    final unicode = _nextUnicode;
    _data[unicode] = _Embedding(
      value: value as dynamic,
      builder: (context, style, withComposing) =>
          trigger.builder(context, value, style, withComposing),
      display: display,
      triggerChar: triggerChar,
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
    }
    replaceSelection(unicode + (suffixSpace ? ' ' : ''));
    onInsertEmbedding?.call();
    bringIntoView?.call(selection.extent);
  }

  /// Inserts a trigger character at the current cursor position.
  /// If the character before the cursor is a word character(same as [^A-Za-z0-9_]), a space will be added before the trigger character
  void insertTriggerChar(String char) {
    var start = selection.start;
    if (start == -1) start = text.length;
    final insertSpace = start > 0 && text[start - 1].isWordCharacter;
    replaceSelection(insertSpace ? ' $char' : char);
    bringIntoView?.call(selection.extent);
  }

  @override
  dispose() {
    removeListener(_onChanged);
    super.dispose();
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
              child: value.builder!(context, style, withComposing),
            );
          }
        }

        return TextSpan(text: part, style: style);
      }).toList(),
    );
  }

  void replaceSelection(String t) {
    var selection = this.selection;
    TextSelection newSelection;
    if (selection.isValid) {
      newSelection = TextSelection.collapsed(
        offset: selection.start + t.length,
      );
    } else {
      selection = TextSelection.collapsed(offset: text.length);
      newSelection = TextSelection.collapsed(offset: text.length + t.length);
    }

    value = value.copyWith(
      text: text.replaceRange(
        max(0, selection.start),
        max(0, selection.end),
        t,
      ),
      selection: newSelection,
      composing: TextRange.empty,
    );
  }

  bool _isCustomUnicode(String text) {
    // return text.runes.first >= _kUnusedUnicodeStart;
    return text.codeUnitAt(0) >= _kUnusedUnicodeStart;
  }

  _onChanged() {
    final beforeCursor = selection.baseOffset - 1;
    if (beforeCursor < 0) {
      // cursor is before the start of the text
      onFinishMatching();
      return;
    }

    // Starting from beforeCursor, search backwards up to [maxMatchLength] characters to find a match in [controller.triggers]
    String? matchingChars;
    for (
      int i = beforeCursor;
      i >= 0 && i > beforeCursor - maxMatchLength;
      i--
    ) {
      final char = text[i];
      if (triggers.contains(char)) {
        if (i == 0) {
          matchingChars = text.substring(0, beforeCursor + 1);
        } else {
          final beforeTrigger = text[i - 1];
          // If it is a space or a non-English character, trigger matching.
          if (beforeTrigger.isWhitespace || !beforeTrigger.isWordCharacter) {
            matchingChars = text.substring(i, beforeCursor + 1);
          }
        }
        break;
      } else if (char.isWhitespace) {
        // Stop searching if a whitespace is encountered
        break;
      }
    }

    if (matchingChars == null) {
      onFinishMatching();
      return;
    }

    final triggerChar = matchingChars[0];
    final trigger = triggers.get(triggerChar)!;
    trigger.onTrigger(matchingChars.substring(1));
  }

  String get _nextUnicode {
    final char = String.fromCharCode(_customUnicode + 1);
    _customUnicode++;
    return char;
  }
}
