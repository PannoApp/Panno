import io
import re

from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image


# ── helpers ────────────────────────────────────────────────────────────────

def _make_png(name: str = "photo.png", width: int = 1600, height: int = 900) -> SimpleUploadedFile:
    img = Image.new("RGB", (width, height), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type="image/png")


def _make_landscape_png(name: str = "photo.png") -> SimpleUploadedFile:
    return _make_png(name, width=1600, height=900)


def _make_jpeg_stub(name: str = "photo.jpg") -> SimpleUploadedFile:
    img = Image.new("RGB", (1600, 900), color=(80, 80, 80))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type="image/jpeg")


_UUID_RE = re.compile(r'^[0-9a-f]{32}$')


# ── 1. UUID-callable из upload_paths ───────────────────────────────────────

class UploadPathsUniqueTest(TestCase):

    def test_dish_image_paths_differ(self):
        from utils.upload_paths import dish_image_upload
        self.assertNotEqual(
            dish_image_upload(None, "photo.jpg"),
            dish_image_upload(None, "photo.jpg"),
        )

    def test_event_image_paths_differ(self):
        from utils.upload_paths import event_image_upload
        self.assertNotEqual(
            event_image_upload(None, "photo.jpg"),
            event_image_upload(None, "photo.jpg"),
        )

    def test_interior_image_paths_differ(self):
        from utils.upload_paths import interior_image_upload
        self.assertNotEqual(
            interior_image_upload(None, "photo.jpg"),
            interior_image_upload(None, "photo.jpg"),
        )

    def test_dish_image_upload_uses_jpg_extension(self):
        from utils.upload_paths import dish_image_upload
        path = dish_image_upload(None, "something.png")
        self.assertTrue(path.endswith(".jpg"))
        self.assertTrue(path.startswith("dishes/images/"))

    def test_dish_video_upload_preserves_extension(self):
        from utils.upload_paths import dish_video_upload
        path = dish_video_upload(None, "clip.mp4")
        self.assertTrue(path.endswith(".mp4"))
        self.assertTrue(path.startswith("dishes/videos/"))

    def test_interior_upload_preserves_extension(self):
        from utils.upload_paths import interior_image_upload
        path = interior_image_upload(None, "room.jpeg")
        self.assertTrue(path.endswith(".jpeg"))
        self.assertTrue(path.startswith("interior/"))

    def test_path_basename_is_32_hex_chars(self):
        import os
        from utils.upload_paths import dish_image_upload
        path = dish_image_upload(None, "x.jpg")
        basename = os.path.splitext(os.path.basename(path))[0]
        self.assertEqual(len(basename), 32)
        self.assertRegex(basename, _UUID_RE)

    def test_event_report_preserves_extension(self):
        from utils.upload_paths import event_report_image_upload
        path = event_report_image_upload(None, "report.png")
        self.assertTrue(path.endswith(".png"))
        self.assertTrue(path.startswith("events/reports/"))

    def test_hero_image_upload_uses_jpg(self):
        from utils.upload_paths import hero_image_upload
        path = hero_image_upload(None, "slide.png")
        self.assertTrue(path.endswith(".jpg"))
        self.assertTrue(path.startswith("core/hero/"))


# ── 2. center_crop_to_ratio → JPEG ─────────────────────────────────────────

class CenterCropToRatioTest(TestCase):

    def test_returns_jpeg(self):
        from utils.image_processing import center_crop_to_ratio
        result = center_crop_to_ratio(_make_landscape_png(), 16 / 9)
        img = Image.open(io.BytesIO(result.read()))
        self.assertEqual(img.format, "JPEG")

    def test_output_width_respects_max_width(self):
        from utils.image_processing import center_crop_to_ratio
        big = _make_png("big.png", width=2400, height=1350)
        result = center_crop_to_ratio(big, 16 / 9, max_width=1200)
        img = Image.open(io.BytesIO(result.read()))
        self.assertLessEqual(img.width, 1200)

    def test_png_with_alpha_converted_to_rgb(self):
        from utils.image_processing import center_crop_to_ratio
        rgba = Image.new("RGBA", (1600, 900), color=(100, 150, 200, 128))
        buf = io.BytesIO()
        rgba.save(buf, format="PNG")
        buf.seek(0)
        uploaded = SimpleUploadedFile("alpha.png", buf.read(), content_type="image/png")
        result = center_crop_to_ratio(uploaded, 16 / 9)
        img = Image.open(io.BytesIO(result.read()))
        self.assertEqual(img.mode, "RGB")

    def test_output_ratio_is_correct(self):
        from utils.image_processing import center_crop_to_ratio
        result = center_crop_to_ratio(_make_png("r.png", 1600, 900), 16 / 9)
        img = Image.open(io.BytesIO(result.read()))
        actual_ratio = img.width / img.height
        self.assertAlmostEqual(actual_ratio, 16 / 9, places=1)


# ── 3. AutoCropImageMixin сохраняет UUID-имя ───────────────────────────────

class AutoCropImageMixinUUIDNameTest(TestCase):

    def setUp(self):
        from apps.menu.models import Category
        self.cat = Category.objects.create(name="Тест", order=1)

    def test_saved_filename_is_uuid_hex(self):
        import os
        from apps.menu.models import Dish
        dish = Dish.objects.create(
            name="Блюдо",
            description="",
            price="100.00",
            category=self.cat,
            image=_make_landscape_png("my_special_photo.png"),
        )
        dish.refresh_from_db()
        basename = os.path.splitext(os.path.basename(dish.image.name))[0]
        self.assertRegex(basename, _UUID_RE)
        self.assertNotEqual(basename, "my_special_photo")

    def test_saved_file_is_jpeg(self):
        from apps.menu.models import Dish
        dish = Dish.objects.create(
            name="JPEG-блюдо",
            description="",
            price="100.00",
            category=self.cat,
            image=_make_landscape_png("input.png"),
        )
        dish.refresh_from_db()
        self.assertTrue(dish.image.name.endswith(".jpg"))

    def test_file_exists_in_storage(self):
        from apps.menu.models import Dish
        dish = Dish.objects.create(
            name="Storage-блюдо",
            description="",
            price="100.00",
            category=self.cat,
            image=_make_landscape_png(),
        )
        dish.refresh_from_db()
        self.assertTrue(default_storage.exists(dish.image.name))

    def test_image_stored_in_correct_directory(self):
        from apps.menu.models import Dish
        dish = Dish.objects.create(
            name="Dir-блюдо",
            description="",
            price="100.00",
            category=self.cat,
            image=_make_landscape_png(),
        )
        dish.refresh_from_db()
        self.assertTrue(dish.image.name.startswith("dishes/images/"))


# ── 4. Коллизия: два объекта с одинаковым именем ──────────────────────────

class FileCollisionTest(TestCase):

    def setUp(self):
        from apps.menu.models import Category
        self.cat = Category.objects.create(name="Коллизия", order=99)

    def test_two_dishes_with_same_filename_have_different_paths(self):
        from apps.menu.models import Dish
        d1 = Dish.objects.create(
            name="Блюдо 1", description="", price="100.00",
            category=self.cat,
            image=_make_landscape_png("photo.png"),
        )
        d2 = Dish.objects.create(
            name="Блюдо 2", description="", price="200.00",
            category=self.cat,
            image=_make_landscape_png("photo.png"),
        )
        d1.refresh_from_db()
        d2.refresh_from_db()
        self.assertNotEqual(d1.image.name, d2.image.name)

    def test_both_files_exist_in_storage(self):
        from apps.menu.models import Dish
        d1 = Dish.objects.create(
            name="Блюдо A", description="", price="100.00",
            category=self.cat,
            image=_make_landscape_png("photo.png"),
        )
        d2 = Dish.objects.create(
            name="Блюдо B", description="", price="200.00",
            category=self.cat,
            image=_make_landscape_png("photo.png"),
        )
        d1.refresh_from_db()
        d2.refresh_from_db()
        self.assertTrue(default_storage.exists(d1.image.name))
        self.assertTrue(default_storage.exists(d2.image.name))

    def test_interior_photos_with_same_filename_have_different_paths(self):
        from apps.core.models import InteriorPhoto
        p1 = InteriorPhoto.objects.create(
            image=_make_jpeg_stub("room.jpg"),
            zone="main_hall",
        )
        p2 = InteriorPhoto.objects.create(
            image=_make_jpeg_stub("room.jpg"),
            zone="bar",
        )
        self.assertNotEqual(p1.image.name, p2.image.name)
        self.assertTrue(default_storage.exists(p1.image.name))
        self.assertTrue(default_storage.exists(p2.image.name))

    def test_event_images_with_same_filename_have_different_paths(self):
        from django.utils import timezone
        from apps.events.models import Event
        e1 = Event.objects.create(
            title="Событие 1", description="Описание",
            date_time=timezone.now(),
            image=_make_landscape_png("event.png"),
        )
        e2 = Event.objects.create(
            title="Событие 2", description="Описание",
            date_time=timezone.now(),
            image=_make_landscape_png("event.png"),
        )
        e1.refresh_from_db()
        e2.refresh_from_db()
        self.assertNotEqual(e1.image.name, e2.image.name)
        self.assertTrue(default_storage.exists(e1.image.name))
        self.assertTrue(default_storage.exists(e2.image.name))
