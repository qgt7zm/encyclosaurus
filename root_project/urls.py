"""
URL configuration for root_project project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.views.generic import TemplateView

from encyclosaurus import views
from user import views as user_views

def home_view(request):
    return user_views.home(request)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('user/', include('user.urls')),
    path('dinosaur/', include('dinosaur.urls')),
    path('', home_view, name='home'),
    path('login/', TemplateView.as_view(template_name='encyclosaurus/login.html'), name='login'),
    path('register/', TemplateView.as_view(template_name='encyclosaurus/register.html'), name='register'),
    path('submit-dinosaur/', views.submit_dinosaur, name='submit_dinosaur'),
    path('dinosaurs/', views.browse_dinosaurs, name='browse'),
    path('dinosaurs/<int:dino_id>', views.view_dinosaur, name='view_dinosaur'),
    path('dinosaurs/<int:dino_id>/update/', views.update_dinosaur, name='view_dinosaur'),
    path('requests', views.requests, name='requests'),
    path('accept_request/<int:request_id>', views.accept_request, name='accept_request'),
    path('reject_request/<int:request_id>', views.reject_request, name='reject_request'),
    path('logs', views.logs, name='logs'),
    path('map/', views.interactive_map, name='interactive_map'),
]
