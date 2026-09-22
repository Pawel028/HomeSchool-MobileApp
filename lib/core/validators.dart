/// Pure input validation shared by the forms (and unit-tested).
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _pin = RegExp(r'^\d{4,6}$');
  static final RegExp _otp = RegExp(r'^\d{6}$');

  static bool isEmail(String v) => _email.hasMatch(v.trim());

  /// The API needs 10 to 128 characters.
  static bool isPassword(String v) => v.length >= 10 && v.length <= 128;

  static bool isPin(String v) => _pin.hasMatch(v);

  static bool isOtp(String v) => _otp.hasMatch(v);

  static bool isBirthYear(String v, int currentYear) {
    final int? y = int.tryParse(v.trim());
    if (y == null) return false;
    return y >= 2000 && y <= currentYear;
  }

  /// Turns what a parent types ("98765 43210", "+91 98765-43210", "09876543210") into "+919876543210".
  /// Returns null when it cannot be a phone number (the API pattern is `^\+?[0-9]{8,15}$`).
  static String? normalizePhone(String raw) {
    String s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.isEmpty) return null;
    final bool plus = s.startsWith('+');
    if (plus) s = s.substring(1);
    if (!RegExp(r'^\d+$').hasMatch(s)) return null;
    if (!plus) {
      if (s.length == 10) {
        s = '91$s';
      } else if (s.length == 11 && s.startsWith('0')) {
        s = '91${s.substring(1)}';
      }
    }
    if (s.length < 8 || s.length > 15) return null;
    return '+$s';
  }
}
