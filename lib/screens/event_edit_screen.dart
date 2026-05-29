import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/models/api_event.dart';
import '../data/repositories/events_repository.dart';
import '../providers/events_provider.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';

/// Экран создания / редактирования мероприятия.
/// [event] == null → режим создания нового мероприятия.
class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key, required this.event});

  final ApiEvent? event;

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EventsRepository();
  File? _localImageFile;
  bool _isSaving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _maxPlacesCtrl;

  DateTime? _selectedDateTime;
  late ApiEventFormat _selectedFormat;
  late bool _isActive;

  bool get _isCreating => widget.event == null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event?.title ?? '')
      ..addListener(() => setState(() {}));
    _descriptionCtrl = TextEditingController(text: widget.event?.description ?? '');
    _priceCtrl = TextEditingController(
      text: widget.event?.priceFrom?.toString() ?? '',
    );
    _maxPlacesCtrl = TextEditingController(
      text: (widget.event?.maxPlaces ?? 0).toString(),
    );
    _selectedDateTime = widget.event?.startsAt;
    _selectedFormat = widget.event?.format ?? ApiEventFormat.open;
    _isActive = widget.event?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _maxPlacesCtrl.dispose();
    super.dispose();
  }

  /// Открывает последовательно DatePicker, затем TimePicker и сохраняет результат.
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    // Запрещаем выбирать прошедшие даты: firstDate = сегодня.
    // initialDate должен быть >= firstDate, поэтому берём максимум из текущей даты и now.
    final initialDate =
        (_selectedDateTime != null && _selectedDateTime!.isAfter(now))
            ? _selectedDateTime!
            : now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: PiligrimColors.steppe,
            surface: PiligrimColors.earthDeep,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: _selectedDateTime != null
          ? TimeOfDay.fromDateTime(_selectedDateTime!)
          : TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: PiligrimColors.steppe,
            surface: PiligrimColors.earthDeep,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  /// Выбор изображения из галереи и кадрирование в формате 16:9.
  Future<void> _pickAndCropImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Кадрировать 16:9', lockAspectRatio: true),
        IOSUiSettings(title: 'Кадрировать 16:9', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped != null) {
      setState(() => _localImageFile = File(cropped.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCreating &&
        _selectedDateTime != null &&
        _selectedDateTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Нельзя создавать мероприятие на прошедшую дату',
          style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky),
        ),
        backgroundColor: PiligrimColors.earthDeep,
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final priceRaw = _priceCtrl.text.trim();
      final fields = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'date_time': _selectedDateTime!.toUtc().toIso8601String(),
        'format': _selectedFormat.name,
        'price': priceRaw.isEmpty ? null : priceRaw,
        'max_places': int.tryParse(_maxPlacesCtrl.text.trim()) ?? 0,
        'is_active': _isActive,
      };
      widget.event == null
          ? await _repo.createEvent(fields, image: _localImageFile)
          : await _repo.updateEvent(widget.event!.id, fields, image: _localImageFile);
      if (mounted) context.read<EventsProvider>().load();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      String errorMessage = 'Произошла сетевая ошибка';
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map) {
          final errorList = <String>[];
          data.forEach((key, val) {
            final valStr = val is List ? val.join(', ') : val.toString();
            if (key == 'non_field_errors' || key == 'detail') {
              errorList.add(valStr);
            } else {
              errorList.add('$key: $valStr');
            }
          });
          errorMessage = errorList.isNotEmpty ? errorList.join('\n') : 'Ошибка валидации данных';
        } else if (data is String && data.isNotEmpty) {
          errorMessage = data;
        } else {
          errorMessage = 'Ошибка валидации данных';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.connectionError) {
        errorMessage = 'Сетевая ошибка. Проверьте интернет-соединение';
      } else {
        errorMessage = 'Ошибка сервера: ${e.response?.statusCode ?? ""} ${e.message ?? ""}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage, style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
          backgroundColor: PiligrimColors.earthDeep,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Не удалось сохранить мероприятие: $e',
              style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
          backgroundColor: PiligrimColors.earthDeep,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Форматирует дату и время для отображения в поле.
  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
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
        title: Text(
          _isCreating ? 'Создать мероприятие' : 'Редактировать мероприятие',
          style: PiligrimTextStyles.heading.copyWith(
            fontSize: 17,
            color: PiligrimColors.sky,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isCreating)
            PiligrimTap(
              onTap: _isSaving ? null : _deleteEvent,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: PiligrimColors.fruit,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(),
                _buildFieldLabel('Название мероприятия *'),
                _buildInput(
                  controller: _titleCtrl,
                  hint: 'Введите название',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите название мероприятия';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildFieldLabel('Описание'),
                _buildInput(
                  controller: _descriptionCtrl,
                  hint: 'Краткое описание мероприятия',
                  maxLines: 3,
                ),
                const SizedBox(height: 18),

                _buildDateTimeField(),
                const SizedBox(height: 18),

                _buildFormatDropdown(),
                const SizedBox(height: 18),

                _buildFieldLabel('Цена (₸)'),
                _buildInput(
                  controller: _priceCtrl,
                  hint: 'Оставьте пустым для свободного входа',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),

                _buildFieldLabel('Максимум мест'),
                _buildInput(
                  controller: _maxPlacesCtrl,
                  hint: '0 — без ограничений',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),

                _buildActiveSwitch(),
                const SizedBox(height: 32),

                _buildSaveButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Секция выбора обложки мероприятия с предпросмотром и кнопкой.
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Обложка мероприятия'),
        const SizedBox(height: 4),
        _EventPreviewCard(
          localImageFile: _localImageFile,
          coverUrl: widget.event?.coverUrl,
          title: _titleCtrl.text,
          selectedDateTime: _selectedDateTime,
        ),
        const SizedBox(height: 12),
        PiligrimTap(
          onTap: _pickAndCropImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PiligrimColors.water, width: 1.2),
              color: PiligrimColors.earthWarm.withValues(alpha: 0.95),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library_outlined, color: PiligrimColors.water, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Выбрать фото'.toUpperCase(),
                  style: PiligrimTextStyles.button.copyWith(
                    fontSize: 13,
                    color: PiligrimColors.water,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  /// Заголовок поля в верхнем регистре.
  Widget _buildFieldLabel(String text) {
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

  /// Стилизованное текстовое поле ввода.
  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky),
      cursorColor: PiligrimColors.water,
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

  /// Поле выбора даты и времени (только для чтения, открывает пикеры по тапу).
  Widget _buildDateTimeField() {
    final displayText = _selectedDateTime != null
        ? _formatDateTime(_selectedDateTime!)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Дата и время *'),
        TextFormField(
          readOnly: true,
          onTap: _pickDateTime,
          controller: TextEditingController(text: displayText),
          style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky),
          validator: (_) {
            if (_selectedDateTime == null) {
              return 'Укажите дату и время мероприятия';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Выберите дату и время',
            hintStyle: PiligrimTextStyles.body.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.35),
            ),
            filled: true,
            fillColor: PiligrimColors.earthWarm.withValues(alpha: 0.95),
            suffixIcon: const Icon(
              Icons.calendar_today_outlined,
              color: PiligrimColors.water,
              size: 18,
            ),
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
        ),
      ],
    );
  }

  /// Выпадающий список выбора формата мероприятия (открытое / закрытое).
  Widget _buildFormatDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Формат *'),
        DropdownButtonFormField<ApiEventFormat>(
          initialValue: _selectedFormat,
          dropdownColor: PiligrimColors.earthWarm,
          style: PiligrimTextStyles.body.copyWith(
            fontSize: 14,
            color: PiligrimColors.sky,
          ),
          iconEnabledColor: PiligrimColors.water,
          decoration: InputDecoration(
            filled: true,
            fillColor: PiligrimColors.earthWarm.withValues(alpha: 0.95),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ),
          items: const [
            DropdownMenuItem(
              value: ApiEventFormat.open,
              child: Text('Открытое'),
            ),
            DropdownMenuItem(
              value: ApiEventFormat.closed,
              child: Text('Закрытое'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedFormat = val);
          },
        ),
      ],
    );
  }

  /// Переключатель активности мероприятия (is_active).
  Widget _buildActiveSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Отображать на афише'.toUpperCase(),
          style: PiligrimTextStyles.sectionLabel.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.50),
            letterSpacing: 1.6,
          ),
        ),
        Switch.adaptive(
          value: _isActive,
          activeThumbColor: PiligrimColors.water,
          activeTrackColor: PiligrimColors.water.withValues(alpha: 0.3),
          inactiveThumbColor: PiligrimColors.sky.withValues(alpha: 0.5),
          inactiveTrackColor: PiligrimColors.earthWarm,
          onChanged: (val) => setState(() => _isActive = val),
        ),
      ],
    );
  }

  /// Кнопка сохранения / публикации мероприятия.
  Widget _buildSaveButton() {
    if (_isSaving) {
      return const SizedBox(
        height: 52,
        child: Center(child: PiligrimLoader(color: PiligrimColors.steppe)),
      );
    }

    return PiligrimTap(
      onTap: _save,
      scaleDown: 0.97,
      releaseDuration: const Duration(milliseconds: 280),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PiligrimColors.steppe, PiligrimColors.emberDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: PiligrimColors.shadow.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: PiligrimColors.ember.withValues(alpha: 0.12),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Text(
          _isCreating ? 'ОПУБЛИКОВАТЬ' : 'СОХРАНИТЬ ИЗМЕНЕНИЯ',
          style: PiligrimTextStyles.button.copyWith(
            fontSize: 12,
            letterSpacing: 1.8,
            color: PiligrimColors.sky,
          ),
        ),
      ),
    );
  }

  void _deleteEvent() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PiligrimColors.earthDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PiligrimColors.divider, width: 1),
        ),
        title: Text(
          'Удалить мероприятие?',
          style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
        ),
        content: Text(
          'Вы действительно хотите удалить "${widget.event?.title}"?',
          style: PiligrimTextStyles.body.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Отмена',
              style: PiligrimTextStyles.button.copyWith(color: PiligrimColors.water),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isSaving = true);
              try {
                await _repo.deleteEvent(widget.event!.id);
                if (mounted) context.read<EventsProvider>().load();
                if (mounted) Navigator.of(context).pop();
              } on DioException catch (e) {
                String errorMessage = 'Не удалось удалить мероприятие';
                if (e.type == DioExceptionType.connectionTimeout ||
                    e.type == DioExceptionType.receiveTimeout ||
                    e.type == DioExceptionType.sendTimeout ||
                    e.type == DioExceptionType.connectionError) {
                  errorMessage = 'Сетевая ошибка при удалении';
                } else if (e.response?.statusCode != null) {
                  errorMessage = 'Ошибка сервера при удалении: ${e.response!.statusCode}';
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(errorMessage,
                        style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
                    backgroundColor: PiligrimColors.earthDeep,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Ошибка при удалении: $e',
                        style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
                    backgroundColor: PiligrimColors.earthDeep,
                  ));
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: Text(
              'Удалить',
              style: PiligrimTextStyles.button.copyWith(color: PiligrimColors.fruit),
            ),
          ),
        ],
      ),
    );
  }
}

/// Виджет предпросмотра обложки мероприятия (Live Preview) в формате 16:9.
class _EventPreviewCard extends StatelessWidget {
  const _EventPreviewCard({
    required this.localImageFile,
    required this.coverUrl,
    required this.title,
    required this.selectedDateTime,
  });

  final File? localImageFile;
  final String? coverUrl;
  final String title;
  final DateTime? selectedDateTime;

  String _formatDate(DateTime dt) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: PiligrimColors.earthWarm,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PiligrimColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: PiligrimColors.shadow.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: _buildImage()),
            // Верхний виньет
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x501C1510), Colors.transparent],
                    stops: [0.0, 0.55],
                  ),
                ),
              ),
            ),
            // Нижний градиент
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x441C1510),
                      Color(0xD41C1510),
                      Color(0xF61C1510),
                    ],
                    stops: [0.0, 0.40, 0.80, 1.0],
                  ),
                ),
              ),
            ),
            // Название и дата-badge
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: PiligrimTextStyles.heading.copyWith(
                        fontSize: 17,
                        color: PiligrimColors.nomadCream,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedDateTime != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xD61C1510),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: PiligrimColors.steppe.withValues(alpha: 0.58),
                          width: 0.9,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PiligrimColors.steppe.withValues(alpha: 0.28),
                            blurRadius: 14,
                          ),
                          BoxShadow(
                            color: PiligrimColors.shadow.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatDate(selectedDateTime!),
                        style: const TextStyle(
                          fontFamily: PiligrimFonts.museoSans,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PiligrimColors.steppe,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (localImageFile != null) {
      return Image.file(localImageFile!, fit: BoxFit.cover);
    } else if (coverUrl != null && coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: PiligrimColors.water),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image_outlined, color: PiligrimColors.fruit, size: 40),
        ),
      );
    } else {
      return const Center(
        child: Icon(Icons.event_outlined, color: PiligrimColors.sky, size: 40),
      );
    }
  }
}
