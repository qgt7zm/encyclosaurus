from django.urls import path
from . import views

app_name = "dinosaur"
urlpatterns = [
    path("submit-dinosaur/", views.submit_request, name = "submit_request"),
    path("update-dinosaur/", views.update_request, name = "update_request"),
]