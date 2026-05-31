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
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: PiligrimTap(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: PiligrimColors.sky.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Назад',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
