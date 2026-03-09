#!/usr/bin/env python3
"""
Google OAuth2 Helper for Headless Environments

This script helps generate OAuth2 refresh tokens for Gmail and Google Calendar
access in headless/server environments.

Usage:
    python3 google-oauth-helper.py --client-id CLIENT_ID --client-secret CLIENT_SECRET --scopes SCOPES

Scopes can be:
    gmail - Gmail read/write access
    calendar - Google Calendar access
    gmail-read - Gmail read-only
    all - Both Gmail and Calendar (default)

The script will output a URL to visit in your browser, then prompt for the
authorization code returned after you grant access.
"""

import argparse
import json
import os
import sys
from pathlib import Path

try:
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
except ImportError:
    print("Error: Required packages not installed.")
    print("Run: pip install google-auth-oauthlib google-auth-httplib2")
    sys.exit(1)

# Scope definitions
SCOPES = {
    'gmail': [
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/gmail.labels',
        'https://www.googleapis.com/auth/gmail.modify',
    ],
    'gmail-read': [
        'https://www.googleapis.com/auth/gmail.readonly',
    ],
    'calendar': [
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/calendar.events',
    ],
    'calendar-read': [
        'https://www.googleapis.com/auth/calendar.readonly',
    ],
    'all': [],
}

# Populate 'all' with all scopes
SCOPES['all'] = SCOPES['gmail'] + SCOPES['calendar']


def generate_refresh_token(client_id: str, client_secret: str, scopes: list) -> dict:
    """
    Generate OAuth2 refresh token using installed app flow.
    
    Returns dict with token details.
    """
    client_config = {
        "installed": {
            "client_id": client_id,
            "client_secret": client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "redirect_uris": ["urn:ietf:wg:oauth:2.0:oob", "http://localhost"]
        }
    }
    
    flow = InstalledAppFlow.from_client_config(client_config, scopes)
    
    # Use console flow for headless environments
    credentials = flow.run_console()
    
    return {
        'refresh_token': credentials.refresh_token,
        'token_uri': credentials.token_uri,
        'client_id': credentials.client_id,
        'client_secret': credentials.client_secret,
        'scopes': credentials.scopes,
    }


def validate_refresh_token(refresh_token: str, client_id: str, client_secret: str) -> bool:
    """
    Validate that a refresh token still works.
    """
    try:
        creds = Credentials(
            token=None,
            refresh_token=refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=client_id,
            client_secret=client_secret,
        )
        creds.refresh(Request())
        return True
    except Exception as e:
        print(f"Token validation failed: {e}")
        return False


def output_env_vars(token_data: dict):
    """
    Output the credentials as environment variable format.
    """
    print("\n" + "="*60)
    print("COPY THESE ENVIRONMENT VARIABLES TO YOUR CONFIGURATION:")
    print("="*60)
    print(f"GMAIL_CLIENT_ID={token_data['client_id']}")
    print(f"GMAIL_CLIENT_SECRET={token_data['client_secret']}")
    print(f"GMAIL_REFRESH_TOKEN={token_data['refresh_token']}")
    print("="*60)
    
    # Also output as JSON for easy copying
    print("\nJSON format (for Railway bulk import):")
    print(json.dumps({
        'GMAIL_CLIENT_ID': token_data['client_id'],
        'GMAIL_CLIENT_SECRET': token_data['client_secret'],
        'GMAIL_REFRESH_TOKEN': token_data['refresh_token'],
    }, indent=2))


def main():
    parser = argparse.ArgumentParser(
        description='Generate Google OAuth2 refresh tokens for headless environments'
    )
    parser.add_argument('--client-id', required=False,
                        help='Google OAuth2 Client ID')
    parser.add_argument('--client-secret', required=False,
                        help='Google OAuth2 Client Secret')
    parser.add_argument('--scopes', '-s', default='all',
                        choices=['gmail', 'gmail-read', 'calendar', 'calendar-read', 'all'],
                        help='OAuth scopes to request (default: all)')
    parser.add_argument('--validate', action='store_true',
                        help='Validate existing refresh token instead of generating new one')
    parser.add_argument('--refresh-token',
                        help='Refresh token to validate (use with --validate)')
    parser.add_argument('--output', '-o', choices=['env', 'json'], default='env',
                        help='Output format (default: env)')
    
    args = parser.parse_args()
    
    # Validation mode
    if args.validate:
        if not all([args.refresh_token, args.client_id, args.client_secret]):
            print("Error: --validate requires --refresh-token, --client-id, and --client-secret")
            sys.exit(1)
        
        if validate_refresh_token(args.refresh_token, args.client_id, args.client_secret):
            print("Token is valid!")
            sys.exit(0)
        else:
            print("Token is invalid or expired")
            sys.exit(1)
    
    # Generation mode
    if not args.client_id or not args.client_secret:
        print("="*60)
        print("GOOGLE OAUTH2 TOKEN GENERATOR")
        print("="*60)
        print("""
To use this script, you need to create Google OAuth2 credentials:

1. Go to: https://console.cloud.google.com/apis/credentials
2. Create a new project or select existing one
3. Click "Create Credentials" > "OAuth client ID"
4. Select "Desktop app" as application type
5. Copy the Client ID and Client Secret

Then run:
    python3 google-oauth-helper.py \\
        --client-id "YOUR_CLIENT_ID" \\
        --client-secret "YOUR_CLIENT_SECRET" \\
        --scopes all
        """)
        sys.exit(1)
    
    scopes = SCOPES[args.scopes]
    print(f"\nRequesting scopes: {args.scopes}")
    for scope in scopes:
        print(f"  - {scope}")
    print()
    
    token_data = generate_refresh_token(args.client_id, args.client_secret, scopes)
    
    if args.output == 'json':
        print(json.dumps({
            'GMAIL_CLIENT_ID': token_data['client_id'],
            'GMAIL_CLIENT_SECRET': token_data['client_secret'],
            'GMAIL_REFRESH_TOKEN': token_data['refresh_token'],
        }, indent=2))
    else:
        output_env_vars(token_data)


if __name__ == '__main__':
    main()
