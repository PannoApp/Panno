import os
from uuid import uuid4


def _uuid_path(directory: str, ext: str) -> str:
    return os.path.join(directory, f"{uuid4().hex}{ext}")


def dish_image_upload(instance, filename) -> str:
    return _uuid_path("dishes/images", ".jpg")


def dish_video_upload(instance, filename) -> str:
    ext = os.path.splitext(filename)[1].lower() or ".mp4"
    return _uuid_path("dishes/videos", ext)


def dish_video_processed_upload(instance, filename) -> str:
    ext = os.path.splitext(filename)[1].lower() or ".mp4"
    return _uuid_path("dishes/videos/processed", ext)


def event_image_upload(instance, filename) -> str:
    return _uuid_path("events/images", ".jpg")


def news_image_upload(instance, filename) -> str:
    return _uuid_path("news/images", ".jpg")


def event_report_image_upload(instance, filename) -> str:
    ext = os.path.splitext(filename)[1].lower() or ".jpg"
    return _uuid_path("events/reports", ext)


def interior_image_upload(instance, filename) -> str:
    ext = os.path.splitext(filename)[1].lower() or ".jpg"
    return _uuid_path("interior", ext)


def hero_image_upload(instance, filename) -> str:
    return _uuid_path("core/hero", ".jpg")
