#!/usr/bin/env python3
"""
One-time bulk import of Tema West constituency executives as app operators.

- Parses REGISTER.docx (position, name, phone, branch).
- Normalizes phones (O->0, +233, validates 0XXXXXXXXX).
- Maps position -> role:
    CHAIRMAN, SECRETARY                      -> higher_authority (Coordinator)
    ORGANISER, TREASURER, COMMUNICATION      -> manager          (Administrator)
    YOUTH ORG, WOMEN ORG, OTHER MEMBER       -> personnel
- Skips + reports rows with missing / invalid / duplicate phones.
- Creates a Supabase auth user (synthetic email {phone}@temawest.local, shared
  default password, email pre-confirmed) and upserts the app_users row with
  role / party_position / branch / phone / must_change_password = true.

Idempotent: existing accounts (by email) are updated, not duplicated.

Usage:
  SUPABASE_URL=... SERVICE_ROLE_KEY=... python3 scripts/import_operators.py --dry-run
  SUPABASE_URL=... SERVICE_ROLE_KEY=... python3 scripts/import_operators.py --apply
"""
import os, re, sys, json, time, urllib.request, urllib.error

DOCX = os.environ.get("REGISTER_DOCX", "/home/zero/Downloads/REGISTER.docx")
DOMAIN = "temawest.local"
DEFAULT_PASSWORD = "temawestndc2026!"
URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SERVICE_ROLE_KEY"]

ROLE_MAP = {
    "CHAIRMAN": "higher_authority", "SECRETARY": "higher_authority",
    "ORGANISER": "manager", "TREASURER": "manager", "COMMUNICATION": "manager",
    "YOUTH ORG": "personnel", "WOMEN ORG": "personnel", "OTHER MEMBER": "personnel",
}

def norm_pos(p): return p.upper().replace(".", "").strip()

def normalize_phone(raw):
    s = (raw or "").strip().replace("O", "0").replace("o", "0")
    plus = s.startswith("+")
    s = re.sub(r"[^0-9]", "", s)
    if plus and s.startswith("233"): s = "0" + s[3:]
    elif s.startswith("233") and len(s) == 12: s = "0" + s[3:]
    return s if re.fullmatch(r"0\d{9}", s) else None

def parse_docx():
    import docx
    from docx.oxml.ns import qn
    import docx.table
    d = docx.Document(DOCX)
    rows = []
    for child in d.element.body.iterchildren():
        if child.tag == qn("w:tbl"):
            tbl = docx.table.Table(child, d); last_branch = ""
            for r in tbl.rows:
                c = [x.text.strip() for x in r.cells]
                if len(c) >= 4 and c[1] and c[1].upper() != "POSITION" and c[2] and c[2].upper() != "NAME":
                    branch = c[4] if len(c) > 4 and c[4] else last_branch
                    if len(c) > 4 and c[4]: last_branch = c[4]
                    rows.append({"position": c[1], "name": c[2], "phone": c[3], "branch": branch})
    return rows

def api(method, path, body=None, base=None, extra_headers=None):
    b = base or URL
    headers = {"apikey": KEY, "Authorization": f"Bearer {KEY}",
               "Content-Type": "application/json", "User-Agent": "temawest-import/1.0"}
    if extra_headers: headers.update(extra_headers)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(b + path, data=data, headers=headers, method=method)
    try:
        r = urllib.request.urlopen(req)
        raw = r.read().decode()
        return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw

def build_plan():
    rows = parse_docx()
    valid, skipped, seen = [], [], {}
    for r in rows:
        pos = norm_pos(r["position"]); role = ROLE_MAP.get(pos)
        phone = normalize_phone(r["phone"])
        if role is None:
            skipped.append({**r, "reason": f"unknown position '{r['position']}'"}); continue
        if not phone:
            skipped.append({**r, "reason": "missing/invalid phone"}); continue
        if phone in seen:
            skipped.append({**r, "reason": f"duplicate phone (first: {seen[phone]})"}); continue
        seen[phone] = r["name"]
        branch = re.sub(r"\s+", " ", r["branch"] or "").strip()
        valid.append({"name": re.sub(r"\s+", " ", r["name"]).strip(), "phone": phone,
                      "email": f"{phone}@{DOMAIN}", "role": role,
                      "position": pos.title(), "branch": branch})
    return valid, skipped

def fetch_existing_emails():
    """email -> auth user id, paginated."""
    m = {}; page = 1
    while True:
        st, data = api("GET", f"/auth/v1/admin/users?page={page}&per_page=200", base=URL)
        users = (data or {}).get("users", []) if isinstance(data, dict) else []
        if not users: break
        for u in users:
            if u.get("email"): m[u["email"].lower()] = u["id"]
        if len(users) < 200: break
        page += 1
    return m

def upsert_app_user(uid, p):
    body = {"id": uid, "full_name": p["name"], "email": p["email"], "phone": p["phone"],
            "role": p["role"], "party_position": p["position"], "branch": p["branch"],
            "is_active": True, "must_change_password": True}
    st, _ = api("POST", "/rest/v1/app_users", body, base=URL,
                extra_headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
    return st

def main():
    mode = "--apply" if "--apply" in sys.argv else "--dry-run"
    valid, skipped = build_plan()
    from collections import Counter
    roles = Counter(p["role"] for p in valid)
    print(f"== PLAN ==  valid={len(valid)}  skipped={len(skipped)}")
    print("roles:", dict(roles))
    print(f"skipped ({len(skipped)}):")
    for s in skipped:
        print(f"   - {s['position']:14} {s['name']:26} phone='{s['phone']}'  [{s['reason']}]")
    if mode == "--dry-run":
        print("\nDRY RUN — nothing created. Sample of first 3 to be created:")
        for p in valid[:3]: print("   ", p)
        return

    print("\n== APPLYING ==")
    existing = fetch_existing_emails()
    print(f"existing auth users: {len(existing)}")
    created = updated = failed = 0
    for i, p in enumerate(valid, 1):
        uid = existing.get(p["email"].lower())
        if not uid:
            st, data = api("POST", "/auth/v1/admin/users",
                           {"email": p["email"], "password": DEFAULT_PASSWORD,
                            "email_confirm": True,
                            "user_metadata": {"full_name": p["name"], "signup_source": "bulk_import"}},
                           base=URL)
            if st in (200, 201) and isinstance(data, dict) and data.get("id"):
                uid = data["id"]; created += 1
            else:
                failed += 1; print(f"   ! create failed {p['email']}: {st} {str(data)[:120]}"); continue
        else:
            updated += 1
        st = upsert_app_user(uid, p)
        if st not in (200, 201, 204):
            print(f"   ! app_users upsert {p['email']}: {st}")
        if i % 50 == 0: print(f"   ...{i}/{len(valid)}")
        time.sleep(0.02)
    print(f"\nDONE. created={created} updated={updated} failed={failed}")

if __name__ == "__main__":
    main()
