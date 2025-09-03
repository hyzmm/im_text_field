extension StringExtension on String {
  bool get isWhitespace => trim().isEmpty;

  bool get isWordCharacter {
    if (isEmpty) return false;
    final code = codeUnitAt(0);
    // \w matches [A-Za-z0-9_]
    return (code >= 65 && code <= 90) || // A-Z
           (code >= 97 && code <= 122) || // a-z
           (code >= 48 && code <= 57) || // 0-9
           (code == 95); // _
  }
}
