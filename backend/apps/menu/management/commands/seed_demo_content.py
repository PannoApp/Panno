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


def _open_interior_asset(filename: str) -> File:
    path = _interior_image_path(filename)
    if path is None:
        raise FileNotFoundError(f"Нет ассета интерьера: {filename}")
    return File(path.open("rb"), name=path.name)


MENU_CATEGORIES = [
    ("Супы и бульоны", 1),
    ("Горячие блюда", 2),
    ("Салаты", 3),
    ("Десерты", 4),
    ("Напитки", 5),
]

TAGS = ["Острое", "Вегетарианское", "Авторское", "Халяль"]
ALLERGENS = ["Глютен", "Молоко", "Орехи", "Яйца"]

# (name, description, price, category_name, image, weight_g, story, tag_names, allergen_names)
DISHES = [
    (
        "Шорпа из баранины",
        "Наваристый бульон с картофелем и зеленью — согревает после долгой дороги.",
        "3 200",
        "Супы и бульоны",
        "soup.jpg",
        350,
        "Проводники варят шорпу по утрам — аромат дыма и мяса встречает гостя у входа.",
        [],
        [],
    ),
    (
        "Лагман по-степному",
        "Длинная лапша, говядина, перец и томат — медленный огонь, насыщенный вкус.",
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
        "Бешбармак домашний",
        "Отварное мясо на лепёшке, лук и бульон — традиция, которую не торопят.",
        "5 500",
        "Горячие блюда",
        "plov.jpg",
        550,
        "Блюдо для тех, кто пришёл за настоящим — без лишних украшений, только вкус.",
        ["Халяль"],
        ["Глютен"],
    ),
    (
        "Стейк из степной говядины",
        "Сочный срез medium, соль, перец и масло — чистый вкус мяса.",
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
        "Запечённая форель, лимон, укроп и масло — лёгкое, прохладное блюдо.",
        "6 200",
        "Горячие блюда",
        "fish.jpg",
        280,
        "Рыбу подают на каменной тарелке — сохраняет тепло и аромат дыма.",
        [],
        [],
    ),
    (
        "Салат «Степной»",
        "Зелень, томаты, огурцы, творожный сыр и ореховое масло.",
        "2 900",
        "Салаты",
        "salad.jpg",
        260,
        "Собирают перед подачей — хруст и свежесть как пауза между горячими блюдами.",
        ["Вегетарианское"],
        ["Молоко", "Орехи"],
    ),
    (
        "Хлеб из тандыра",
        "Тёплый лепёшка с хрустящей коркой — к первому бульону или чаю.",
        "1 200",
        "Салаты",
        "bread.jpg",
        180,
        "Пекут несколько раз за вечер — запах уходит в главный зал.",
        ["Вегетарианское"],
        ["Глютен"],
    ),
    (
        "Мёд, курага и грецкий орех",
        "Мягкий десерт без спешки — сладость степи и чай после ужина.",
        "2 400",
        "Десерты",
        "dessert.jpg",
        150,
        "Подают в глиняной чаше — тёплый финал пути за столом.",
        ["Вегетарианское"],
        ["Орехи"],
    ),
    (
        "Чай с молоком и солью",
        "Традиционный напиток в чайнике — делят на двоих, наливают медленно.",
        "1 800",
        "Напитки",
        "tea.jpg",
        400,
        "Чай — ритуал ожидания блюд и разговора с проводниками.",
        ["Халяль"],
        ["Молоко"],
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
