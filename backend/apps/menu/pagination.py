from rest_framework.pagination import PageNumberPagination

class VideoFeedPagination(PageNumberPagination):
    page_size = 5  # Количество блюд на одной странице
    page_size_query_param = 'page_size'
    max_page_size = 20