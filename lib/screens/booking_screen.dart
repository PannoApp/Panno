// Бронирование зала — «Путь Героя к столу»
// Выбор зоны, даты, кол-ва гостей, подтверждение. Согласно ТЗ раздел 4.4
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/auth_guard.dart';
import '../core/interior_assets.dart';
import '../core/theme.dart';
import '../data/models/booking_request.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/core_info_provider.dart';
import '../widgets/ember_cta.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/piligrim_tap.dart';

// Форматирует TimeOfDay в строку HH:MM:SS для Django TimeField.
String bookingTimeForApi(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

// Согласно brand/piligrim_design_spec.md:
// - палитра Қара жер / Мөлдір су / Сары дала
// - мягкая геометрия карточек и медитативные анимации
// Согласно ТЗ бронирования:
// - только заявка, без онлайн-оплаты и списания депозита
// Экран бронирования столика: форма заявки (имя, дата, время, зал, комментарий)
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+7 777 777 77 77');
  final _commentCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController(text: '2');

  DateTime _visitDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _visitTime = const TimeOfDay(hour: 19, minute: 30);
  String? _selectedZone = 'Главный зал';
  bool _submitted = false;

  // API-значения зон соответствуют backend enum: main/terrace/private
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
    if (picked != null) {
      setState(() => _visitDate = picked);
    }
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
    if (picked != null) {
      setState(() => _visitTime = picked);
    }
  }

  // Формат времени для Django TimeField: HH:MM → HH:MM:SS
  String get _timeForApi => bookingTimeForApi(_visitTime);

  // Формат даты для API Django DateField
  String get _dateForApi {
    final d = _visitDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Auth guard — редиректит на экран входа, если пользователь не авторизован
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
      setState(() => _submitted = true);
    } else if (booking.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PiligrimColors.earthDeep,
          content: Text(
            booking.error!,
            style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky),
          ),
        ),
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
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PiligrimTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: PiligrimColors.sky,
                          ),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/images/moon_totem (1).svg',
                        width: 28,
                        height: 28,
                        colorFilter: const ColorFilter.mode(
                          PiligrimColors.water,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'БРОНИРОВАНИЕ СТОЛИКА',
                        style: PiligrimTextStyles.heading.copyWith(
                          letterSpacing: 1.4,
                          color: PiligrimColors.sky,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Дорогие герои, оставьте заявку на бронь. Мы подтвердим её после связи менеджера с вами.',
                    style: PiligrimTextStyles.body.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Пространства зала',
                    style: PiligrimTextStyles.caption.copyWith(
                      letterSpacing: 1.5,
                      color: PiligrimColors.steppe.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: PiligrimInteriorAssets.allInteriorPngs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 76,
                            height: 76,
                            child: Image.asset(
                              PiligrimInteriorAssets.allInteriorPngs[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LuxCard(
                    child: Form(
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
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _DateTimeChip(
                                  label: 'Дата',
                                  value: _dateLabel,
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateTimeChip(
                                  label: 'Время',
                                  value: _timeLabel,
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 14),
                          const _FieldLabel('Зона / зал (опционально)'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _zones
                                .map(
                                  (zone) => ChoiceChip(
                                    label: Text(zone),
                                    selected: _selectedZone == zone,
                                    selectedColor: PiligrimColors.water.withValues(alpha: 0.22),
                                    backgroundColor: PiligrimColors.earth.withValues(alpha: 0.55),
                                    side: BorderSide(
                                      color: _selectedZone == zone
                                          ? PiligrimColors.water
                                          : PiligrimColors.sky.withValues(alpha: 0.14),
                                    ),
                                    labelStyle: PiligrimTextStyles.body.copyWith(
                                      color: _selectedZone == zone
                                          ? PiligrimColors.water
                                          : PiligrimColors.sky.withValues(alpha: 0.9),
                                      fontSize: 13,
                                    ),
                                    onSelected: (_) => setState(() => _selectedZone = zone),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                          const _FieldLabel('Комментарий'),
                          _PiligrimInput(
                            controller: _commentCtrl,
                            hint: 'Повод визита, пожелания, аллергии',
                            maxLines: 4,
                          ),
                          if (depositRequired) ...[
                            const SizedBox(height: 14),
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
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: PiligrimColors.steppe,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
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
                            ),
                          ],
                          const SizedBox(height: 18),
                          EmberGlow(
                            radius: 12,
                            child: booking.isSubmitting
                                ? const SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: PiligrimColors.steppe,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : EmberCta(
                                    label: 'ОТПРАВИТЬ ЗАЯВКУ',
                                    iconAsset: 'assets/images/moon_totem (1).svg',
                                    onTap: _submit,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Важно: в приложении нет онлайн-оплаты и списания депозита.',
                            style: PiligrimTextStyles.caption.copyWith(
                              color: PiligrimColors.sky.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: _submitted
                        ? _FlowCard(
                            visitDate: _dateLabel,
                            visitTime: _timeLabel,
                            depositRequired: depositRequired,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Премиальная карточка-контейнер с тенью и рамкой для группировки полей формы
class _LuxCard extends StatelessWidget {
  const _LuxCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: PiligrimColors.earthDeep.withValues(alpha: 0.88),
        border: Border.all(color: PiligrimColors.sky.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: PiligrimColors.shadow.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: PiligrimColors.water.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );
  }
}

// Подпись над полем ввода (например, «Имя героя», «Номер телефона»)
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: PiligrimTextStyles.caption.copyWith(
          color: PiligrimColors.sky.withValues(alpha: 0.72),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// Стилизованное поле ввода текста в стиле PILIGRIM
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
          color: PiligrimColors.sky.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: PiligrimColors.earth.withValues(alpha: 0.55),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PiligrimColors.sky.withValues(alpha: 0.14)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// Кнопка выбора даты или времени (показывает текущее значение, открывает пикер)
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: PiligrimColors.earth.withValues(alpha: 0.55),
          border: Border.all(color: PiligrimColors.sky.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: PiligrimTextStyles.caption.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 3),
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

// Карточка «Сценарий после отправки» — пошагово объясняет, что произойдёт после заявки
class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.visitDate,
    required this.visitTime,
    required this.depositRequired,
  });

  final String visitDate;
  final String visitTime;
  final bool depositRequired;

  @override
  Widget build(BuildContext context) {
    final pushes = <String>[
      'Заявка принята, мы свяжемся с вами в течение 15 минут.',
      'После подтверждения менеджером: бронь подтверждена на $visitDate, $visitTime.',
      'Напоминание за 1-2 часа до визита.',
    ];
    if (depositRequired) {
      pushes.add('Для выбранного стола нужен депозит — менеджер направит вас на звонок.');
    }

    return _LuxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сценарий после отправки',
            style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.steppe),
          ),
          const SizedBox(height: 8),
          ...pushes.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $line',
                style: PiligrimTextStyles.body.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.87),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
