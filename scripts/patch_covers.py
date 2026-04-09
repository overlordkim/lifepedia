#!/usr/bin/env python3
"""
补图脚本：读取已生成的词条 JSON → 豆包生成封面图提示词+尺寸 → Seedream 生图 → 上传 → 回写 JSON
"""

import json, os, sys, time, uuid, re, threading
from pathlib import Path
from typing import Optional, List
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from dotenv import load_dotenv
from tqdm import tqdm

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

ARK_API_KEY = os.getenv("ARK_API_KEY")
ARK_BASE_URL = os.getenv("ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3")
ARK_MODEL = os.getenv("ARK_MODEL", "doubao-seed-2-0-lite-260215")
SEEDREAM_MODEL = "doubao-seedream-5-0-260128"
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "output"
WORKERS = 5

COVER_PROMPT_SYSTEM = """你是一位摄影师。你会看到一篇个人记忆百科词条，需要为它设计一张封面照片。

要求：
- 真实照片风格，像用相机实拍的
- 只描述画面内容本身，不要加任何滤镜、色调、风格修饰词
- 不要提"阳光""明媚""温暖""金色光线"等词汇
- 不要出现清晰的人脸，可以用背影、手部、侧影、物品代替
- 构图自然，不要刻意
- 禁止：插画/水彩/油画/卡通/3D/海报/文字/UI

请通过 design_cover 工具输出：
1. prompt：简洁的场景描述（中文，40-80字），只写画面里有什么、在哪里、什么角度拍的。不要写风格和色调。

2. size：根据内容选择尺寸：
   - "2560x1440"：横版（风景/场所/旅行）
   - "1920x1920"：正方形（食物/物件/宠物）
   - "2304x1728"：横版 4:3（室内/生活场景）
   - "1728x2304"：竖版 3:4（人物/建筑/小巷）
   灵活选。"""

INS_STYLE_SUFFIX = "，真实摄影，高画质"

COVER_TOOL = [
    {
        "type": "function",
        "function": {
            "name": "design_cover",
            "description": "为词条设计封面图",
            "parameters": {
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "Seedream 绘画提示词（中文，80-150字，详细描述画面）"
                    },
                    "size": {
                        "type": "string",
                        "description": "图片尺寸",
                        "enum": ["2560x1440", "1920x1920", "2304x1728", "1728x2304"]
                    }
                },
                "required": ["prompt", "size"]
            }
        }
    }
]

write_lock = threading.Lock()
stats = {"ok": 0, "fail": 0, "skip": 0}


def call_doubao(messages, tools, retries=3):
    url = f"{ARK_BASE_URL}/chat/completions"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {ARK_API_KEY}"}
    body = {"model": ARK_MODEL, "messages": messages, "tools": tools, "tool_choice": "auto"}
    for attempt in range(retries):
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=90)
            if resp.status_code == 429:
                time.sleep(5 * (attempt + 1))
                continue
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            if attempt == retries - 1:
                tqdm.write(f"  Doubao 失败: {e}")
            time.sleep(3)
    return None


def call_seedream(prompt, size="2K", retries=3):
    url = f"{ARK_BASE_URL}/images/generations"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {ARK_API_KEY}"}
    body = {"model": SEEDREAM_MODEL, "prompt": prompt, "size": size, "response_format": "url", "watermark": False}
    for attempt in range(retries):
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=120)
            if resp.status_code == 429:
                time.sleep(5 * (attempt + 1))
                continue
            if resp.status_code == 400:
                err = resp.json().get("error", {}).get("message", "")
                tqdm.write(f"  Seedream 400: {err[:100]}")
                if "size" in err.lower():
                    body["size"] = "2K"
                    continue
                return None
            resp.raise_for_status()
            data = resp.json()
            return data.get("data", [{}])[0].get("url")
        except Exception as e:
            if attempt == retries - 1:
                tqdm.write(f"  Seedream 失败: {e}")
            time.sleep(3)
    return None


def upload_to_supabase(image_url, filename):
    try:
        img_resp = requests.get(image_url, timeout=60)
        img_resp.raise_for_status()
    except Exception as e:
        tqdm.write(f"  下载失败: {e}")
        return None

    path = f"entries/{filename}"
    upload_url = f"{SUPABASE_URL}/storage/v1/object/images/{path}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "image/jpeg",
        "x-upsert": "true",
    }
    try:
        resp = requests.post(upload_url, headers=headers, data=img_resp.content, timeout=60)
        if resp.status_code in (200, 201):
            return f"{SUPABASE_URL}/storage/v1/object/public/images/{path}"
        tqdm.write(f"  上传失败 {resp.status_code}: {resp.text[:100]}")
    except Exception as e:
        tqdm.write(f"  上传异常: {e}")
    return None


def summarize_entry(data):
    """提取词条摘要给豆包看"""
    parts = [f"标题：{data.get('title', '')}"]
    if data.get("subtitle"):
        parts.append(f"副标题：{data['subtitle']}")
    parts.append(f"分类：{data.get('category', '')}")
    if data.get("introduction"):
        parts.append(f"引言：{data['introduction'][:200]}")
    sections = data.get("sections", [])
    if sections:
        sec_titles = "、".join(s.get("title", "") for s in sections[:5])
        parts.append(f"章节：{sec_titles}")
        first_body = sections[0].get("body", "")[:150]
        parts.append(f"首段内容：{first_body}")
    return "\n".join(parts)


def process_one(filepath, pbar):
    data = json.loads(filepath.read_text())

    if data.get("cover_image_url"):
        stats["skip"] += 1
        pbar.update(1)
        return

    title = data.get("title", filepath.stem)
    pbar.set_postfix_str(f"📝 {title}")

    summary = summarize_entry(data)
    messages = [
        {"role": "system", "content": COVER_PROMPT_SYSTEM},
        {"role": "user", "content": f"请为这篇词条设计封面图：\n\n{summary}"},
    ]

    resp = call_doubao(messages, COVER_TOOL)
    if not resp:
        stats["fail"] += 1
        pbar.set_postfix_str(f"❌ {title}")
        pbar.update(1)
        return

    design = None
    try:
        tc = resp["choices"][0]["message"]["tool_calls"][0]
        design = json.loads(tc["function"]["arguments"])
    except Exception:
        stats["fail"] += 1
        pbar.set_postfix_str(f"❌ {title}")
        pbar.update(1)
        return

    prompt = design.get("prompt", "")
    size = design.get("size", "2K")
    if not prompt:
        stats["fail"] += 1
        pbar.update(1)
        return

    full_prompt = prompt.rstrip("，。") + INS_STYLE_SUFFIX
    pbar.set_postfix_str(f"🎨 {title} ({size})")
    temp_url = call_seedream(full_prompt, size)
    if not temp_url:
        stats["fail"] += 1
        pbar.set_postfix_str(f"❌ {title}")
        pbar.update(1)
        return

    fname = f"{uuid.uuid4().hex}.jpg"
    pbar.set_postfix_str(f"📤 {title}")
    public_url = upload_to_supabase(temp_url, fname)
    if not public_url:
        stats["fail"] += 1
        pbar.update(1)
        return

    data["cover_image_url"] = public_url
    with write_lock:
        filepath.write_text(json.dumps(data, ensure_ascii=False, indent=2))

    stats["ok"] += 1
    pbar.set_postfix_str(f"✅ {title}")
    pbar.update(1)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0, help="只处理前 N 篇（0=全部）")
    parser.add_argument("--workers", type=int, default=WORKERS)
    args = parser.parse_args()

    if not ARK_API_KEY:
        print("❌ 请设置 ARK_API_KEY")
        sys.exit(1)

    files = sorted(OUTPUT_DIR.glob("*.json"))
    need_cover = [f for f in files if not json.loads(f.read_text()).get("cover_image_url")]
    if args.limit > 0:
        need_cover = need_cover[:args.limit]
    workers = args.workers
    total = len(need_cover) + (len(files) - len([f for f in files if not json.loads(f.read_text()).get("cover_image_url")]))
    if args.limit > 0:
        total = args.limit
    print(f"📸 {len(need_cover)} 篇待生成封面，并发={workers}\n")

    pbar = tqdm(total=len(need_cover), desc="补封面图", unit="篇",
                bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}] {postfix}")

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(process_one, f, pbar) for f in need_cover]
        for f in as_completed(futures):
            try:
                f.result()
            except Exception as e:
                tqdm.write(f"⚠️ 线程异常: {e}")
                stats["fail"] += 1

    pbar.close()
    print(f"\n🎉 完成！成功={stats['ok']}  失败={stats['fail']}  跳过={stats['skip']}")


if __name__ == "__main__":
    main()
