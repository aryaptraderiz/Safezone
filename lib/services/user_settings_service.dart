import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  Map<String, String> toMap() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromMap(Map<dynamic, dynamic> map) =>
      EmergencyContact(
        name: map['name']?.toString() ?? '',
        phone: map['phone']?.toString() ?? '',
      );
}

class UserSettingsService {
  static final ValueNotifier<List<EmergencyContact>> emergencyContacts =
      ValueNotifier(const []);

  static String _key(String suffix) {
    final uid = AuthService.currentUser?.uid ?? 'guest';
    return 'safezone.$uid.$suffix';
  }

  static Future<bool> getReportNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key('notifications.reports')) ?? true;
  }

  static Future<void> setReportNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('notifications.reports'), enabled);
  }

  static Future<bool> getNotificationSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key('notifications.sound')) ?? true;
  }

  static Future<void> setNotificationSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('notifications.sound'), enabled);
  }

  static Future<List<EmergencyContact>> loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key('emergency_contacts'));
    if (encoded == null) {
      emergencyContacts.value = const [];
      return emergencyContacts.value;
    }

    try {
      final decoded = jsonDecode(encoded);
      final contacts = decoded is List
          ? decoded
              .whereType<Map>()
              .map(EmergencyContact.fromMap)
              .where((contact) => contact.name.isNotEmpty && contact.phone.isNotEmpty)
              .toList()
          : <EmergencyContact>[];
      emergencyContacts.value = List.unmodifiable(contacts);
    } on FormatException {
      emergencyContacts.value = const [];
    }
    return emergencyContacts.value;
  }

  static Future<void> saveEmergencyContacts(
    List<EmergencyContact> contacts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key('emergency_contacts'),
      jsonEncode(contacts.map((contact) => contact.toMap()).toList()),
    );
    emergencyContacts.value = List.unmodifiable(contacts);
  }
}
