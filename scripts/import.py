#!/usr/bin/env python3
"""
Lifepedia 数据导入脚本
将 users.json + output/*.json 导入 Supabase（users / entries / follows 表）
"""

import json, os, sys, hashlib, time
from pathlib import Path
from datetime import datetime, timezone, timedelta

import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "output"

HEADERS = {
    "apikey": SUPABASE_ANON_KEY,
    "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation,resolution=merge-duplicates",
}


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def import_users():
    """导入用户到 users 表"""
    data = json.loads((SCRIPT_DIR / "users.json").read_text())
    users = data["users"]

    rows = []
    for u in users:
        rows.append({
            "id": u["id"],
            "username": u["username"],
            "password_hash": sha256(u["password"]),
            "display_name": u["display_name"],
            "bio": u["bio"],
            "avatar_seed": u["avatar_seed"],
        })

    url = f"{SUPABASE_URL}/rest/v1/users"
    resp = requests.post(url, headers=HEADERS, json=rows, timeout=30)

    if resp.status_code in (200, 201):
        print(f"✅ 导入 {len(rows)} 个用户")
    else:
        print(f"❌ 用户导入失败 ({resp.status_code}): {resp.text[:300]}")


def import_follows():
    """导入关注关系到 follows 表"""
    data = json.loads((SCRIPT_DIR / "users.json").read_text())
    follows = data["follows"]

    rows = [{"follower_id": f["follower_id"], "following_id": f["following_id"]} for f in follows]

    url = f"{SUPABASE_URL}/rest/v1/follows"
    resp = requests.post(url, headers=HEADERS, json=rows, timeout=30)

    if resp.status_code in (200, 201):
        print(f"✅ 导入 {len(rows)} 条关注关系")
    else:
        print(f"❌ 关注关系导入失败 ({resp.status_code}): {resp.text[:300]}")


def import_entries():
    """导入词条到 entries 表"""
    files = sorted(OUTPUT_DIR.glob("*.json"))
    if not files:
        print("⚠️ output/ 目录为空，请先运行 generate.py")
        return

    base_time = datetime(2025, 1, 15, tzinfo=timezone.utc)
    success = 0

    for i, f in enumerate(files):
        raw = json.loads(f.read_text())

        created = base_time + timedelta(hours=i * 6, minutes=i * 13 % 60)
        updated = created + timedelta(hours=2)

        sections = []
        for s in raw.get("sections", []):
            sec = {"title": s.get("title", ""), "body": s.get("body", "")}
            if s.get("image_refs"):
                sec["image_refs"] = s["image_refs"]
            sections.append(sec)

        row = {
            "id": raw.get("id"),
            "title": raw.get("title", ""),
            "subtitle": raw.get("subtitle"),
            "category": raw.get("category", "person"),
            "scope": raw.get("scope", "public"),
            "infobox": raw.get("infobox", []),
            "introduction": raw.get("introduction"),
            "sections": sections,
            "tags": raw.get("tags", []),
            "cover_image_url": raw.get("cover_image_url"),
            "author_name": raw.get("author_name", ""),
            "author_id": raw.get("author_id", ""),
            "contributor_names": raw.get("contributor_names", []),
            "like_count": (i * 7 + 3) % 50,
            "collect_count": (i * 3 + 1) % 20,
            "comment_count": (i * 2) % 10,
            "view_count": (i * 17 + 10) % 200 + 20,
            "status": "published",
            "created_at": created.isoformat(),
            "updated_at": updated.isoformat(),
            "published_at": updated.isoformat(),
        }

        url = f"{SUPABASE_URL}/rest/v1/entries"
        resp = requests.post(url, headers=HEADERS, json=[row], timeout=30)

        if resp.status_code in (200, 201):
            success += 1
            print(f"  [{i+1}/{len(files)}] ✅ {raw.get('title')}")
        else:
            print(f"  [{i+1}/{len(files)}] ❌ {raw.get('title')}: {resp.status_code} {resp.text[:200]}")

        time.sleep(0.2)

    print(f"\n✅ 成功导入 {success}/{len(files)} 篇词条")


def main():
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        print("❌ 请设置 SUPABASE_URL 和 SUPABASE_ANON_KEY")
        sys.exit(1)

    print("═══ Step 1: 导入用户 ═══")
    import_users()

    print("\n═══ Step 2: 导入关注关系 ═══")
    import_follows()

    print("\n═══ Step 3: 导入词条 ═══")
    import_entries()

    print("\n🎉 全部完成！")


if __name__ == "__main__":
    main()
