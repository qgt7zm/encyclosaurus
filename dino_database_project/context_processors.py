def auth_context_processor(request):
    """
    Add authentication information and messages to the context of all templates.
    """
    # Get success message from session and remove it after using it
    success_message = request.session.pop('success_message', None)
    
    return {
        'user_authenticated': request.session.get('authenticated', False),
        'username': request.session.get('username', ''),
        'success_message': success_message,
    } 