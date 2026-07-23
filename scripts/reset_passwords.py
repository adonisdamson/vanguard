#!/usr/bin/env python3
"""
Reset ALL operator account passwords to temawestndc@2026!
Uses the Supabase Admin API with the service_role key.

Usage:
  export SUPABASE_SERVICE_ROLE_KEY="<key>"
  python3 scripts/reset_passwords.py
"""
import json, time, sys, os
import urllib.request
import urllib.error

SUPABASE_URL = "https://gnolfngnwyuwubqzopzl.supabase.co"
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
if not SERVICE_ROLE_KEY:
    sys.exit("ERROR: set SUPABASE_SERVICE_ROLE_KEY env var before running this script.")
NEW_PASSWORD = "temawestndc@2026!"

def supabase_get(path):
    url = f"{SUPABASE_URL}{path}"
    req = urllib.request.Request(url, headers={
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    })
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def supabase_put(path, body):
    url = f"{SUPABASE_URL}{path}"
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method="PUT", headers={
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

def list_all_users():
    """Page through all auth users (100 per page)."""
    users = []
    page = 1
    while True:
        data = supabase_get(f"/auth/v1/admin/users?page={page}&per_page=100")
        batch = data.get("users", [])
        users.extend(batch)
        print(f"  Fetched page {page}: {len(batch)} users (total so far: {len(users)})")
        if len(batch) < 100:
            break
        page += 1
    return users

def main():
    print(f"Fetching all users from {SUPABASE_URL}...")
    users = list_all_users()
    print(f"\nTotal users found: {len(users)}")

    ok = 0
    fail = 0
    for i, u in enumerate(users, 1):
        uid = u["id"]
        email = u.get("email", "")
        status, _ = supabase_put(f"/auth/v1/admin/users/{uid}", {"password": NEW_PASSWORD})
        if status == 200:
            ok += 1
            print(f"  [{i}/{len(users)}] ✓ {email}")
        else:
            fail += 1
            print(f"  [{i}/{len(users)}] ✗ {email}  (HTTP {status})")
        # small delay to avoid rate limiting
        time.sleep(0.05)

    print(f"\nDone: {ok} updated, {fail} failed.")
    if fail > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
