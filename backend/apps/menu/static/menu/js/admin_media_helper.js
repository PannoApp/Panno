// Скрипт для интерактива в админке Django: обрезка фото (16:9) и сетка безопасных зон для видео
document.addEventListener('DOMContentLoaded', function () {
    // 1. ДИНАМИЧЕСКАЯ ЗАГРУЗКА CROPPER.JS ИЗ CDN
    function loadCropper(callback) {
        if (window.Cropper) {
            callback();
            return;
        }

        // Загружаем стили
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.css';
        document.head.appendChild(link);

        // Загружаем скрипт
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.js';
        script.onload = callback;
        document.body.appendChild(script);
    }

    // 2. ИНИЦИАЛИЗАЦИЯ ДЛЯ ФОТО (ОБРЕЗКА 16:9)
    const imageInput = document.getElementById('id_image');
    if (imageInput) {
        // Создаем элементы модального окна в DOM
        const modalHtml = `
            <div id="cropper-modal" class="cropper-modal-overlay" style="display:none;">
                <div class="cropper-modal-content">
                    <h3>Обрезка изображения (формат 16:9)</h3>
                    <p style="font-size: 12px; color: #666; margin-bottom: 10px;">
                        Выделите область, которая будет отображаться в карточке меню.
                    </p>
                    <div class="cropper-container-wrapper">
                        <img id="cropper-preview-img" src="" alt="Preview">
                    </div>
                    <div class="cropper-modal-actions">
                        <button type="button" id="cropper-btn-save" class="button default">Применить обрезку</button>
                        <button type="button" id="cropper-btn-cancel" class="button" style="background:#ccc; color:#000;">Отмена</button>
                    </div>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        const modal = document.getElementById('cropper-modal');
        const previewImg = document.getElementById('cropper-preview-img');
        const btnSave = document.getElementById('cropper-btn-save');
        const btnCancel = document.getElementById('cropper-btn-cancel');
        let cropper = null;
        let originalFile = null;

        imageInput.addEventListener('change', function (e) {
            if (!e.target.files || e.target.files.length === 0) return;
            
            originalFile = e.target.files[0];
            // Чтобы не триггерить обрезку на уже обрезанном нами файле
            if (originalFile.name.startsWith('cropped_')) return;

            loadCropper(function () {
                const reader = new FileReader();
                reader.onload = function (event) {
                    previewImg.src = event.target.result;
                    modal.style.display = 'flex';

                    // Инициализируем Cropper
                    if (cropper) {
                        cropper.destroy();
                    }
                    cropper = new Cropper(previewImg, {
                        aspectRatio: 16 / 9,
                        viewMode: 1,
                        autoCropArea: 0.9,
                        responsive: true,
                        restore: false,
                        guides: true,
                        center: true,
                        highlight: false,
                        cropBoxMovable: true,
                        cropBoxResizable: true,
                        toggleDragModeOnDblclick: false,
                    });
                };
                reader.readAsDataURL(originalFile);
            });
        });

        // Сохранение обрезанной версии
        btnSave.addEventListener('click', function () {
            if (!cropper) return;

            // Получаем cropped canvas
            const canvas = cropper.getCroppedCanvas({
                maxWidth: 2048,
                maxHeight: 1152,
                imageSmoothingQuality: 'high'
            });

            canvas.toBlob(function (blob) {
                if (!blob) return;

                // Создаем новый файл
                const croppedFile = new File([blob], 'cropped_' + originalFile.name, {
                    type: originalFile.type || 'image/jpeg',
                    lastModified: Date.now()
                });

                // Подменяем файл в инпуте
                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(croppedFile);
                imageInput.files = dataTransfer.files;

                // Обновляем превью в админке
                const adminPreview = document.querySelector('.field-image_preview_detail img');
                if (adminPreview) {
                    adminPreview.src = URL.createObjectURL(blob);
                } else {
                    // Если превью еще нет (создание нового объекта), можем показать его рядом с инпутом
                    let tempPreview = document.getElementById('temp-image-preview');
                    if (!tempPreview) {
                        tempPreview = document.createElement('img');
                        tempPreview.id = 'temp-image-preview';
                        tempPreview.style.cssText = 'max-width: 300px; border-radius: 8px; margin-top: 10px; display: block;';
                        imageInput.parentNode.appendChild(tempPreview);
                    }
                    tempPreview.src = URL.createObjectURL(blob);
                }

                // Закрываем модалку
                closeModal();
            }, originalFile.type || 'image/jpeg', 0.90);
        });

        // Отмена обрезки
        btnCancel.addEventListener('click', function () {
            // Очищаем инпут, если пользователь передумал обрезать
            imageInput.value = '';
            closeModal();
        });

        function closeModal() {
            modal.style.display = 'none';
            if (cropper) {
                cropper.destroy();
                cropper = null;
            }
        }
    }

    // 3. ИНИЦИАЛИЗАЦИЯ ДЛЯ ВИДЕО (ПРЕДПРОСМОТР + СЕТКА)
    const videoInput = document.getElementById('id_video');
    if (videoInput) {
        videoInput.addEventListener('change', function (e) {
            if (!e.target.files || e.target.files.length === 0) return;
            const file = e.target.files[0];
            const videoUrl = URL.createObjectURL(file);

            // Ищем или создаем контейнер для превью нового видео
            let wrapper = document.querySelector('.field-video_preview_detail .video-preview-wrapper');
            let isNew = false;
            
            if (!wrapper) {
                isNew = true;
                // Создаем обертку для отображения
                const formRow = videoInput.closest('.form-row');
                let previewRow = document.getElementById('new-video-preview-row');
                if (!previewRow) {
                    previewRow = document.createElement('div');
                    previewRow.id = 'new-video-preview-row';
                    previewRow.className = 'form-row field-video_preview_detail';
                    previewRow.style.cssText = 'padding: 10px 0 20px 170px; border-bottom: 1px solid #eee;';
                    formRow.parentNode.insertBefore(previewRow, formRow.nextSibling);
                }
                
                previewRow.innerHTML = `
                    <div style="font-weight: bold; margin-bottom: 5px;">Предпросмотр нового видео:</div>
                    <div class="video-preview-wrapper" style="position: relative; width: 300px; display: inline-block; border-radius: 10px; overflow: hidden; background: #000; box-shadow: 0 4px 10px rgba(0,0,0,0.15);">
                        <video id="video-preview-element" width="300" controls style="display: block;">
                            <source src="${videoUrl}" type="${file.type}">
                            Ваш браузер не поддерживает видео.
                        </video>
                        <div class="video-safe-zone-overlay" style="position: absolute; top: 0; left: 0; right: 0; bottom: 0; pointer-events: none; border: 2px dashed rgba(255, 0, 0, 0.4); box-sizing: border-box;">
                            <div class="video-overlay-text top-scrim" style="position: absolute; top: 0; left: 0; right: 0; height: 15%; background: rgba(255, 0, 0, 0.15); color: #fff; font-size: 10px; padding: 2px; text-align: center; border-bottom: 1px dotted red; font-family: sans-serif;">Зона статус-бара / звука (15%)</div>
                            <div class="video-overlay-text side-safe-left" style="position: absolute; top: 15%; left: 0; width: 10%; bottom: 35%; background: rgba(255, 165, 0, 0.15); border-right: 1px dotted orange;"></div>
                            <div class="video-overlay-text side-safe-right" style="position: absolute; top: 15%; right: 0; width: 10%; bottom: 35%; background: rgba(255, 165, 0, 0.15); border-left: 1px dotted orange;"></div>
                            <div class="video-overlay-text main-safe-zone" style="position: absolute; top: 15%; left: 10%; right: 10%; bottom: 35%; display: flex; align-items: center; justify-content: center; color: #00ff00; font-size: 12px; font-weight: bold; text-shadow: 1px 1px 2px #000; font-family: sans-serif;">БЕЗОПАСНАЯ ЗОНА (Центр)</div>
                            <div class="video-overlay-text bottom-scrim" style="position: absolute; bottom: 0; left: 0; right: 0; height: 35%; background: rgba(255, 0, 0, 0.15); color: #fff; font-size: 10px; padding: 2px; text-align: center; border-top: 1px dotted red; display: flex; align-items: center; justify-content: center; font-family: sans-serif;">Зона описания / цены (35%)</div>
                        </div>
                    </div>
                    <div style="margin-top: 5px;">
                        <label><input type="checkbox" class="toggle-video-overlay" checked style="vertical-align: middle; margin-right: 5px;">Показывать сетку безопасной зоны приложения</label>
                    </div>
                `;

                // Вешаем обработчик для нового чекбокса
                previewRow.querySelector('.toggle-video-overlay').addEventListener('change', function(e) {
                    const overlay = previewRow.querySelector('.video-safe-zone-overlay');
                    if (overlay) overlay.style.display = this.checked ? 'block' : 'none';
                });
            } else {
                // Если превью уже существует, просто обновляем источник видео
                const videoEl = document.getElementById('video-preview-element');
                if (videoEl) {
                    videoEl.src = videoUrl;
                    videoEl.load();
                }
            }
        });
    }
});
