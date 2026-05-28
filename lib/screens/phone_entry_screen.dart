import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/piligrim_route.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/piligrim_auth_view.dart';
import '../widgets/piligrim_tap.dart';
import 'onboarding_screen.dart';

/// Clean Scaffold wrapper around unified [PiligrimAuthView] for modal auth flows.
class PhoneEntryScreen extends StatelessWidget {
  const PhoneEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earthSurface,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PiligrimTap(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.close_rounded,
            color: PiligrimColors.sky,
          ),
        ),
      ),
      body: PiligrimAuthView(
        onSuccess: (isNewUser) {
          if (isNewUser) {
            context.read<AuthProvider>().clearNewUserFlag();
            Navigator.of(context).pushReplacement(
              PiligrimPageRoute(builder: (_) => const OnboardingScreen()),
            );
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
