import 'package:flutter_test/flutter_test.dart';
import 'package:novanet_vpn/features/license/presentation/license_key_input_formatter.dart';

void main() {
  const formatter = LicenseKeyInputFormatter();

  test('formats digits with dashes', () {
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '123456789012'),
    );
    expect(out.text, '1234-5678-9012');
  });

  test('accepts letters and uppercases them', () {
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'ursnb88ga5dr'),
    );
    expect(out.text, 'URSN-B88G-A5DR');
  });

  test('strips unsupported characters', () {
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'URSN!B88G_A5DR'),
    );
    expect(out.text, 'URSN-B88G-A5DR');
  });

  test('caps at 12 characters', () {
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '1234567890123456'),
    );
    expect(out.text, '1234-5678-9012');
  });
}
