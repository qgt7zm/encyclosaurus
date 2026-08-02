from django.db import models
from django.contrib.auth.models import User  # Django's built-in User model

class Researcher(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    institution = models.CharField()