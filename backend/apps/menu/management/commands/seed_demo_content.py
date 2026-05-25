"""
Демо-контент для локальной разработки: меню, интерьер, hero-слайды.

Использование (в Docker):
    python manage.py seed_demo_content
    python manage.py seed_demo_content --force

Картинки блюд: backend/apps/menu/seed_data/images/
Интерьер / hero: assets/images/interior_hero_*.png из корня Flutter-репо.
"""

from __future__ import annotations

from pathlib import Path

from django.core.files import File
from django.core.management.base import BaseCommand
from django.db import transaction

from apps.core.models import HeroSlide, InteriorPhoto, RestaurantInfo
from apps.menu.models import Allergen, Category, Dish, Tag

# backend/apps/menu/management/commands/ → menu app root
_MENU_APP_DIR = Path(__file__).resolve().parents[2]
_SEED_IMAGES_DIR = _MENU_APP_DIR / "seed_data" / "images"
_SEED_VIDEOS_DIR = _MENU_APP_DIR / "seed_data" / "videos"
_CORE_SEED_INTERIOR_DIR = _MENU_APP_DIR.parent / "core" / "seed_data" / "interior"
# Fallback: Flutter-ассеты при запуске manage.py с хоста (вне Docker)
_REPO_ROOT = _MENU_APP_DIR.parents[2]
_FLUTTER_INTERIOR_DIR = _REPO_ROOT / "assets" / "images"


def _interior_image_path(filename: str) -> Path | None:
    for base in (_CORE_SEED_INTERIOR_DIR, _FLUTTER_INTERIOR_DIR):
        path = base / filename
        if path.is_file():
            return path
    return None


def _open_seed_image(filename: str) -> File:
    path = _SEED_IMAGES_DIR / filename
    if not path.is_file():
        raise FileNotFoundError(f"Нет файла сида: {path}")
    return File(path.open("rb"), name=path.name)


def _open_seed_video(filename: str) -> File | None:
    """Возвращает File с готовым видео или None, если файла нет.

    Видео уже считаются обработанными — сохраняются прямо в video_processed
    со статусом READY, минуя Celery (т.к. это seed-данные).
    """
    path = _SEED_VIDEOS_DIR / filename
    if not path.is_file():
        return None
    return File(path.open("rb"), name=path.name)


def _open_interior_asset(filename: str) -> File:
    path = _interior_image_path(filename)
    if path is None:
        raise FileNotFoundError(f"Нет ассета интерьера: {filename}")
    return File(path.open("rb"), name=path.name)


# Готовые видео для feed-ленты (TikTok-режим в приложении).
# Ключ — name блюда из DISHES (точное совпадение). Значение — имя файла
# в seed_data/videos/. Если файла нет на диске, блюдо сидится без видео,
# а команда печатает предупреждение, но не падает.
# Поддерживаемые форматы — те же, что играет video_player Flutter:
# .mp4 (H.264/AAC) предпочтительно, .mov работает на iOS.
DISH_VIDEOS: dict[str, str] = {
    "Шорпа из баранины": "demo_dish.mov",
    "Плов на казане": "demo_dish.mov",
    "Плов с курицей": "demo_dish.mov",
    "Лагман по-степному": "demo_dish.mov",
    "Манты с бараниной": "demo_dish.mov",
    "Бешбармак домашний": "demo_dish.mov",
    "Стейк из степной говядины": "demo_dish.mov",
    "Чак-чак с мёдом": "demo_dish.mov",
}


MENU_CATEGORIES = [
    ("Супы и бульоны", 1),
    ("Горячие блюда", 2),
    ("Салаты", 3),
    ("Десерты", 4),
    ("Напитки", 5),
]

TAGS = ["Острое", "Вегетарианское", "Веган", "Авторское", "Халяль"]
ALLERGENS = ["Глютен", "Молоко", "Орехи", "Яйца"]

# (name, description, price, category_name, image, weight_g, story, tag_names, allergen_names)
DISHES = [
    # ── Супы и бульоны ───────────────────────────────────────────────────────
    (
        "Шорпа из баранины",
        "Наваристый бульон с картофелем, морковью и зеленью — согревает после долгой дороги.",
        "3 200",
        "Супы и бульоны",
        "soup.jpg",
        350,
        "Проводники варят шорпу по утрам — аромат дыма и мяса встречает гостя у входа.",
        ["Халяль"],
        [],
    ),
    (
        "Сорпа с домашней лапшой",
        "Прозрачный бульон, тонкая лапша и зелень — лёгкое начало трапезы без тяжести.",
        "2 800",
        "Супы и бульоны",
        "soup.jpg",
        320,
        "Лапшу отваривают отдельно, в бульон кладут в последний момент — сохраняется нежность.",
        ["Халяль"],
        ["Глютен"],
    ),
    (
        "Машхурда",
        "Крем-суп из красной чечевицы с тмином и маслом — бархатная текстура, тёплый аромат.",
        "2 600",
        "Супы и бульоны",
        "soup.jpg",
        300,
        "Подходят вегетарианцам и тем, кто ищет мягкий вкус перед основным блюдом.",
        ["Вегетарианское", "Халяль"],
        [],
    ),
    # ── Горячие блюда ────────────────────────────────────────────────────────
    (
        "Лагман по-степному",
        "Длинная лапша, говядина, болгарский перец и томат — медленный огонь, насыщенный вкус.",
        "4 100",
        "Горячие блюда",
        "lagman.jpg",
        420,
        "Лагман тянут вручную — каждая порция как отдельный этап пути.",
        ["Авторское"],
        ["Глютен"],
    ),
    (
        "Плов на казане",
        "Рис, морковь, зира и нежная баранина — румяная корочка снизу, дымок сверху.",
        "4 800",
        "Горячие блюда",
        "plov.jpg",
        480,
        "Казан стоит в центре зала по пятницам — гости слышат шипение за минуту до подачи.",
        ["Халяль", "Авторское"],
        [],
    ),
    (
        "Плов с курицей",
        "Тот же рис и специи, но с нежным филе — мягче по вкусу, удобно для первого визита.",
        "4 200",
        "Горячие блюда",
        "plov.jpg",
        450,
        "Готовят в отдельном казане, чтобы не смешивать с бараниной — чистый вкус птицы.",
        ["Халяль"],
        [],
    ),
    (
        "Бешбармак домашний",
        "Отварное мясо на лепёшке, репчатый лук и горячий бульон — традиция, которую не торопят.",
        "5 500",
        "Горячие блюда",
        "plov.jpg",
        550,
        "Блюдо для тех, кто пришёл за настоящим — без лишних украшений, только вкус.",
        ["Халяль", "Авторское"],
        ["Глютен"],
    ),
    (
        "Манты с бараниной",
        "Паровые манты с соком внутри — подают с соусом из томатов и перца, посыпают зеленью.",
        "3 900",
        "Горячие блюда",
        "lagman.jpg",
        380,
        "Лепят утром, готовят на пару к обеду — мясо остаётся сочным, тесто тонким.",
        ["Халяль"],
        ["Глютен"],
    ),
    (
        "Куырдак из печени и почек",
        "Обжарка на сильном огне с луком и специями — смелый вкус для тех, кто знает степь.",
        "4 600",
        "Горячие блюда",
        "steak.jpg",
        340,
        "Готовят на открытой сковороде — хруст снаружи, мягкость внутри.",
        ["Халяль", "Острое"],
        [],
    ),
    (
        "Стейк из степной говядины",
        "Сочный срез medium, морская соль, перец и топлёное масло — чистый вкус мяса.",
        "8 900",
        "Горячие блюда",
        "steak.jpg",
        320,
        "Мясо зреет сутки, жарится на углях — финальный аккорд вечера.",
        ["Авторское"],
        [],
    ),
    (
        "Форель с травами",
        "Запечённая форель, лимон, укроп и сливочное масло — лёгкое блюдо между мясными.",
        "6 200",
        "Горячие блюда",
        "fish.jpg",
        280,
        "Рыбу подают на каменной тарелке — сохраняет тепло и аромат дыма.",
        [],
        ["Молоко"],
    ),
    (
        "Сёмга на углях",
        "Филе с хрустящей коркой, соус из йогурта и укропа — прохладный контраст к жару.",
        "7 400",
        "Горячие блюда",
        "fish.jpg",
        260,
        "Маринуют два часа, жарят коротко — внутри остаётся розовой.",
        ["Авторское"],
        ["Молоко"],
    ),
    # ── Салаты ───────────────────────────────────────────────────────────────
    (
        "Салат «Степной»",
        "Зелень, томаты, огурцы, творожный сыр и ореховое масло — свежий, с хрустом.",
        "2 900",
        "Салаты",
        "salad.jpg",
        260,
        "Собирают перед подачей — пауза между горячими блюдами.",
        ["Вегетарианское"],
        ["Молоко", "Орехи"],
    ),
    (
        "Салат с бараниной и гранатом",
        "Тёплая баранина, руккола, гранат и лимонная заправка — сочетание сладости и кислоты.",
        "4 300",
        "Салаты",
        "salad.jpg",
        290,
        "Мясо томят в специях, остужают — контраст с холодными листьями.",
        ["Халяль", "Авторское"],
        [],
    ),
    (
        "Овощи на гриле",
        "Кабачки, баклажаны, перец и томаты с чесночным маслом — для лёгкого ужина.",
        "2 500",
        "Салаты",
        "salad.jpg",
        240,
        "Овощи маринуют час, жарят на углях — дымок остаётся в аромате.",
        ["Вегетарианское", "Веган"],
        [],
    ),
    (
        "Хлеб из тандыра",
        "Тёплая лепёшка с хрустящей коркой — к бульону, салату или чаю.",
        "1 200",
        "Салаты",
        "bread.jpg",
        180,
        "Пекут несколько раз за вечер — запах уходит в главный зал.",
        ["Вегетарианское"],
        ["Глютен"],
    ),
    (
        "Бауырсақ с мёдом",
        "Пышные пончики, мёд и сметана — делят на стол, едят руками, без спешки.",
        "1 600",
        "Салаты",
        "bread.jpg",
        200,
        "Жарят перед подачей — тесто остаётся воздушным внутри.",
        ["Вегетарианское"],
        ["Глютен", "Молоко", "Яйца"],
    ),
    # ── Десерты ──────────────────────────────────────────────────────────────
    (
        "Мёд, курага и грецкий орех",
        "Мягкий десерт без выпечки — сладость степи и чай после ужина.",
        "2 400",
        "Десерты",
        "dessert.jpg",
        150,
        "Подают в глиняной чаше — тёплый финал пути за столом.",
        ["Вегетарианское"],
        ["Орехи"],
    ),
    (
        "Чак-чак с миндалём",
        "Хрустящие кусочки в мёде, миндаль сверху — сладко, но не приторно.",
        "2 800",
        "Десерты",
        "dessert.jpg",
        180,
        "Готовят небольшими партиями — лучше свежим, с лёгким хрустом.",
        ["Вегетарианское"],
        ["Глютен", "Орехи", "Яйца"],
    ),
    (
        "Сырне с изюмом",
        "Творожная запеканка, изюм и сметана — домашний вкус, спокойный финал.",
        "2 200",
        "Десерты",
        "dessert.jpg",
        160,
        "Пекут в глиняной форме — края слегка карамелизуются.",
        ["Вегетарианское"],
        ["Молоко", "Яйца", "Глютен"],
    ),
    # ── Напитки ──────────────────────────────────────────────────────────────
    (
        "Чай с молоком и солью",
        "Традиционный напиток в чайнике — наливают медленно, делят на двоих.",
        "1 800",
        "Напитки",
        "tea.jpg",
        400,
        "Чай — ритуал ожидания блюд и разговора с проводниками.",
        ["Халяль"],
        ["Молоко"],
    ),
    (
        "Чай зелёный жасмин",
        "Лёгкий аромат цветов, без молока — после плотного ужина или к десерту.",
        "1 400",
        "Напитки",
        "tea.jpg",
        350,
        "Заваривают при температуре ниже кипятка — не горчит.",
        ["Веган", "Халяль"],
        [],
    ),
    (
        "Морс из смородины",
        "Кисло-сладкий, со льдом летом и тёплый зимой — освежает между блюдами.",
        "1 100",
        "Напитки",
        "tea.jpg",
        300,
        "Ягоды варят с сахаром и корицой — без искусственных ароматизаторов.",
        ["Веган", "Вегетарианское"],
        [],
    ),
]

INTERIOR_PHOTOS = [
    ("main_hall", "interior_hero_1.png", "Главный зал — свет камина", 1),
    ("main_hall", "interior_hero_2.png", "Главный зал — вечерний свет", 2),
    ("bar", "interior_hero_3.png", "Бар — медь и тёплый янтарь", 1),
    ("terrace", "interior_hero_1.png", "Терраса — вид на огни", 2),
    ("private", "interior_hero_2.png", "Приватная комната — тишина", 1),
    ("main_hall", "interior_hero_3.png", "Зал — детали дерева и камня", 3),
]

HERO_SLIDES = [
    ("interior_hero_1.png", 0),
    ("interior_hero_2.png", 1),
    ("interior_hero_3.png", 2),
]

CONCEPT_TEXT = (
    "Piligrim — кухня свободы и традиций. Каждый визит — путь: проводники встречают у порога, "
    "огонь в зале, блюда из степи и гор. Здесь не торопят — ужин становится историей."
)


class Command(BaseCommand):
    help = "Заполняет меню, интерьер и hero-слайды демо-данными для локального приложения"

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Удалить существующие блюда, интерьер и hero-слайды и создать заново",
        )
        parser.add_argument(
            "--menu-only",
            action="store_true",
            help="Только меню (категории, теги, блюда)",
        )
        parser.add_argument(
            "--interior-only",
            action="store_true",
            help="Только интерьер и hero-слайды",
        )

    def handle(self, *args, **options):
        force = options["force"]
        menu_only = options["menu_only"]
        interior_only = options["interior_only"]

        if menu_only and interior_only:
            self.stderr.write("Укажите только один из флагов --menu-only / --interior-only.")
            return

        with transaction.atomic():
            if not interior_only:
                self._seed_menu(force)
            if not menu_only:
                self._seed_interior_and_hero(force)
                self._seed_restaurant_text()

        self.stdout.write(self.style.SUCCESS("seed_demo_content завершён."))

    def _seed_menu(self, force: bool) -> None:
        if force:
            deleted, _ = Dish.objects.all().delete()
            Category.objects.all().delete()
            Tag.objects.all().delete()
            Allergen.objects.all().delete()
            self.stdout.write(f"  Меню очищено (блюд удалено: {deleted})")
        elif Dish.objects.exists():
            self.stdout.write(
                "  Меню уже есть — пропуск (добавьте --force для пересоздания)"
            )
            return

        tags = {name: Tag.objects.create(name=name) for name in TAGS}
        allergens = {name: Allergen.objects.create(name=name) for name in ALLERGENS}
        categories = {
            name: Category.objects.create(name=name, order=order)
            for name, order in MENU_CATEGORIES
        }

        for row in DISHES:
            (
                name,
                description,
                price_str,
                cat_name,
                image_file,
                weight,
                story,
                tag_names,
                allergen_names,
            ) = row
            price = int(price_str.replace(" ", ""))
            dish = Dish(
                name=name,
                description=description,
                price=price,
                category=categories[cat_name],
                weight=weight,
                story=story,
                is_active=True,
            )
            dish.image.save(image_file, _open_seed_image(image_file), save=True)
            for t in tag_names:
                dish.tags.add(tags[t])
            for a in allergen_names:
                if a in allergens:
                    dish.allergens.add(allergens[a])

            # Видео для feed-ленты (если для блюда задан файл и он есть на диске).
            video_filename = DISH_VIDEOS.get(name)
            if video_filename:
                video_file = _open_seed_video(video_filename)
                if video_file is None:
                    self.stderr.write(
                        self.style.WARNING(
                            f"    Нет видео {video_filename} — блюдо без feed-видео"
                        )
                    )
                else:
                    dish.video_processed.save(video_filename, video_file, save=False)
                    dish.video_status = Dish.VideoStatus.READY
                    dish.save(update_fields=["video_processed", "video_status"])
                    self.stdout.write(f"    + видео: {video_filename}")

            self.stdout.write(f"  Блюдо: {name}")

        self.stdout.write(
            self.style.SUCCESS(f"  Меню: {len(DISHES)} блюд, {len(categories)} категорий")
        )

    def _seed_interior_and_hero(self, force: bool) -> None:
        if force:
            InteriorPhoto.objects.all().delete()
            HeroSlide.objects.all().delete()
            self.stdout.write("  Интерьер и hero-слайды очищены")
        elif InteriorPhoto.objects.exists() or HeroSlide.objects.exists():
            self.stdout.write(
                "  Интерьер/hero уже есть — пропуск (добавьте --force)"
            )
            return

        needed = {p[1] for p in INTERIOR_PHOTOS} | {s[0] for s in HERO_SLIDES}
        missing = [f for f in needed if _interior_image_path(f) is None]
        if missing:
            self.stderr.write(
                self.style.WARNING(
                    f"  Нет PNG интерьера: {', '.join(sorted(missing))}. "
                    "Положите файлы в backend/apps/core/seed_data/interior/ "
                    "или assets/images/."
                )
            )

        info = RestaurantInfo.load()
        for zone, filename, caption, order in INTERIOR_PHOTOS:
            if _interior_image_path(filename) is None:
                continue
            photo = InteriorPhoto(zone=zone, caption=caption, order=order)
            photo.image.save(filename, _open_interior_asset(filename), save=True)
            self.stdout.write(f"  Интерьер: {caption}")

        for filename, order in HERO_SLIDES:
            if _interior_image_path(filename) is None:
                continue
            slide = HeroSlide(restaurant_info=info, order=order)
            slide.image.save(filename, _open_interior_asset(filename), save=True)
            self.stdout.write(f"  Hero-слайд {order + 1}")

    def _seed_restaurant_text(self) -> None:
        info = RestaurantInfo.load()
        if not info.concept_description or info.concept_description.strip() == "":
            info.concept_description = CONCEPT_TEXT
            info.save(update_fields=["concept_description"])
            self.stdout.write("  Описание концепции ресторана обновлено")
