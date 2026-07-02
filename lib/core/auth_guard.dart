import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/phone_entry_screen.dart';

/// Auth Guard — вызывать перед действиями, требующими входа.
///
/// ```dart
/// if (!await guardAuth(context)) return;
/// // продолжить действие
/// ```
Future<bool> guardAuth(BuildContext context) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;

  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
  );

  if (!context.mounted) return false;
  return context.read<AuthProvider>().isLoggedIn;
}
