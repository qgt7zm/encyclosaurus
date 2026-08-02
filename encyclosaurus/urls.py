from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
    path('map/', views.interactive_map, name='interactive_map'),
    path('dinosaurs/', views.browse_dinosaurs, name='browse_dinosaurs'),
    path('dinosaurs/<int:dino_id>/', views.view_dinosaur, name='view_dinosaur'),
    path('submit-dinosaur/', views.submit_dinosaur, name='submit_dinosaur'),
    path('requests/', views.requests, name='requests'),
    path('accept_request/<int:request_id>', views.accept_request, name='accept_request'),
    path('reject_request/<int:request_id>', views.reject_request, name='reject_request'),
    path('logs/', views.logs, name='logs'),
    path('login/', views.login, name='login'),
] 