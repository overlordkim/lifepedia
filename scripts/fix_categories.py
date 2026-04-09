#!/usr/bin/env python3
"""
修复 category 字段中的脏数据（多余空白、制表符、引号）
1. 修复本地 output/*.json 文件
2. 修复 Supabase 数据库中的对应记录
"""

import json, os, re, sys
from pathlib import Path
import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
REST_URL = f"{SUPABASE_URL}/rest/v1"

VALID_CATEGORIES = {"person", "place", "companion", "taste", "keepsake", "moment", "era"}
OUTPUT_DIR = Path(__file__).resolve().parent / "output"

HEADERS = {
    "apikey": SUPABASE_ANON_KEY,
    "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}


def clean_category(raw: str) -> str:
    """从脏字符串中提取有效的 category 值"""
    cleaned = raw.strip().strip('"').strip("'").strip()
    if cleaned in VALID_CATEGORIES:
        return cleaned
    for cat in VALID_CATEGORIES:
        if cat in raw:
            return cat
    return raw


def fix_local_files():
    """修复本地 JSON 文件"""
    fixed = 0
    for f in sorted(OUTPUT_DIR.glob("*.json")):
        data = json.loads(f.read_text())
        cat = data.get("category", "")
        cleaned = clean_category(cat)
        if cleaned != cat:
            print(f"  📝 {f.name}: {repr(cat[:50])} → {cleaned}")
            data["category"] = cleaned
            f.write_text(json.dumps(data, ensure_ascii=False, indent=2))
            fixed += 1
    print(f"\n本地文件修复完成: {fixed} 个文件\n")
    return fixed


def fix_supabase():
    """修复 Supabase 数据库"""
    print("正在查询 Supabase 所有词条...")
    resp = requests.get(
        f"{REST_URL}/entries?select=id,category&limit=500",
        headers={
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        },
    )
    resp.raise_for_status()
    entries = resp.json()
    print(f"共 {len(entries)} 条记录\n")

    fixed = 0
    for entry in entries:
        cat = entry["category"]
        cleaned = clean_category(cat)
        if cleaned != cat:
            print(f"  🔧 {entry['id'][:8]}... : {repr(cat[:50])} → {cleaned}")
            patch_resp = requests.patch(
                f"{REST_URL}/entries?id=eq.{entry['id']}",
                headers=HEADERS,
                json={"category": cleaned},
            )
            if patch_resp.status_code < 300:
                fixed += 1
                print(f"     ✅ 已修复")
            else:
                print(f"     ❌ 失败: {patch_resp.status_code} {patch_resp.text[:100]}")

    print(f"\nSupabase 修复完成: {fixed} 条记录")
    return fixed


if __name__ == "__main__":
    print("=" * 50)
    print("修复 category 脏数据")
    print("=" * 50)

    print("\n── 第一步：修复本地 JSON 文件 ──\n")
    fix_local_files()

    print("── 第二步：修复 Supabase 数据库 ──\n")
    fix_supabase()

    print("\n✅ 全部完成！")
