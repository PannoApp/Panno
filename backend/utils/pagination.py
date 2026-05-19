from rest_framework.pagination import PageNumberPagination, CursorPagination


class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class VideoFeedPagination(PageNumberPagination):
    page_size = 5
    page_size_query_param = 'page_size'
    max_page_size = 20


# Курсорная пагинация для видеоленты: гарантирует стабильный обход
# при конкурентных вставках — страница-номер здесь неприменима, так как
# добавление нового блюда сдвигает все последующие страницы.
class VideoCursorPagination(CursorPagination):
    page_size = 5
    # Сортировка по id (монотонно возрастающий PK) — обязательное требование
    # CursorPagination: поле должно быть уникальным и стабильным.
    ordering = 'id'
    cursor_query_param = 'cursor'
