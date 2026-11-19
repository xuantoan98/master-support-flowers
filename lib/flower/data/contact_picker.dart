import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

class PickedContact {
  const PickedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Opens a contact chooser; null when the user backs out.
typedef ContactPicker = Future<PickedContact?> Function();

/// Uses the system phone-number picker. The app only receives the one
/// contact the user taps, so no contacts permission is requested.
Future<PickedContact?> pickSystemContact() async {
  final contact = await FlutterNativeContactPicker().selectPhoneNumber();
  if (contact == null) {
    return null;
  }
  final numbers = contact.phoneNumbers ?? const <String>[];
  final phone =
      contact.selectedPhoneNumber ?? (numbers.isEmpty ? '' : numbers.first);
  return PickedContact(
    name: (contact.fullName ?? '').trim(),
    phone: normalizeVietnamesePhone(phone),
  );
}

/// Cleans a phone number from the address book: drops spaces and
/// punctuation and turns the +84 country code into a leading 0.
String normalizeVietnamesePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.startsWith('+84')) {
    digits = '0${digits.substring(3)}';
  } else if (digits.startsWith('0084')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('84') && digits.length == 11) {
    digits = '0${digits.substring(2)}';
  }
  return digits;
}
