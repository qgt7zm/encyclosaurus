from django.shortcuts import render, redirect
from django.http import HttpResponse
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login as auth_login, logout as auth_logout
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from .models import Researcher

username_max_length = 50
password_min_length = 8

def register(request):
    if request.method == 'POST':
        username = request.POST.get("username", "")
        email = request.POST.get("email", "")
        password = request.POST.get("password", "")
        confirm_password = request.POST.get("confirm_password", "")
        institution = request.POST.get("institution", "")
        
        # Prepare context for form with entered values
        context = {
            'username': username,
            'email': email,
            'institution': institution,
            'errors_list': []  # Initialize errors list
        }
        
        # Field-specific validation errors
        validation_errors = False
        
        # Validate username
        if not valid_length_username(username):
            error_message = f"Username must be between 1 and {username_max_length} characters."
            context['username_error'] = error_message
            context['errors_list'].append(error_message)
            validation_errors = True
            
        if User.objects.filter(username=username).exists():
            error_message = "This username is already taken."
            context['username_error'] = error_message
            context['errors_list'].append(error_message)
            validation_errors = True
            
        # Validate email
        if User.objects.filter(email=email).exists():
            error_message = "This email is already registered."
            context['email_error'] = error_message
            context['errors_list'].append(error_message)
            validation_errors = True
            
        # Validate password
        if not valid_length_password(password):
            error_message = f"Password must be at least {password_min_length} characters long."
            context['password_error'] = error_message
            context['errors_list'].append(error_message)
            validation_errors = True
            
        if  password != confirm_password:
            error_message = "Passwords do not match."
            context['confirm_password_error'] = error_message
            context['errors_list'].append(error_message)
            validation_errors = True
        
        # If validation passes, create account
        if not validation_errors:
            # Create the User (Django handles password hashing)
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password  # create_user automatically hashes this
            )
            
            # Create the Researcher profile
            Researcher.objects.create(
                user=user,
                institution=institution
            )
            
            # Log the user in after registration
            auth_login(request, user)
            
            # Set success message
            messages.success(request, f"Welcome, {username}! Your account has been successfully created.")
            
            return redirect('/')
        
        # If validation fails, render the form with errors
        return render(request, 'encyclosaurus/register.html', context)
    
    # For GET requests, just show the form
    return render(request, 'encyclosaurus/register.html')

def login(request):
    if request.method == 'POST':
        email = request.POST.get("email", "")
        password = request.POST.get("password", "")
                # Get the username from email (since Django auth uses username by default)
        try:
            user_obj = User.objects.get(email=email)
            username = user_obj.username
            # Authenticate with username and password
            user = authenticate(request, username=username, password=password)
        except User.DoesNotExist:
            user = None
            
        if user:
            # Log the user in - this sets up the session
            auth_login(request, user)
            
            # Set success message
            messages.success(request, f"Welcome back, {user.username}! You have successfully logged in.")
            
            return redirect('/')
        else:
            # Authentication failed
            context = {
                'error': 'Invalid email or password. Please check your credentials and try again.'
            }
            return render(request, 'encyclosaurus/login.html', context)
    
    # For GET requests, just show the form
    return render(request, 'encyclosaurus/login.html')

def home(request):
    context = {
        'user_authenticated': request.user.is_authenticated,
        'username': request.user.username if request.user.is_authenticated else '',
        # If you're using Django's message framework:
        # 'success_message': messages will be available in the template automatically
    }
    return render(request, 'encyclosaurus/home.html', context)

def logout(request):
    # Get username before logging out
    username = request.user.username if request.user.is_authenticated else ''
    
    # Log the user out - this clears the session
    auth_logout(request)
    
    # Add success message
    if username:
        messages.success(request, "You have been successfully logged out. See you again soon!")
    
    return redirect('/')


def valid_length_username(username):
    return 1 <= len(username) <= username_max_length

def valid_length_password(password):
    return password_min_length <= len(password)