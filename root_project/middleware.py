class AuthenticationMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Add user authentication info to all incoming requests
        request.user_authenticated = request.session.get('authenticated', False)
        request.username = request.session.get('username', '')
        
        response = self.get_response(request)
        return response 