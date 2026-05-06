import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'splash_screen.dart';

class PannoApp extends StatelessWidget {
  const PannoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Piligrim',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF3D3A38),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF7BA5B8), // Мөлдір су — стальной синий
            secondary: Color(0xFFC4956A), // Сары дала — золотой песок
            surface:   Color(0xFF2A2826),
            onSurface: Color(0xFFF2EDE4), // Ақ аспан — кремовый
            error:     Color(0xFF8B1A1A), // Піскен жеміс — тёмно-красный
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFFF2EDE4),
            elevation: 0,
            titleTextStyle: GoogleFonts.outfit(
              color: const Color(0xFF7BA5B8),
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 2.5,
            ),
          ),
          cardColor: const Color(0xFF2A2826),
          dividerColor: const Color(0x1AF2EDE4),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
