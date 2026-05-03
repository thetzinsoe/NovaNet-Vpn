import 'package:flutter/services.dart';

/// Keeps only letters/digits and formats as `XXXX-XXXX-XXXX`.
class LicenseKeyInputFormatter extends TextInputFormatter {
  const LicenseKeyInputFormatter();

  static const maxChars = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final key = raw.length > maxChars ? raw.substring(0, maxChars) : raw;
    final buf = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      if (i == 4 || i == 8) buf.write('-');
      buf.write(key[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
