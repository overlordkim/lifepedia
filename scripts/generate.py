#!/usr/bin/env python3
"""
Lifepedia 批量词条生成脚本 v2
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

VALID_CATEGORIES = {"person", "place", "companion", "taste", "keepsake", "moment", "era"}

# ── 范文 JSON ──────────────────────────────────────
MODEL_ENTRY_JSON = r'''
{
  "title": "红烧肉（张薇家庭版）",
  "subtitle": "一道已失传的家庭菜，约四十年间从未缺席每一次团聚",
  "category": "taste",
  "infobox": [
    { "key": "菜名", "value": "红烧肉（张薇家庭版）" },
    { "key": "别称", "value": "外婆的红烧肉" },
    { "key": "类型", "value": "家常菜" },
    { "key": "菜系", "value": "湘菜（家庭改良）" },
    { "key": "创制者", "value": "[[张薇]]（1941—2019）" },
    { "key": "关键食材", "value": "五花肉、冰糖、生抽、老抽、八角、绍酒" },
    { "key": "传承状态", "value": "失传" }
  ],
  "introduction": "红烧肉（张薇家庭版）是一道家庭菜，由[[张薇]]（1941—2019）于不晚于1970年代创制，至2019年张薇去世为止，一直为张氏家族成员春节、中秋、生日等重大场合的定席菜品之一。该配方据信源自其母亲{{刘春梅}}（1918—1976）口传，未有任何形式的书面记录。张薇去世后，其外孙女曾七次尝试复原该配方，均未成功。本条目编纂者认为，该配方应被视为已失传。",
  "sections": [
    {
      "title": "创制与来源",
      "body": "关于该配方的起源，目前存在两种说法。其一为「{{刘春梅}}传承说」，来自[[张薇]]本人，她曾于多次家庭聚餐时向外孙女提及「这是你太外婆教我的」。但由于{{刘春梅}}于1976年即已去世，该说法无法被独立验证[来源请求]。刘春梅一生未离开过湖南长沙，其制作的红烧肉风格应属湘菜传统家庭做法，但与市面上常见的湘菜馆红烧肉存在显著差异，因此该配方可能包含刘春梅本人的独创改良。\n\n其二为「自创说」。[[张薇]]的长女{{周丽}}曾于2023年的一次家庭聚会中提出异议，认为该配方大部分细节实际为张薇本人在1970年代初独立摸索形成，「太奶奶的版本根本不是这个味道」。但张薇本人从未在生前对此做出说明。\n\n由于两位关键当事人均已去世，该争议无法得到解决。本条目编纂者倾向于认为，该配方是代际传承与个人改良的混合产物，其确切比例已不可考。"
    },
    {
      "title": "四十年间的餐桌",
      "body": "该菜品的活跃期为约1970年代至2018年，跨越约四十余年。在这段时间里，它在张氏家族内部形成了稳定的出现模式——春节必做，通常作为年夜饭的主菜之一；中秋大部分年份会做；[[张薇]]本人生日（农历三月初七）必做；家族有人从外地归来时必做。\n\n根据条目编纂者的回忆，她的童年与该菜品的记忆基本重合。她能记得的最早一次吃这道菜，是在[[1996年的春节]]，当时她四岁。最后一次是2018年春节，当时[[张薇]]已身患疾病，做完这顿饭后即长期卧床，次年去世。"
    },
    {
      "title": "外观、味道与香气",
      "body": "以下描述基于条目编纂者的记忆及现存的三张照片（均为2015年以后拍摄）。\n\n肉块较大，约3×3×2厘米，远大于一般湘菜馆红烧肉的切法。色泽偏深，接近酱色，但不至于发黑。收汁较干，盘底基本无汤汁。肉块表面有轻微的焦糖光泽。\n\n咸甜平衡偏甜，但甜味不来自糖而来自冰糖，因此甜得较为干净，不黏腻。肥瘦相间的部分入口即化，但瘦肉部分仍保持一定的嚼劲，不柴——这一点被条目编纂者认为是该菜品最难复原的特征。\n\n有明显的八角香，但八角本身不会被端上桌（[[张薇]]习惯于起锅前将八角捞出）。此外有一种无法命名的、类似于柴火的淡淡烟熏味，条目编纂者怀疑这与张薇使用的铁锅和煤气灶的火候有关，但从未得到证实[来源请求]。"
    },
    {
      "title": "制作过程与永久缺失的细节",
      "body": "根据条目编纂者的回忆和2015年拍摄的一段47秒视频，该菜品的制作过程大致为：选用五花肉（[[张薇]]习惯在{{岳麓山菜市场}}购买），切成大块，冷水下锅焯水加少量绍酒，另起锅用冰糖炒糖色（此步骤在视频中可见，但张薇的具体手法过快，视频无法完整捕捉），加入五花肉翻炒上色，加入生抽、老抽、八角、葱姜，加水至没过肉块，大火煮沸后转小火慢炖约90分钟，最后大火收汁。\n\n然而以下细节在张薇生前均未被明确记录，现已无法获得：冰糖与生抽、老抽的具体比例（张薇从不称量，凭手感放入）；炒糖色的具体火候判断标准（她的回答始终是「看颜色」）；是否使用其他隐藏调料（条目编纂者怀疑张薇在某些步骤中加入了她从未提及的东西，这一怀疑基于复原尝试的持续失败）；慢炖阶段是否加盖及加盖时长；收汁阶段的火候与时间。"
    },
    {
      "title": "七次失败的复原",
      "body": "在[[张薇]]一生的厨房生涯中，该配方从未被任何形式地书面化。2014年，条目编纂者曾尝试让张薇口述配方并由自己记录，但张薇的回答均为「这个东西写不出来的」，或「你多做几次就会了」。最终记录的笔记仅有：「五花肉。冰糖。酱油。八角。慢炖。看颜色。尝味道。差不多了就好。」\n\n截至2024年3月，条目编纂者共进行了七次有记录的复原尝试，全部失败。2019年4月第一次尝试，肉质偏柴，糖色过深，味道完全不对。此后分别于2019年10月（甜味过重）、2020年2月（参考菜谱书，按标准做法，但「根本不是那个味道」）、2020年8月（请教母亲{{周丽}}，按母亲的版本做，依然不对）、2021年春节（第一次在[[青云街17号]]的原厨房尝试，该建筑于同年拆除，失败）、2023年1月（严格按2015年视频中的动作复原，失败）、2024年3月（最近一次，收汁阶段调整，肉质有所改善，但仍然不对）。条目编纂者认为，每一次尝试的失败，都让该配方在记忆中的轮廓变得更加清晰也更加遥远。"
    },
    {
      "title": "关于「不对」的定义",
      "body": "值得说明的是，上述所有「失败」均为条目编纂者主观判断。从客观烹饪角度，这七次尝试做出的红烧肉均为合格的家常菜，味道并无明显问题。「不对」指的是它们没有复原出记忆中的味道。\n\n这是否构成真正意义上的「失传」，取决于如何定义「该配方」。如果「该配方」指的是一组食材和步骤，那么它并未失传——它大致是已知的。如果「该配方」指的是在[[张薇]]的厨房里、用张薇的手、在张薇在场的情况下做出的那个味道，那么它已于2019年张薇去世之时永久失传。本条目编纂者采用后一种定义。"
    },
    {
      "title": "文化与情感地位",
      "body": "在张氏家族中，该菜品的地位远超一道普通家常菜，这与它长达四十余年的稳定出现、与[[张薇]]本人的紧密绑定、以及张薇去世后所有复原尝试的失败有关。\n\n条目编纂者在2019年参加[[张薇]]葬礼时，曾在悼词中提及该菜品：「我记得外婆的所有东西里，最清楚的就是她的红烧肉。我不知道这是不是太肤浅了——一个人去世之后，你首先想起的竟然是一道菜。但我后来想，也许这不是肤浅。也许是因为那道菜里，有她做菜时的专注、有她不肯教给我们的骄傲、有她凭手感调整一切的那种从容、有她认为'这个东西写不出来'的那种自信。这些东西都在那道菜里。她不在了，那些东西也就不在了。」\n\n条目编纂者认为，该菜品应被理解为一种无法被文字化的隐性知识的载体，其消失应被视为一次小规模的认知遗产灭绝事件。"
    }
  ],
  "tags": ["滋味", "失味", "湘菜", "家族记忆", "无法被书面化的事物"],
  "related_entry_titles": ["张薇", "青云街17号", "刘春梅", "1998年的除夕", "周丽", "岳麓山菜市场"],
  "cover_image_prompt": "一只黑色铸铁锅中的红烧肉，酱色油亮，冰糖焦糖光泽，八角点缀其间。背景是模糊的老式厨房，煤气灶上方蒸汽缭绕。暖色调，胶片质感，略带怀旧感的静物摄影风格。"
}
'''.strip()

# ── System prompt ──────────────────────────────────────

SYSTEM_PROMPT = f"""你是「人间词条」(Lifepedia) 的批量词条生成引擎。
你需要根据提供的任务要求，一次性生成一篇完整的、高质量的维基百科风格个人记忆词条。

═══ 词条结构 ═══
你必须通过 create_entry 工具输出以下完整结构：
- title: 词条标题
- subtitle: 副标题（一句话概括，有文学性，15-30字）
- category: 分类，必须是以下纯英文之一：person / place / companion / taste / keepsake / moment / era
  ⚠️ category 必须是纯净的英文单词，不能有任何空格、换行、引号、制表符等多余字符
- infobox: [{{key, value}}] 信息框字段数组，value 必须是字符串，value 中可用 [[]] 和 {{{{}}}} 标记
- introduction: 引言（150-300字，第三人称，有文学性的概述，流畅的叙述段落）
- sections: [{{title, body}}] 章节数组（5-7个章节，每个100-400字）
- tags: 标签数组（4-6个，简洁有力）
- related_entry_titles: 相关词条标题（3-6个）
- cover_image_prompt: 封面图的 AI 绘画提示词（详细描述画面、风格、色调、构图，中文，100字左右）

═══ 七大分类与信息框 ═══
person（人物）：全名 / 生年 / 卒年 / 关系 / 籍贯 / 职业 / 状态
place（栖居）：地点名 / 类型 / 位置 / 建成 / 现状 / 作者居住时期
companion（相伴）：名字 / 物种 / 品种 / 性别 / 毛色 / 性情 / 状态
taste（滋味）：菜名 / 类型 / 菜系 / 创制者 / 关键食材 / 传承状态
keepsake（旧物）：物品名 / 类型 / 来历 / 获得时间 / 当前状态
moment（际遇）：事件名 / 类型 / 日期 / 地点 / 参与者
era（流年）：时期名 / 开始 / 结束 / 作者年龄 / 主要居所

═══ Wiki 标记语法 ═══
在 introduction 和 sections 的 body 中使用以下三种标记，除此之外不支持任何其他格式：
- [[词条名]]：蓝色链接，链接到已存在或同一用户名下的相关词条
- {{{{待创建词条名}}}}：红色链接，链接到尚未创建但值得创建的词条
- [来源请求]：标记不确定/有争议/无法考证的信息

⚠️ 绝对不要使用以下格式（App 不支持，会被当作纯文本原样显示）：
- **粗体** 或 *斜体*
- Markdown 标题（## / ###）
- Markdown 列表（- 或 1.）
- Markdown 表格（| | |）
- Markdown 引用（> ）
- HTML 标签（<div> <sup> 等）
- Markdown 链接（[text](url)）

═══ 写作风格（最重要）═══
1. 引言用第三人称，有文学性，像一篇好的百科词条开头。不要用「本词条」「本条目」等元叙述。
2. 正文要百科中立语气与私人情感温度的精妙平衡——不是冷冰冰的记录，也不是煽情的散文。
3. 细节为王：具体的时间、具体的地名、具体的对话、具体的感官描写（气味、温度、声音、触感）。
4. 章节标题要具体且有画面感（「2019年的冬天」比「事件经过」好，「炒糖色的手法」比「制作方法」好）。
5. 在正文中自然地使用 [[]] 和 {{{{}}}} 引用相关词条，让词条之间形成网络。
6. 每个章节用 \\n\\n 分段（两个换行符），写出有呼吸感的段落。
7. 对话和直接引语用中文「」括起来，不要用""引号。
8. 可以幽默、可以感人，但绝不煽情。用克制的方式写出打动人的东西。
9. 尤其注意：每篇词条至少 800 字（introduction + 所有 sections body 加起来），短了会显得敷衍。
10. 一些信息标记「无从考证」「已不可查」「据本人回忆」比直接编造更好。

═══ 范文 ═══
以下是一篇完美的范文，请仔细学习它的结构、语气、细节密度和 wiki 标记用法：

{MODEL_ENTRY_JSON}

请严格按此水准和格式输出。"""


TOOL_SCHEMA = [
    {
        "type": "function",
        "function": {
            "name": "create_entry",
            "description": "创建一篇完整的词条，包含所有结构化字段。",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "词条标题"},
                    "subtitle": {"type": "string", "description": "副标题，一句话概括，15-30字"},
                    "category": {
                        "type": "string",
                        "enum": ["person", "place", "companion", "taste", "keepsake", "moment", "era"],
                        "description": "分类，纯英文单词",
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
                    "introduction": {"type": "string", "description": "引言，150-300字，第三人称"},
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
                        "description": "5-7个章节，每个100-400字",
                    },
                    "tags": {"type": "array", "items": {"type": "string"}, "description": "4-6个标签"},
                    "related_entry_titles": {"type": "array", "items": {"type": "string"}},
                    "cover_image_prompt": {"type": "string", "description": "封面图 AI 绘画提示词，中文，100字左右"},
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
            resp = requests.post(url, headers=headers, json=body, timeout=180)
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


def clean_string_field(val: str) -> str:
    """清理字符串字段中的多余空白和引号"""
    if not isinstance(val, str):
        return val
    return val.strip().strip('"').strip("'").strip()


def sanitize_entry(data: dict, expected_category: str) -> dict:
    """校验并清理所有字段"""
    # category: 提取有效值
    raw_cat = data.get("category", "")
    cleaned_cat = clean_string_field(raw_cat)
    if cleaned_cat not in VALID_CATEGORIES:
        for cat in VALID_CATEGORIES:
            if cat in str(raw_cat):
                cleaned_cat = cat
                break
        else:
            cleaned_cat = expected_category
    data["category"] = cleaned_cat

    # title / subtitle
    if "title" in data:
        data["title"] = clean_string_field(data["title"])
    if "subtitle" in data:
        data["subtitle"] = clean_string_field(data["subtitle"])

    # introduction
    if "introduction" in data:
        data["introduction"] = data["introduction"].strip()

    # sections: 清理每个 section 的 title/body
    for sec in data.get("sections", []):
        sec["title"] = clean_string_field(sec.get("title", ""))
        sec["body"] = sec.get("body", "").strip()

    # infobox: 清理 key/value
    for field in data.get("infobox", []):
        field["key"] = clean_string_field(field.get("key", ""))
        field["value"] = clean_string_field(field.get("value", ""))

    # tags: 清理每个 tag
    data["tags"] = [clean_string_field(t) for t in data.get("tags", []) if clean_string_field(t)]

    # related_entry_titles
    data["related_entry_titles"] = [
        clean_string_field(t) for t in data.get("related_entry_titles", []) if clean_string_field(t)
    ]

    return data


def generate_entry(task: dict, user: dict, user_titles: List[str]) -> Optional[dict]:
    other_titles = [t for t in user_titles if t != task["title"]]
    cross_refs_str = "、".join(f"[[{r}]]" for r in task.get("cross_refs", []))

    user_msg = f"""请为用户「{user['display_name']}」（签名：{user['bio']}）创建一篇词条。

任务信息：
- 标题：{task['title']}
- 分类：{task['category']}（在 category 字段中必须填写这个纯英文单词：{task['category']}）
- 创作提示：{task['hints']}
- 需要在正文中用 [[]] 引用的相关词条：{cross_refs_str or '无'}
- 该用户的其他词条标题（可在正文中引用）：{'、'.join(other_titles) or '无'}

写作要求：
1. 严格参照范文的质量和格式，写出有血有肉的词条
2. introduction 150-300字，sections 5-7个，每个100-400字，整篇词条 800 字以上
3. 在正文中自然穿插 [[蓝色链接]] 引用相关词条，对值得创建但不存在的词条用 {{{{红色链接}}}}
4. 不确定或无从考证的细节标记 [来源请求]
5. 细节！细节！细节！——具体的时间、地名、对话（用「」括起来）、感官描写
6. 每个章节用 \\n\\n 分段，写出有呼吸感的段落
7. 绝对不要使用 **粗体**、*斜体*、Markdown 列表、表格、引用等格式
8. cover_image_prompt 要详细具体，描述一个与词条情感核心相关的画面，适合作为封面图
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

    return sanitize_entry(entry_data, task["category"])


WORKERS = 4
write_lock = threading.Lock()
stats = {"ok": 0, "fail": 0, "skip": 0}


def process_one(task, user, user_titles_list, pbar):
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

    user_titles: Dict[str, List[str]] = {}
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
