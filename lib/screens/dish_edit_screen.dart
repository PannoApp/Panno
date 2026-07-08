import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/models/api_allergen.dart';
import '../data/models/api_category.dart';
import '../data/models/api_dish.dart';
import '../data/models/api_tag.dart';
import '../data/repositories/menu_repository.dart';
import '../providers/menu_provider.dart';
import '../widgets/piligrim_back_button.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';
import '../widgets/piligrim_toast.dart';

/// Экран создания и редактирования блюда.
class DishEditScreen extends StatefulWidget {
  const DishEditScreen({
    super.key,
    required this.dish,
    required this.categories,
  });

  /// Модель блюда. Если [dish] равен null — экран работает в режиме создания нового блюда.
  final ApiDish? dish;

  /// Список доступных категорий для выбора.
  final List<ApiCategory> categories;

  @override
  State<DishEditScreen> createState() => _DishEditScreenState();
}

class _DishEditScreenState extends State<DishEditScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _localImageFile; // Локальный файл выбранного и кадрированного изображения блюда
  File? _localVideoFile; // Локальный файл выбранного видео для ленты
  final _repo = MenuRepository();
  bool _isSaving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _storyCtrl;

  int? _selectedCategoryId;
  final Set<int> _selectedTagIds = {};
  final Set<int> _selectedAllergenIds = {};
  bool _isActive = true;

  List<ApiTag> _allTags = [];
  List<ApiAllergen> _allAllergens = [];
  bool _isLoadingMetadata = false;

  // Обновление состояния экрана при вводе текста в name или price
  void _onTextChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.dish?.name ?? '');
    _descriptionCtrl = TextEditingController(text: widget.dish?.description ?? '');
    _priceCtrl = TextEditingController(text: widget.dish?.price.toString() ?? '');
    _weightCtrl = TextEditingController(text: widget.dish?.weight ?? '');
    _storyCtrl = TextEditingController(text: widget.dish?.story ?? '');

    _nameCtrl.addListener(_onTextChanged);
    _priceCtrl.addListener(_onTextChanged);

    if (widget.dish != null) {
      _selectedCategoryId = widget.dish!.category;
      _isActive = widget.dish!.isActive;
      _selectedTagIds.addAll(widget.dish!.tags.map((t) => t.id));
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first.id;
    }

    _loadMetadata();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onTextChanged);
    _priceCtrl.removeListener(_onTextChanged);
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _weightCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  /// Загрузка тегов и аллергенов с бэкенда для отображения в форме.
  Future<void> _loadMetadata() async {
    setState(() => _isLoadingMetadata = true);
    try {
      final repo = MenuRepository();
      final results = await Future.wait([
        repo.fetchTags(),
        repo.fetchAllergens(),
      ]);
      if (mounted) {
        setState(() {
          _allTags = results[0] as List<ApiTag>;
          _allAllergens = results[1] as List<ApiAllergen>;

          // Сопоставляем текстовые аллергены из ApiDish с ID полученных аллергенов
          if (widget.dish != null) {
            for (final allergenName in widget.dish!.allergens) {
              final match = _allAllergens.firstWhere(
                (a) => a.name.toLowerCase().trim() == allergenName.toLowerCase().trim(),
                orElse: () => const ApiAllergen(id: -1, name: ''),
              );
              if (match.id != -1) {
                _selectedAllergenIds.add(match.id);
              }
            }
          }
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMetadata = false);
      }
    }
  }

  /// Выбор вертикального видео из галереи (9:16, до 5 минут).
  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked != null) setState(() => _localVideoFile = File(picked.path));
  }

  /// Выбор изображения из галереи и его последующее кадрирование (16:9).
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
    setState(() => _isSaving = true);
    try {
      final fields = {
        'name': _nameCtrl.text.trim(),
        'price': int.parse(_priceCtrl.text),
        'category': _selectedCategoryId,
        'is_active': _isActive,
        'description': _descriptionCtrl.text.trim(),
        'weight': _weightCtrl.text.trim(),
        'story': _storyCtrl.text.trim(),
        'tags': _selectedTagIds.toList(),
        'allergens': _selectedAllergenIds.toList(),
      };
      widget.dish == null
          ? await _repo.createDish(fields, image: _localImageFile, video: _localVideoFile)
          : await _repo.updateDish(widget.dish!.id, fields, image: _localImageFile, video: _localVideoFile);
      if (mounted) {
        context.read<MenuProvider>().load(); // Обновить меню
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
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
        PiligrimToast.show(context, errorMessage, type: PiligrimToastType.error);
      }
    } catch (e) {
      if (mounted) {
        PiligrimToast.show(context, 'Не удалось сохранить блюдо: $e', type: PiligrimToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Диалог подтверждения удаления блюда. Отправляет запрос на бэкенд при подтверждении.
  void _deleteDish() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PiligrimColors.earthDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PiligrimColors.divider, width: 1),
        ),
        title: Text(
          'Удалить блюдо?',
          style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
        ),
        content: Text(
          'Вы действительно хотите удалить блюдо "${widget.dish?.name}"?',
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
              Navigator.of(ctx).pop(); // Закрыть диалог
              setState(() => _isSaving = true);
              try {
                await _repo.deleteDish(widget.dish!.id);
                if (mounted) {
                  context.read<MenuProvider>().load(); // Обновить меню
                }
                if (mounted) {
                  Navigator.of(context).pop(); // Закрыть экран редактирования
                }
              } on DioException catch (e) {
                String errorMessage = 'Не удалось удалить блюдо';
                if (e.type == DioExceptionType.connectionTimeout ||
                    e.type == DioExceptionType.receiveTimeout ||
                    e.type == DioExceptionType.sendTimeout ||
                    e.type == DioExceptionType.connectionError) {
                  errorMessage = 'Сетевая ошибка при удалении';
                } else if (e.response?.statusCode != null) {
                  errorMessage = 'Ошибка сервера при удалении: ${e.response!.statusCode}';
                }
                if (mounted) {
                  PiligrimToast.show(context, errorMessage, type: PiligrimToastType.error);
                }
              } catch (e) {
                if (mounted) {
                  PiligrimToast.show(context, 'Ошибка при удалении: $e', type: PiligrimToastType.error);
                }
              } finally {
                if (mounted) {
                  setState(() => _isSaving = false);
                }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: PiligrimBackButton.kWidth,
        leading: const PiligrimBackButton(),
        title: Text(
          widget.dish == null ? 'Создать блюдо' : 'Редактировать блюдо',
          style: PiligrimTextStyles.heading.copyWith(
            fontSize: 17,
            color: PiligrimColors.sky,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.dish != null)
            PiligrimTap(
              onTap: _isSaving ? null : _deleteDish,
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
                _buildVideoSection(),
                _buildFieldLabel('Название блюда *'),
                _buildInput(
                  controller: _nameCtrl,
                  hint: 'Введите название',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите название блюда';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildFieldLabel('Цена (₸) *'),
                _buildInput(
                  controller: _priceCtrl,
                  hint: 'Введите цену (например, 4500)',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите цену блюда';
                    }
                    final price = int.tryParse(v.trim());
                    if (price == null || price <= 0) {
                      return 'Укажите корректное число больше 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildCategoryDropdown(),
                const SizedBox(height: 18),

                _buildFieldLabel('Вес (например, "350 г")'),
                _buildInput(
                  controller: _weightCtrl,
                  hint: 'Введите вес блюда',
                ),
                const SizedBox(height: 18),

                _buildFieldLabel('Описание блюда'),
                _buildInput(
                  controller: _descriptionCtrl,
                  hint: 'Краткое описание ингредиентов и вкуса',
                  maxLines: 3,
                ),
                const SizedBox(height: 18),

                _buildFieldLabel('История блюда (легенда)'),
                _buildInput(
                  controller: _storyCtrl,
                  hint: 'Исторический контекст или легенда создания блюда',
                  maxLines: 3,
                ),
                const SizedBox(height: 18),

                _buildTagChips(),
                const SizedBox(height: 18),

                _buildAllergenChips(),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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

  /// Выпадающий список выбора категории блюда.
  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Категория *'),
        DropdownButtonFormField<int>(
          initialValue: _selectedCategoryId,
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
          items: widget.categories.map((cat) {
            return DropdownMenuItem<int>(
              value: cat.id,
              child: Text(cat.name),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedCategoryId = val;
            });
          },
          validator: (val) => val == null ? 'Выберите категорию' : null,
        ),
      ],
    );
  }

  /// Выбор тегов с помощью горизонтального/сеточного набора чипсов.
  Widget _buildTagChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Теги'),
        const SizedBox(height: 4),
        if (_isLoadingMetadata)
          const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PiligrimColors.water,
                ),
              ),
            ),
          )
        else if (_allTags.isEmpty)
          Text(
            'Нет доступных тегов',
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.3),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTags.map((tag) {
              final isSelected = _selectedTagIds.contains(tag.id);
              return _SelectableChip(
                label: tag.name,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTagIds.remove(tag.id);
                    } else {
                      _selectedTagIds.add(tag.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Выбор аллергенов с помощью набора чипсов.
  Widget _buildAllergenChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Аллергены'),
        const SizedBox(height: 4),
        if (_isLoadingMetadata)
          const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PiligrimColors.water,
                ),
              ),
            ),
          )
        else if (_allAllergens.isEmpty)
          Text(
            'Нет доступных аллергенов',
            style: PiligrimTextStyles.caption.copyWith(
              color: PiligrimColors.sky.withValues(alpha: 0.3),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allAllergens.map((allergen) {
              final isSelected = _selectedAllergenIds.contains(allergen.id);
              return _SelectableChip(
                label: allergen.name,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedAllergenIds.remove(allergen.id);
                    } else {
                      _selectedAllergenIds.add(allergen.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Переключатель активности блюда (is_active).
  Widget _buildActiveSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Отображать в меню'.toUpperCase(),
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
          onChanged: (val) {
            setState(() {
              _isActive = val;
            });
          },
        ),
      ],
    );
  }

  /// Кнопка сохранения/публикации блюда.
  Widget _buildSaveButton() {
    if (_isSaving) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: PiligrimLoader(color: PiligrimColors.steppe),
        ),
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
          widget.dish == null ? 'ОПУБЛИКОВАТЬ' : 'СОХРАНИТЬ ИЗМЕНЕНИЯ',
          style: PiligrimTextStyles.button.copyWith(
            fontSize: 12,
            letterSpacing: 1.8,
            color: PiligrimColors.sky,
          ),
        ),
      ),
    );
  }

  /// Бейдж статуса существующего видео на сервере.
  Widget _buildVideoStatusBadge() {
    final (label, color) = switch (widget.dish?.videoStatus ?? 'pending') {
      'ready'      => ('ГОТОВО',         PiligrimColors.water),
      'processing' => ('ОБРАБАТЫВАЕТСЯ', PiligrimColors.steppe),
      'failed'     => ('ОШИБКА',         PiligrimColors.fruit),
      _            => ('ОЖИДАЕТ',        PiligrimColors.sky.withValues(alpha: 0.45)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PiligrimColors.earthWarm.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 0.9,
        ),
      ),
      child: Text(
        label,
        style: PiligrimTextStyles.caption.copyWith(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Секция выбора видео для ленты «Путь» с отображением статуса и подсказкой.
  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Видео для ленты (9:16)'),
        const SizedBox(height: 4),
        if (_localVideoFile != null)
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: PiligrimColors.water,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _localVideoFile!.path.split('/').last,
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.water,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        else if (widget.dish?.videoUrl != null)
          _buildVideoStatusBadge(),
        const SizedBox(height: 8),
        Text(
          'Вертикальное видео 9:16. Транскодирование занимает 1–5 минут.',
          style: PiligrimTextStyles.caption.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.35),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        PiligrimTap(
          onTap: _pickVideo,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PiligrimColors.water,
                width: 1.2,
              ),
              color: PiligrimColors.earthWarm.withValues(alpha: 0.95),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.video_library_outlined,
                  color: PiligrimColors.water,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Выбрать видео'.toUpperCase(),
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

  /// Секция выбора фотографии блюда с предпросмотром и кнопкой.
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Фотография блюда'),
        const SizedBox(height: 4),
        _DishPreviewCard(
          localImageFile: _localImageFile,
          imageUrl: widget.dish?.imageUrl,
          name: _nameCtrl.text,
          price: _priceCtrl.text,
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
              border: Border.all(
                color: PiligrimColors.water,
                width: 1.2,
              ),
              color: PiligrimColors.earthWarm.withValues(alpha: 0.95),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: PiligrimColors.water,
                  size: 18,
                ),
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
}

/// Выделяемый элемент выбора (тега или аллергена).
class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
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
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? PiligrimColors.steppe.withValues(alpha: 0.18)
              : PiligrimColors.earthWarm.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? PiligrimColors.steppe.withValues(alpha: 0.6)
                : PiligrimColors.sky.withValues(alpha: 0.11),
            width: isSelected ? 0.9 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 12,
            color: isSelected
                ? PiligrimColors.steppe
                : PiligrimColors.sky.withValues(alpha: 0.5),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w300,
          ),
        ),
      ),
    );
  }
}

/// Виджет предпросмотра блюда (Live Preview), который зеркалит визуал [_ClassicDishCard].
class _DishPreviewCard extends StatelessWidget {
  const _DishPreviewCard({
    required this.localImageFile,
    required this.imageUrl,
    required this.name,
    required this.price,
  });

  final File? localImageFile;
  final String? imageUrl;
  final String name;
  final String price;

  String _formatPrice(int price) =>
      price.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]} ',
          );

  @override
  Widget build(BuildContext context) {
    final parsedPrice = int.tryParse(price.trim());

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
            // Изображение
            Positioned.fill(
              child: _buildImage(),
            ),
            // Верхний виньет — приглушает яркие фотографии и даёт атмосферность
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
            // Многоступенчатый bottom gradient — гарантирует читаемость цены/категории
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
            // Название блюда и Ценник
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: PiligrimTextStyles.heading.copyWith(
                        fontSize: 17,
                        color: PiligrimColors.nomadCream,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (parsedPrice != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: PiligrimColors.imageScrim.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: PiligrimColors.steppe.withValues(alpha: 0.58),
                          width: 0.75,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PiligrimColors.steppe.withValues(alpha: 0.28),
                            blurRadius: 14,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: PiligrimColors.shadow.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_formatPrice(parsedPrice)} ₸',
                        style: const TextStyle(
                          fontFamily: PiligrimFonts.museoSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PiligrimColors.steppe,
                          letterSpacing: 0.6,
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
      return Image.file(
        localImageFile!,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PiligrimColors.water,
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: PiligrimColors.fruit,
            size: 40,
          ),
        ),
      );
    } else {
      return const Center(
        child: Icon(
          Icons.camera_alt_outlined,
          color: PiligrimColors.sky,
          size: 40,
        ),
      );
    }
  }
}
