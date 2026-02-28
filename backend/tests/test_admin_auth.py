#!/usr/bin/env python3
"""
Test Script für Admin-Endpoint Authentifizierung
"""

import requests

BASE_URL = "http://localhost:8000"

def test_admin_endpoint_auth():
    """Testet ob Admin-Endpoint mit Cookie-Auth funktioniert"""

    print("🧪 Test: Admin-Endpoint Authentifizierung\n")

    # 1. Login
    print("1️⃣ Login als Admin...")
    login_response = requests.post(
        f"{BASE_URL}/login",
        json={"username": "admin", "password": "your_password_here"},
        headers={"Content-Type": "application/json"}
    )

    if login_response.status_code != 200:
        print(f"❌ Login fehlgeschlagen: {login_response.status_code}")
        print(f"   Response: {login_response.text}")
        return False

    print(f"✅ Login erfolgreich")

    # Cookies aus Login-Response extrahieren
    cookies = login_response.cookies
    print(f"   Cookies: {list(cookies.keys())}")

    # 2. Admin-Endpoint testen
    print("\n2️⃣ Admin-Endpoint aufrufen...")
    admin_response = requests.get(
        f"{BASE_URL}/admin/users",
        cookies=cookies
    )

    if admin_response.status_code == 200:
        print(f"✅ Admin-Endpoint erfolgreich: {admin_response.status_code}")
        users = admin_response.json()
        print(f"   {len(users)} User geladen")
        return True
    else:
        print(f"❌ Admin-Endpoint fehlgeschlagen: {admin_response.status_code}")
        print(f"   Response: {admin_response.text}")
        return False

if __name__ == "__main__":
    print("⚠️  Stelle sicher, dass das Backend läuft: uvicorn backend.main:app --reload\n")
    print("⚠️  Passe Username/Password im Script an!\n")

    success = test_admin_endpoint_auth()

    if success:
        print("\n🎉 Test erfolgreich!")
    else:
        print("\n❌ Test fehlgeschlagen!")

