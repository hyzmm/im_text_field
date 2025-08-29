import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_text_field/im_text_field.dart';

class PlainCopyAction extends Action<CopySelectionTextIntent> {
  final ImEditingController controller;
  final FocusNode? focusNode;
  PlainCopyAction(this.controller, this.focusNode);

  @override
  Object? invoke(CopySelectionTextIntent intent) {
    final selection = controller.selection;
    if (selection.isCollapsed) return null;
    final selectedRaw = selection.textInside(controller.text);
    final plain = controller.toPlainText(selectedRaw);
    Clipboard.setData(ClipboardData(text: plain));

    // If it is a cut operation, delete the selected content
    if (intent.collapseSelection) {
      final newText =
          selection.textBefore(controller.text) +
          selection.textAfter(controller.text);
      final newSelection = TextSelection.collapsed(offset: selection.start);
      controller.value = controller.value.copyWith(
        text: newText,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }

    return null;
  }

  @override
  bool get isActionEnabled {
    return (focusNode?.hasFocus ?? true) && !controller.selection.isCollapsed;
  }
}
