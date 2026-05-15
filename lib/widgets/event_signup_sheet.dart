// Заявка «Записаться» — не онлайн-продажа билетов; ресторан перезванивает (ТЗ)
// Стили: piligrim_design_spec.md — primary #7BA5B8, поля на тёмном фоне
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import 'piligrim_tap.dart';

Future<void> showEventSignupSheet(
  BuildContext context, {
  required String eventTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (ctx) => _EventSignupSheet(eventTitle: eventTitle),
  );
}

class _EventSignupSheet extends StatefulWidget {
  const _EventSignupSheet({required this.eventTitle});
  final String eventTitle;

  @override
  State<_EventSignupSheet> createState() => _EventSignupSheetState();
}

class _EventSignupSheetState extends State<_EventSignupSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Заявка отправлена. Мы перезвоним вам для подтверждения — это не оплата билета онлайн.',
          style: PiligrimTextStyles.body.copyWith(fontSize: 14),
        ),
        backgroundColor: PiligrimColors.earth,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: PiligrimColors.divider),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PiligrimColors.sky.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Запись на мероприятие',
                          style: PiligrimTextStyles.heading.copyWith(
                            color: PiligrimColors.sky,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset(
                            'assets/images/x.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              PiligrimColors.sky.withValues(alpha: 0.5),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.eventTitle,
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.water,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Оставьте имя и телефон — проводник PILIGRIM перезвонит, чтобы подтвердить участие. Онлайн-оплаты билетов нет.',
                    style: PiligrimTextStyles.body.copyWith(
                      fontSize: 13,
                      color: PiligrimColors.sky.withValues(alpha: 0.75),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Имя',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.steppe.withValues(alpha: 0.8),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _nameCtrl,
                    hint: 'Как к вам обращаться',
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Введите имя';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Телефон',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.steppe.withValues(alpha: 0.8),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _phoneCtrl,
                    hint: '+7 …',
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return 'Укажите номер для обратного звонка';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 50,
                    child: PiligrimTap(
                      onTap: _submit,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: PiligrimColors.water,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'ОТПРАВИТЬ ЗАЯВКУ',
                            style: PiligrimTextStyles.button.copyWith(
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PiligrimColors.earth,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PiligrimColors.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: PiligrimTextStyles.body.copyWith(
          fontSize: 15,
          color: PiligrimColors.sky,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: PiligrimTextStyles.body.copyWith(
            fontSize: 15,
            color: PiligrimColors.sky.withValues(alpha: 0.25),
          ),
          border: InputBorder.none,
          errorStyle: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.steppe,
            fontSize: 11,
          ),
        ),
        cursorColor: PiligrimColors.water,
      ),
    );
  }
}
