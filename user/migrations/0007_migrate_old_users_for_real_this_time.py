from django.db import migrations
from django.contrib.auth.hashers import make_password

def migrate_legacy_users(apps, schema_editor):
    # Get a connection to run raw SQL queries
    connection = schema_editor.connection
    cursor = connection.cursor()
    
    # Get the Django User model and your new Researcher model
    User = apps.get_model('auth', 'User')
    Researcher = apps.get_model('user', 'Researcher')  # Change 'yourapp' to your actual app name
    
    # Fetch all users from the old users table
    cursor.execute("SELECT id, username, email, password, sitemanager FROM users")
    old_users = cursor.fetchall()
    
    # For each old user, create a new Django user and researcher
    for old_id, username, email, password, is_site_manager in old_users:
        # Skip if this username already exists in auth_user
        if User.objects.filter(username=username).exists():
            print(f"Skipping existing user: {username}")
            continue
            
        # Create the Django user
        django_user = User.objects.create(
            username=username,
            email=email,
            password=make_password(password),  # Hash the password
            is_staff=is_site_manager,
            is_superuser=is_site_manager,
            is_active=True
        )
        
        # See if there's a matching researcher record
        cursor.execute("SELECT institution FROM researchers WHERE id = %s", [old_id])
        researcher_data = cursor.fetchone()
        
        if researcher_data:
            institution = researcher_data[0]
            # Create a new researcher linked to the Django user
            Researcher.objects.create(
                user=django_user,
                institution=institution
            )
            print(f"Migrated user {username} with researcher profile")
        else:
            print(f"Migrated user {username} without researcher profile")


class Migration(migrations.Migration):

    dependencies = [
        ('user', '0006_alter_researcher_id_alter_researcher_user'),
    ]

    operations = [
        migrations.RunPython(migrate_legacy_users),
    ]
