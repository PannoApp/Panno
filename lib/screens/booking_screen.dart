// Бронирование зала — «Путь Героя к столу»
// Выбор зоны, даты, кол-ва героев, подтверждение. Согласно ТЗ раздел 4.4
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_guard.dart';
import '../core/interior_assets.dart';
import '../core/theme.dart';
import '../data/models/booking_request.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/core_info_provider.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/path_cta.dart';
import '../widgets/piligrim_toast.dart';
import '../widgets/piligrim_cta.dart';
import '../widgets/piligrim_tap.dart';
import '../core/piligrim_route.dart';
import 'booking_success_screen.dart';

String bookingTimeForApi(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController(text: '2');

  DateTime _visitDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _visitTime = const TimeOfDay(hour: 19, minute: 30);
  String? _selectedZone = 'Главный зал';

  static const _zones = ['Главный зал', 'Терраса', 'Приват'];
  static const _zoneApiMap = {
    'Главный зал': 'main',
    'Терраса': 'terrace',
    'Приват': 'private',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;
      _nameCtrl.text = auth.user.name;
      final phone = auth.user.phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (phone.isNotEmpty) _phoneCtrl.text = phone;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _commentCtrl.dispose();
    _guestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            surface: PiligrimColors.earthDeep,
            primary: PiligrimColors.water,
            onPrimary: PiligrimColors.sky,
            onSurface: PiligrimColors.sky,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            surface: PiligrimColors.earthDeep,
            primary: PiligrimColors.water,
            onPrimary: PiligrimColors.sky,
            onSurface: PiligrimColors.sky,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _visitTime = picked);
  }

  String get _timeForApi => bookingTimeForApi(_visitTime);

  String get _dateForApi {
    final d = _visitDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!await guardAuth(context)) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final booking = context.read<BookingProvider>();
    final req = BookingRequest(
      guestName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      date: _dateForApi,
      time: _timeForApi,
      guestsCount: int.parse(_guestsCtrl.text),
      zone: _selectedZone != null ? _zoneApiMap[_selectedZone] : null,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    );

    await booking.submitBooking(req);
    if (!mounted) return;

    if (booking.isSuccess) {
      final dateText = _dateLabel;
      final timeText = _timeLabel;
      final count = int.parse(_guestsCtrl.text);
      final zoneText = _selectedZone;

      _nameCtrl.clear();
      _commentCtrl.clear();
      setState(() {
        _selectedZone = null;
        _visitDate = DateTime.now().add(const Duration(days: 1));
        _visitTime = const TimeOfDay(hour: 19, minute: 0);
      });

      Navigator.of(context).push(
        PiligrimPageRoute<void>(
          builder: (_) => BookingSuccessScreen(
            date: dateText,
            time: timeText,
            heroesCount: count,
            zone: zoneText,
          ),
        ),
      );
    } else if (booking.error != null) {
      PiligrimToast.show(
        context,
        booking.error!,
        type: PiligrimToastType.error,
      );
    }
  }

  String get _dateLabel {
    final d = _visitDate;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String get _timeLabel {
    final h = _visitTime.hour.toString().padLeft(2, '0');
    final m = _visitTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final depositRequired =
        context.watch<CoreInfoProvider>().coreInfo?.bookingDepositRequired ?? false;

    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: Stack(
        children: [
          const Positioned.fill(
            child: PiligrimBackground(
              textureOpacity: 0.45,
              vignetteIntensity: 0.25,
              cinematic: true,
            ),
          ),
          Builder(
            builder: (ctx) {
              // viewPadding is the raw device safe-area — never consumed or zeroed
              // by a parent Scaffold's bottomNavigationBar. Using padding.bottom
              // risks inheriting a modified (possibly 0) value from RootShell.
              final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
              return SafeArea(
                bottom: false, // bottom handled explicitly below
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomInset + 40),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Шапка — редакционная типографика ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Минималистичная кнопка назад — без фона, без рамки
                        PiligrimTap(
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
                        const SizedBox(height: 28),
                        // Двухстрочный заголовок — единая фраза с иерархией
                        Text(
                          'БРОНИРОВАНИЕ',
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.steppe.withValues(alpha: 0.80),
                            fontWeight: FontWeight.w300,
                            fontSize: 15,
                            letterSpacing: 3.0,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'СТОЛИКА',
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.steppe.withValues(alpha: 0.80),
                            fontWeight: FontWeight.w300,
                            fontSize: 15,
                            letterSpacing: 3.0,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: 28,
                          height: 1.5,
                          decoration: BoxDecoration(
                            color: PiligrimColors.steppe,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Дорогие герои, оставьте заявку на бронь. Мы подтвердим её после связи менеджера с вами.',
                          style: PiligrimTextStyles.body.copyWith(
                            color: PiligrimColors.sky.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Фотографии пространств ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ПРОСТРАНСТВА ЗАЛА',
                          style: PiligrimTextStyles.sectionLabel,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 24),
                            itemCount: PiligrimInteriorAssets.allInteriorPngs.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 108,
                                  height: 96,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        PiligrimInteriorAssets.allInteriorPngs[i],
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.28),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Форма ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Тонкая золотая линия-разделитель вместо карточки
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PiligrimColors.steppe.withValues(alpha: 0.0),
                                PiligrimColors.steppe.withValues(alpha: 0.45),
                                PiligrimColors.steppe.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        Form(
                          key: _formKey,
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Имя героя'),
                            _PiligrimInput(
                              controller: _nameCtrl,
                              hint: 'Введите имя',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Укажите имя героя';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Номер телефона'),
                            _PiligrimInput(
                              controller: _phoneCtrl,
                              hint: '+7 7XX XXX XX XX',
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 11) {
                                  return 'Укажите корректный номер телефона';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _DateTimeChip(
                                    label: 'Дата',
                                    value: _dateLabel,
                                    onTap: _pickDate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DateTimeChip(
                                    label: 'Время',
                                    value: _timeLabel,
                                    onTap: _pickTime,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Количество героев'),
                            _PiligrimInput(
                              controller: _guestsCtrl,
                              hint: '2',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final count = int.tryParse(value ?? '');
                                if (count == null || count <= 0) {
                                  return 'Укажите количество героев';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Зона / зал (опционально)'),
                            Row(
                              children: _zones.asMap().entries.map((e) {
                                final zone = e.value;
                                final isLast = e.key == _zones.length - 1;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                                    child: _ZoneButton(
                                      label: zone,
                                      isSelected: _selectedZone == zone,
                                      onTap: () => setState(() => _selectedZone = zone),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Комментарий'),
                            _PiligrimInput(
                              controller: _commentCtrl,
                              hint: 'Повод визита, пожелания, аллергии',
                              maxLines: 4,
                            ),
                            if (depositRequired) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: PiligrimColors.earth.withValues(alpha: 0.4),
                                  border: Border.all(
                                    color: PiligrimColors.steppe.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: PiligrimColors.steppe,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            context.watch<CoreInfoProvider>().coreInfo?.bookingDepositNote
                                                ?? 'Для выбранного стола может потребоваться депозит. Уточните у менеджера.',
                                            style: PiligrimTextStyles.caption.copyWith(
                                              color: PiligrimColors.sky.withValues(alpha: 0.85),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SecondaryCtaButton(
                                      label: 'ПОЗВОНИТЬ МЕНЕДЖЕРУ',
                                      height: 40,
                                      onTap: () async {
                                        final phone = context.read<CoreInfoProvider>().coreInfo?.phone ?? '';
                                        if (phone.isNotEmpty) {
                                          final uri = Uri.parse('tel:$phone');
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            PathCta(
                              label: booking.isSubmitting ? 'ОТПРАВЛЯЕМ...' : 'ОТПРАВИТЬ ЗАЯВКУ',
                              onTap: booking.isSubmitting ? null : _submit,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Важно: в приложении нет онлайн-оплаты и списания депозита.',
                              style: PiligrimTextStyles.caption.copyWith(
                                color: PiligrimColors.sky.withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        ),
        ],
      ),
    );
  }
}

// Подпись поля — мелкие капслоки с разрядкой
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text.toUpperCase(),
        style: PiligrimTextStyles.sectionLabel.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.50),
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// Поле ввода текста в стиле PILIGRIM
class _PiligrimInput extends StatelessWidget {
  const _PiligrimInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: PiligrimTextStyles.body.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.35),
        ),
        filled: true,
        fillColor: PiligrimColors.earthWarm.withValues(alpha: 0.95),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PiligrimColors.sky.withValues(alpha: 0.11)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: PiligrimColors.water, width: 1.2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: PiligrimColors.fruit, width: 1.1),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: PiligrimColors.fruit, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

// Кнопка выбора даты или времени
class _DateTimeChip extends StatelessWidget {
  const _DateTimeChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: PiligrimColors.earthWarm.withValues(alpha: 0.95),
          border: Border.all(color: PiligrimColors.sky.withValues(alpha: 0.11)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: PiligrimTextStyles.sectionLabel.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.48),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: PiligrimTextStyles.body.copyWith(
                color: PiligrimColors.sky,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Кнопка выбора зоны — анимированный переход выбранного состояния
class _ZoneButton extends StatelessWidget {
  const _ZoneButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? PiligrimColors.water.withValues(alpha: 0.13)
              : PiligrimColors.earthWarm.withValues(alpha: 0.95),
          border: Border.all(
            color: isSelected
                ? PiligrimColors.water.withValues(alpha: 0.55)
                : PiligrimColors.sky.withValues(alpha: 0.11),
            width: 1.2,
          ),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: PiligrimTextStyles.caption.copyWith(
              color: isSelected
                  ? PiligrimColors.water
                  : PiligrimColors.sky.withValues(alpha: 0.65),
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w300,
              letterSpacing: 0.2,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

