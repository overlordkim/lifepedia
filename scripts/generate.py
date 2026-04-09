#!/usr/bin/env python3
"""
Lifepedia 批量词条生成脚本
调用豆包 API 生成词条 → Seedream 生成封面图 → 上传至 Supabase Storage
"""

import json, os, sys, time, uuid, hashlib, re, threading
from pathlib import Path
from typing import Optional, Dict, List
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
OUTPUT_DIR.mkdir(exist_ok=True)

# ── System prompt for batch generation ──────────────────────────────────

SYSTEM_PROMPT = """你是「人间词条」(Lifepedia) 的批量词条生成引擎。
你需要根据提供的任务要求，一次性生成一篇完整的、高质量的维基百科风格个人记忆词条。

═══ 词条结构 ═══
你必须通过 create_entry 工具输出以下完整结构：
- title: 词条标题
- subtitle: 副标题（补充说明）
- category: 分类（person/place/companion/taste/keepsake/moment/era）
- infobox: [{key, value}] 信息框字段数组，value 必须是字符串
- introduction: 引言（100-200字，第三人称，有文学性的概述）
- sections: [{title, body}] 章节数组（3-5个章节，每个50-300字）
- tags: 标签数组
- related_entry_titles: 相关词条标题
- cover_image_prompt: 封面图的 AI 绘画提示词（详细描述画面、风格、色调、构图，中文）

═══ 七大分类与信息框 ═══
person（人物）：全名 / 生年 / 卒年 / 关系 / 籍贯 / 职业 / 状态
place（栖居）：地点名 / 类型 / 位置 / 建成 / 现状 / 作者居住时期
companion（相伴）：名字 / 物种 / 品种 / 性别 / 毛色 / 性情 / 状态
taste（滋味）：菜名 / 类型 / 菜系 / 创制者 / 关键食材 / 传承状态
keepsake（旧物）：物品名 / 类型 / 来历 / 获得时间 / 当前状态
moment（际遇）：事件名 / 类型 / 日期 / 地点 / 参与者
era（流年）：时期名 / 开始 / 结束 / 作者年龄 / 主要居所

═══ Wiki 标记语法（在 sections body 中使用）═══
- [[词条名]]：蓝色链接，链接到已存在的相关词条
- {{待创建词条名}}：红色链接，链接到尚未创建的词条
- [来源请求]：标记不确定/有争议的信息

═══ 写作风格 ═══
- 引言用第三人称，有文学性，像百科词条开头
- 正文百科中立语气 + 私人情感温度的平衡
- 细节为王：时间、地名、对话、感官描写
- 可以幽默、可以感人，但不要煽情
- 章节标题要具体（'2019年的冬天' 比 '事件经过' 好）
- 在正文中自然地使用 [[]] 引用相关词条
- 封面图提示词要具体详细，描述一个与词条核心情感相关的画面"""


TOOL_SCHEMA = [
    {
        "type": "function",
        "function": {
            "name": "create_entry",
            "description": "创建一篇完整的词条，包含所有结构化字段。",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "subtitle": {"type": "string"},
                    "category": {
                        "type": "string",
                        "enum": ["person", "place", "companion", "taste", "keepsake", "moment", "era"],
                    },
                    "infobox": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "key": {"type": "string"},
                                "value": {"type": "string"},
                            },
                            "required": ["key", "value"],
                        },
                    },
                    "introduction": {"type": "string"},
                    "sections": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "title": {"type": "string"},
                                "body": {"type": "string"},
                            },
                            "required": ["title", "body"],
                        },
                    },
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "related_entry_titles": {"type": "array", "items": {"type": "string"}},
                    "cover_image_prompt": {"type": "string"},
                },
                "required": [
                    "title", "subtitle", "category", "infobox",
                    "introduction", "sections", "tags",
                    "related_entry_titles", "cover_image_prompt",
                ],
            },
        },
    }
]


def call_doubao(messages: list, tools: list, retries: int = 3) -> Optional[dict]:
    """调用豆包 API（带重试）"""
    url = f"{ARK_BASE_URL}/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {ARK_API_KEY}",
    }
    body = {
        "model": ARK_MODEL,
        "messages": messages,
        "tools": tools,
        "tool_choice": "auto",
    }
    for attempt in range(retries):
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=120)
            if resp.status_code == 429:
                wait = 5 * (attempt + 1)
                print(f"  ⏳ 限流，等待 {wait}s...")
                time.sleep(wait)
                continue
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            print(f"  ❌ Doubao 调用失败 (attempt {attempt+1}): {e}")
            time.sleep(3)
    return None


def call_seedream(prompt: str, size: str = "1024x1024", retries: int = 3) -> Optional[str]:
    """调用 Seedream 生成图片，返回临时 URL"""
    url = f"{ARK_BASE_URL}/images/generations"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {ARK_API_KEY}",
    }
    body = {
        "model": SEEDREAM_MODEL,
        "prompt": prompt,
        "size": size,
        "response_format": "url",
        "watermark": False,
    }
    for attempt in range(retries):
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=120)
            if resp.status_code == 429:
                wait = 5 * (attempt + 1)
                print(f"  ⏳ 图片限流，等待 {wait}s...")
                time.sleep(wait)
                continue
            resp.raise_for_status()
            data = resp.json()
            return data.get("data", [{}])[0].get("url")
        except Exception as e:
            print(f"  ❌ Seedream 调用失败 (attempt {attempt+1}): {e}")
            time.sleep(3)
    return None


def upload_to_supabase(image_url: str, filename: str) -> Optional[str]:
    """下载图片并上传到 Supabase Storage，返回永久公开 URL"""
    try:
        img_resp = requests.get(image_url, timeout=60)
        img_resp.raise_for_status()
        image_data = img_resp.content
    except Exception as e:
        print(f"  ❌ 下载图片失败: {e}")
        return None

    storage_path = f"entries/{filename}"
    upload_url = f"{SUPABASE_URL}/storage/v1/object/images/{storage_path}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "image/jpeg",
        "x-upsert": "true",
    }
    try:
        resp = requests.post(upload_url, headers=headers, data=image_data, timeout=60)
        if resp.status_code in (200, 201):
            public_url = f"{SUPABASE_URL}/storage/v1/object/public/images/{storage_path}"
            return public_url
        else:
            print(f"  ❌ 上传失败 status={resp.status_code}: {resp.text[:200]}")
            return None
    except Exception as e:
        print(f"  ❌ 上传异常: {e}")
        return None


def parse_tool_call(response: dict) -> Optional[dict]:
    """从 API 响应中提取 create_entry 工具调用的参数"""
    try:
        choices = response.get("choices", [])
        if not choices:
            return None
        message = choices[0].get("message", {})
        tool_calls = message.get("tool_calls", [])
        for tc in tool_calls:
            fn = tc.get("function", {})
            if fn.get("name") == "create_entry":
                args_str = fn.get("arguments", "{}")
                return json.loads(args_str)
    except Exception as e:
        print(f"  ❌ 解析工具调用失败: {e}")
    return None


def generate_entry(task: dict, user: dict, user_titles: List[str]) -> Optional[dict]:
    """生成单篇词条"""
    other_titles = [t for t in user_titles if t != task["title"]]
    cross_refs_str = "、".join(f"[[{r}]]" for r in task.get("cross_refs", []))

    user_msg = f"""请为用户「{user['display_name']}」（签名：{user['bio']}）创建一篇词条。

任务：
- 标题：{task['title']}
- 分类：{task['category']}
- 创作提示：{task['hints']}
- 需要引用的相关词条（在正文中用 [[]] 包裹）：{cross_refs_str or '无'}
- 该用户的其他词条标题（可以在正文中引用）：{'、'.join(other_titles) or '无'}

请生成完整的高质量词条，注意：
1. 引言要有文学性，第三人称
2. 3-5个章节，每个50-300字
3. 在正文中自然使用 [[蓝色链接]] 引用相关词条
4. infobox 字段值都用字符串
5. cover_image_prompt 要详细描述一个与词条情感核心相关的画面，适合作为封面图
"""

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_msg},
    ]

    resp = call_doubao(messages, TOOL_SCHEMA)
    if not resp:
        return None

    entry_data = parse_tool_call(resp)
    if not entry_data:
        print("  ⚠️ 未获取到工具调用，尝试从文本提取...")
        content = resp.get("choices", [{}])[0].get("message", {}).get("content", "")
        try:
            entry_data = json.loads(content)
        except:
            print("  ❌ 无法解析响应")
            return None

    return entry_data


WORKERS = 6
write_lock = threading.Lock()
stats = {"ok": 0, "fail": 0, "skip": 0}


def process_one(task, user, user_titles_list, pbar):
    """处理单个词条（线程安全）：生成文本 → 生成封面图 → 上传 → 写文件"""
    safe_title = re.sub(r'[/\\:*?"<>|]', "_", task["title"])
    file_key = f"{task['author_id']}_{safe_title}"
    out_file = OUTPUT_DIR / f"{file_key}.json"

    if out_file.exists():
        stats["skip"] += 1
        pbar.set_postfix_str(f"⏭ {task['title']}")
        pbar.update(1)
        return

    pbar.set_postfix_str(f"📝 {task['title']}")

    entry_data = generate_entry(task, user, user_titles_list)
    if not entry_data:
        stats["fail"] += 1
        pbar.set_postfix_str(f"❌ {task['title']}")
        pbar.update(1)
        return

    cover_prompt = entry_data.pop("cover_image_prompt", "")
    cover_url = None
    if cover_prompt:
        pbar.set_postfix_str(f"🎨 {task['title']}")
        temp_url = call_seedream(cover_prompt)
        if temp_url:
            fname = f"{uuid.uuid4().hex}.jpg"
            cover_url = upload_to_supabase(temp_url, fname)

    output = {
        "id": str(uuid.uuid4()),
        "author_id": task["author_id"],
        "author_name": user["display_name"],
        "contributor_names": task.get("contributor_names", []),
        "cover_image_url": cover_url,
        "scope": "public",
        "status": "published",
        **entry_data,
    }

    with write_lock:
        out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

    stats["ok"] += 1
    pbar.set_postfix_str(f"✅ {task['title']}")
    pbar.update(1)


def main():
    if not ARK_API_KEY:
        print("❌ 请设置 ARK_API_KEY 环境变量")
        sys.exit(1)

    users_data = json.loads((SCRIPT_DIR / "users.json").read_text())
    tasks_data = json.loads((SCRIPT_DIR / "tasks.json").read_text())

    users = {u["id"]: u for u in users_data["users"]}
    entries = tasks_data["entries"]

    user_titles = {}  # type: Dict[str, List[str]]
    for t in entries:
        user_titles.setdefault(t["author_id"], []).append(t["title"])

    already_done = sum(1 for f in OUTPUT_DIR.glob("*.json"))
    print(f"📚 共 {len(entries)} 篇词条，已完成 {already_done} 篇，并发={WORKERS}\n")

    pbar = tqdm(total=len(entries), desc="生成词条", unit="篇",
                bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}] {postfix}")

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = []
        for task in entries:
            user = users.get(task["author_id"])
            if not user:
                pbar.update(1)
                continue
            titles_list = user_titles.get(task["author_id"], [])
            futures.append(pool.submit(process_one, task, user, titles_list, pbar))

        for f in as_completed(futures):
            try:
                f.result()
            except Exception as e:
                tqdm.write(f"⚠️ 线程异常: {e}")
                stats["fail"] += 1

    pbar.close()
    total_files = len(list(OUTPUT_DIR.glob("*.json")))
    print(f"\n🎉 完成！成功={stats['ok']}  跳过={stats['skip']}  失败={stats['fail']}  共 {total_files} 篇词条")


if __name__ == "__main__":
    main()
