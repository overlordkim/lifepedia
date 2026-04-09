#!/usr/bin/env python3
"""为 15 个用户生成头像：Seedream 生图 → 上传 Supabase Storage"""

import json, os, time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from dotenv import load_dotenv
from tqdm import tqdm

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

ARK_API_KEY = os.getenv("ARK_API_KEY")
ARK_BASE_URL = os.getenv("ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3")
SEEDREAM_MODEL = "doubao-seedream-5-0-260128"
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")

USERS_FILE = Path(__file__).resolve().parent / "users.json"

AVATAR_PROMPTS = {
    "u01": "一个年轻女生的背影，坐在图书馆窗边，手边放着一杯咖啡和一本翻开的书，自然光从侧面照进来，构图干净",
    "u02": "一个男生侧身靠在老旧的砖墙上，只露出下半张脸和肩膀，穿着深色卫衣，手里拿着一支笔，光线柔和",
    "u03": "一双手捧着一只青花瓷茶杯，背景是模糊的中式木质茶桌，蒸汽微微升腾，画面温暖安静",
    "u04": "一个女生蹲在路边逗一只橘猫，只拍到手和猫，背景是老巷子的青石板路，自然光",
    "u05": "一只手翻开一本旧书的特写，书页泛黄，旁边散落着几片干花，木质桌面，俯拍角度",
    "u06": "一台老式胶片相机放在木桌上，旁边是一卷胶卷和几张冲洗出的照片，自然光从窗户斜照进来",
    "u07": "黄昏时分一个人的剪影站在河边栏杆旁，远处是城市天际线的轮廓，逆光拍摄，画面安静",
    "u08": "一双穿着登山鞋的脚站在山顶岩石上，远处是连绵的山峦和云海，广角俯拍",
    "u09": "三只猫趴在一起睡觉的特写，一只橘猫一只白猫一只黑猫，柔软的毯子上，室内自然光",
    "u10": "一双手正在案板上揉面的特写，面粉撒在手上和桌面，背景是模糊的厨房器具，暖色光线",
    "u11": "一面贴满便签纸的墙，便签上写着各种问题和箭头，一只手正在贴新的便签，侧面拍摄",
    "u12": "一个旧木箱子里装满了老物件：怀表、信件、老照片、徽章，从上方俯拍，自然光",
    "u13": "一双沾着泥土的手正在花盆里种一株小绿植，旁边摆着几盆多肉植物，阳台场景",
    "u14": "雨天窗户上的水珠特写，透过模糊的玻璃能看到外面朦胧的街景和路灯，画面安静有氛围",
    "u15": "一个背包放在公路边的护栏上，远处是蜿蜒的山路延伸到远方，广角拍摄",
}


def call_seedream(prompt: str, size: str = "1920x1920", retries: int = 3):
    url = f"{ARK_BASE_URL}/images/generations"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {ARK_API_KEY}"}
    body = {"model": SEEDREAM_MODEL, "prompt": prompt, "size": size, "response_format": "url", "watermark": False}
    for attempt in range(retries):
        try:
            resp = requests.post(url, headers=headers, json=body, timeout=120)
            if resp.status_code == 429:
                time.sleep(5 * (attempt + 1))
                continue
            resp.raise_for_status()
            return resp.json().get("data", [{}])[0].get("url")
        except Exception as e:
            if attempt == retries - 1:
                tqdm.write(f"  Seedream fail: {e}")
            time.sleep(3)
    return None


def upload_avatar(image_url: str, user_id: str) -> str:
    img_data = requests.get(image_url, timeout=60).content
    path = f"avatars/{user_id}.jpg"
    upload_url = f"{SUPABASE_URL}/storage/v1/object/images/{path}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "image/jpeg",
        "x-upsert": "true",
    }
    resp = requests.post(upload_url, headers=headers, data=img_data, timeout=60)
    resp.raise_for_status()
    return f"{SUPABASE_URL}/storage/v1/object/public/images/{path}"


def process_one(user_id: str, prompt: str):
    full_prompt = prompt + "，真实摄影，高画质，适合作为社交头像的正方形构图"
    img_url = call_seedream(full_prompt, size="1920x1920")
    if not img_url:
        tqdm.write(f"  {user_id} 生图失败")
        return user_id, None
    public_url = upload_avatar(img_url, user_id)
    tqdm.write(f"  {user_id} ✓ {public_url[-40:]}")
    return user_id, public_url


def main():
    with open(USERS_FILE) as f:
        users = json.load(f)["users"]

    tasks = [(u["id"], AVATAR_PROMPTS[u["id"]]) for u in users if u["id"] in AVATAR_PROMPTS]

    results = {}
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(process_one, uid, prompt): uid for uid, prompt in tasks}
        for future in tqdm(as_completed(futures), total=len(futures), desc="生成头像"):
            uid, url = future.result()
            results[uid] = url

    ok = sum(1 for v in results.values() if v)
    print(f"\n完成: {ok}/{len(tasks)} 成功")
    for uid, url in sorted(results.items()):
        print(f"  {uid}: {url or 'FAILED'}")


if __name__ == "__main__":
    main()
