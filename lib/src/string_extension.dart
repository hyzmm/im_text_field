extension StringExtension on String {
  bool get isWhitespace => trim().isEmpty;

  // 判断字符是否为英文、英文符号、数字
  bool get isAlphaNumSymbol {
    final code = codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || (code == 32);
  }
}
