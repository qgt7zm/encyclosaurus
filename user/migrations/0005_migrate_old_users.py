from django.db import migrations
from django.contrib.auth.hashers import make_password

def forward_migrate_users(apps, schema_editor):
    # Get models
    OldUser = apps.get_model('user', 'User')  # Your old User model
    DjangoUser = apps.get_model('auth', 'User')  # Django's User model
    Researcher = apps.get_model('user', 'Researcher')  # Your Researcher model
    
    # Migrate each old user to Django's auth system
    for old_user in OldUser.objects.all():
        # Create the Django User
        django_user = DjangoUser.objects.create(
            username=old_user.username,
            email=old_user.email,
            password=make_password(old_user.password),  # Hash the password
            is_staff=old_user.SiteManager,
            is_superuser=old_user.SiteManager,
            is_active=True
        )
        
        # Update the researcher record to link to the new user
        try:
            researcher = Researcher.objects.get(id=old_user.id)
            researcher.user = django_user
            researcher.save()
        except Researcher.DoesNotExist:
            # If no researcher record exists for this user, create one
            pass

class Migration(migrations.Migration):

    dependencies = [
        ('user', '0004_researcher_user_alter_researcher_id_delete_user'),
    ]

    operations = []
