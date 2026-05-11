from django.db import models

class Category(models.Model):
    name = models.CharField("Название", max_length=100)
    order = models.PositiveIntegerField("Порядок отображения", default=0)

    class Meta:
        verbose_name = "Категория"
        verbose_name_plural = "Категории"
        ordering = ['order']

    def __str__(self):
        return self.name

class Tag(models.Model):
    name = models.CharField("Название тега", max_length=50)
    
    class Meta:
        verbose_name = "Тег"
        verbose_name_plural = "Теги"

    def __str__(self):
        return self.name

class Allergen(models.Model):
    name = models.CharField("Название аллергена", max_length=100)

    class Meta:
        verbose_name = "Аллерген"
        verbose_name_plural = "Аллергены"

    def __str__(self):
        return self.name

class Dish(models.Model):
    name = models.CharField("Название блюда", max_length=200)
    description = models.TextField("Описание", blank=True)
    price = models.DecimalField("Цена", max_digits=10, decimal_places=2)
    
    category = models.ForeignKey(
        Category, 
        on_delete=models.CASCADE, 
        related_name='dishes', 
        verbose_name="Категория"
    )
    tags = models.ManyToManyField(Tag, blank=True, verbose_name="Теги")
    allergens = models.ManyToManyField(Allergen, blank=True, verbose_name="Аллергены")
    
    image = models.ImageField("Фото", upload_to="dishes/images/")
    video = models.FileField("Видео (для ленты)", upload_to="dishes/videos/", blank=True, null=True)
    weight = models.PositiveIntegerField("Вес (г)", null=True, blank=True)
    story = models.TextField("История блюда", blank=True)

    is_active = models.BooleanField("Активно", default=True)

    class Meta:
        verbose_name = "Блюдо"
        verbose_name_plural = "Блюда"

    def __str__(self):
        return self.name