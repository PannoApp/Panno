import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/events_news_data.dart';
import '../data/repositories/events_repository.dart';
import '../providers/events_provider.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';

/// Экран создания / редактирования новости.
/// [news] == null → режим создания новой новости.
class NewsEditScreen extends StatefulWidget {
  const NewsEditScreen({super.key, required this.news});

  final PiligrimNewsPost? news;

  @override
  State<NewsEditScreen> createState() => _NewsEditScreenState();
}

class _NewsEditScreenState extends State<NewsEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EventsRepository();
  File? _localImageFile;
  bool _isSaving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  bool get _isCreating => widget.news == null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.news?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.news?.body ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
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
    setState(() => _isSaving = true);
    try {
      final fields = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
      };
      widget.news == null
          ? await _repo.createNews(fields, image: _localImageFile)
          : await _repo.updateNews(widget.news!.numericId, fields, image: _localImageFile);
      if (mounted) context.read<EventsProvider>().loadNews();
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
          content: Text('Не удалось сохранить новость: $e',
              style: PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
          backgroundColor: PiligrimColors.earthDeep,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _deleteNews() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PiligrimColors.earthDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PiligrimColors.divider, width: 1),
        ),
        title: Text(
          'Удалить новость?',
          style: PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
        ),
        content: Text(
          'Вы действительно хотите удалить "${widget.news?.title}"?',
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
                await _repo.deleteNews(widget.news!.numericId);
                if (mounted) context.read<EventsProvider>().loadNews();
                if (mounted) Navigator.of(context).pop();
              } on DioException catch (e) {
                String errorMessage = 'Не удалось удалить новость';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PiligrimTap(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(6),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: PiligrimColors.sky,
            ),
          ),
        ),
        title: Text(
          _isCreating ? 'Новая новость' : 'Редактировать новость',
          style: PiligrimTextStyles.heading.copyWith(
            fontSize: 17,
            color: PiligrimColors.sky,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isCreating)
            PiligrimTap(
              onTap: _isSaving ? null : _deleteNews,
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
                _buildFieldLabel('Заголовок *'),
                _buildInput(
                  controller: _titleCtrl,
                  hint: 'Введите заголовок',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите заголовок новости';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildFieldLabel('Текст новости *'),
                _buildInput(
                  controller: _contentCtrl,
                  hint: 'Введите текст новости',
                  maxLines: 6,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите текст новости';
                    }
                    return null;
                  },
                ),
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

  /// Секция выбора обложки новости с предпросмотром и кнопкой.
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Обложка новости'),
        const SizedBox(height: 4),
        _NewsPreviewCard(
          localImageFile: _localImageFile,
          imageUrl: widget.news?.imageUrl,
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

  /// Кнопка сохранения / публикации новости.
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
}

/// Виджет предпросмотра обложки новости (16:9).
class _NewsPreviewCard extends StatelessWidget {
  const _NewsPreviewCard({
    required this.localImageFile,
    required this.imageUrl,
  });

  final File? localImageFile;
  final String? imageUrl;

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
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (localImageFile != null) {
      return Image.file(localImageFile!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
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
        child: Icon(Icons.article_outlined, color: PiligrimColors.sky, size: 40),
      );
    }
  }
}
