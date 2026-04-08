import Foundation
import SwiftData

enum MockEntries {

    /// 在给定的 ModelContext 中创建并插入全部 mock 词条
    static func seedAll(in context: ModelContext) {
        let entries = [
            makeGrandpa(),
            makeCreamChicken(),
            makeGrandmasRedBraisedPork(),
            makeChangshaSt17(),
            makeSeniorHighSchool(),
            makeFirstSnow(),
            makeOldWristwatch(),
            makeXiaoming(),
            makeMilkTeaShop(),
            makeCollegeYears(),
            // 其他用户
            makeYudongGrandma(),
            makeLinqingTeapot(),
            makeXiaoyuDaju(),
        ]
        for entry in entries {
            context.insert(entry)
        }
    }

    // MARK: - Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps) ?? .now
    }

    // MARK: 1. 爷爷（person / collaborative）

    private static func makeGrandpa() -> Entry {
        Entry(
            title: "爷爷",
            subtitle: "金大海（1935-2019）",
            category: .person,
            scope: .collaborative,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "全名", value: "金大海"),
                InfoboxField(key: "生年", value: "1935年"),
                InfoboxField(key: "卒年", value: "2019年"),
                InfoboxField(key: "关系", value: "祖孙"),
                InfoboxField(key: "籍贯", value: "浙江宁波"),
                InfoboxField(key: "职业", value: "退休教师"),
            ]),
            introduction: "金大海（1935年—2019年），浙江宁波人，退休中学数学教师。在孙辈的记忆中，他是一个沉默寡言但极其温柔的老人，总是在傍晚的阳台上用半导体收音机听越剧。",
            sections: [
                EntrySection(title: "早年经历", body: "爷爷出生于宁波北仑的一个渔村。1953年考入浙江师范学院数学系，毕业后分配至[[长沙]]某中学任教。他一生未离开过教育行业，直到1995年退休。"),
                EntrySection(title: "与孙辈的日常", body: "每逢暑假，爷爷会带我去{{钓鱼台公园}}钓鱼。他从不催促，只是安静地坐在那里，偶尔说一句「鱼要来了」。那些下午是我童年里最安静的时光。[来源请求]"),
                EntrySection(title: "晚年与离世", body: "2018年冬天确诊肺癌。爷爷拒绝了化疗，只说「够了」。2019年春天，在老宅的床上安详离世。灵堂上放的是他最爱的越剧《梁祝》。"),
            ],
            relatedEntryTitles: ["长沙岳麓区青云街17号", "外婆的红烧肉"],
            tags: ["人物", "家族", "浙江"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 3, 10), summary: "创建词条"),
                Revision(editorName: "表姐小雅", timestamp: date(2025, 3, 15), summary: "补充早年经历段落"),
                Revision(editorName: "我", timestamp: date(2025, 4, 1), summary: "增加晚年内容"),
            ],
            comments: [
                Comment(authorName: "表姐小雅", body: "爷爷那个半导体收音机我也记得！每次去他都在听越剧", createdAt: date(2025, 3, 11)),
                Comment(authorName: "妈妈", body: "你爷爷年轻时候可帅了，改天翻翻老照片给你", createdAt: date(2025, 3, 12), likeCount: 3),
                Comment(authorName: "昱东", body: "写得真好，读着读着眼眶就湿了", createdAt: date(2025, 3, 15), likeCount: 5),
                Comment(authorName: "表姐小雅", body: "钓鱼那段太真实了，爷爷确实从来不急", createdAt: date(2025, 3, 16), likeCount: 2),
                Comment(authorName: "姐姐", body: "「够了」这两个字看得我好难过", createdAt: date(2025, 4, 1), likeCount: 8),
            ],
            authorName: "我",
            authorId: "self",
            contributorNames: ["表姐小雅"],
            likeCount: 42,
            collectCount: 18,
            commentCount: 5,
            viewCount: 230,
            createdAt: date(2025, 3, 10),
            updatedAt: date(2025, 4, 1)
        )
    }

    // MARK: 2. 奶油鸡（companion / public）

    private static func makeCreamChicken() -> Entry {
        Entry(
            title: "奶油鸡",
            subtitle: "一只名叫奶油鸡的橘猫",
            category: .companion,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "名字", value: "奶油鸡"),
                InfoboxField(key: "物种", value: "猫"),
                InfoboxField(key: "品种", value: "中华田园猫（橘）"),
                InfoboxField(key: "性别", value: "公（已绝育）"),
                InfoboxField(key: "毛色", value: "橘白相间"),
                InfoboxField(key: "性情", value: "贪吃、黏人、怕吹风机"),
                InfoboxField(key: "状态", value: "健在（7岁）"),
            ]),
            introduction: "奶油鸡是一只橘白相间的中华田园猫，2019年被作者从学校后门的纸箱中捡回。因幼年时毛色酷似一只裹了面包糠的炸鸡而得名。现居上海，体重已达14斤。",
            sections: [
                EntrySection(title: "发现与收养", body: "2019年6月的一个雨夜，作者在[[大学]]后门发现了一个湿透的纸箱，里面有三只小猫。奶油鸡是最小的那只，蜷缩在角落，浑身颤抖。作者将其带回宿舍，用热毛巾擦干，喂了半管羊奶粉。"),
                EntrySection(title: "命名由来", body: "关于名字的由来存在两个版本。作者声称是因为幼猫时期毛色像「裹了面包糠的炸鸡」。室友则坚持认为这个名字来自当晚的外卖——一份奶油炸鸡。[来源请求]"),
                EntrySection(title: "性格与习惯", body: "奶油鸡性格极为黏人，会在作者工作时趴在键盘上。它惧怕吹风机和吸尘器，但对快递箱有狂热的热爱。每晚固定在23:00发疯（俗称「跑酷时间」），持续约15分钟。"),
                EntrySection(title: "体重争议", body: "截至2026年3月，奶油鸡体重14斤。兽医多次建议减肥，但收效甚微。作者认为「他只是骨架大」，此说法{{未获兽医认可}}。"),
            ],
            relatedEntryTitles: ["小明"],
            tags: ["相伴", "猫", "上海"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 1, 5), summary: "创建词条"),
                Revision(editorName: "我", timestamp: date(2025, 6, 20), summary: "更新体重数据"),
            ],
            comments: [
                Comment(authorName: "陈小鱼", body: "橘猫都这样！我家大橘也是只认食盆", createdAt: date(2025, 1, 10), likeCount: 12),
                Comment(authorName: "林清", body: "奶油鸡这个名字也太可爱了吧哈哈哈", createdAt: date(2025, 2, 3), likeCount: 7),
                Comment(authorName: "张远", body: "「在逃公主」的气质绝了", createdAt: date(2025, 3, 1), likeCount: 4),
            ],
            authorName: "我",
            authorId: "self",
            likeCount: 128,
            collectCount: 45,
            commentCount: 3,
            viewCount: 890,
            createdAt: date(2025, 1, 5),
            updatedAt: date(2025, 6, 20)
        )
    }

    // MARK: 3. 外婆的红烧肉（taste）

    private static func makeGrandmasRedBraisedPork() -> Entry {
        Entry(
            title: "外婆的红烧肉",
            category: .taste,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "菜名", value: "红烧肉"),
                InfoboxField(key: "类型", value: "家常菜"),
                InfoboxField(key: "菜系", value: "本帮菜 / 浙菜融合"),
                InfoboxField(key: "创制者", value: "外婆（王秀兰）"),
                InfoboxField(key: "关键食材", value: "五花肉、冰糖、老抽、八角"),
                InfoboxField(key: "传承状态", value: "口传，未有文字记录"),
            ]),
            introduction: "外婆的红烧肉是作者家族中最具代表性的一道菜，由外婆王秀兰独创。其特点是冰糖比例偏高，色泽红亮，肥而不腻。此菜长期出现在每年除夕夜的餐桌正中央，被家族成员视为团圆的味觉符号。",
            sections: [
                EntrySection(title: "配方与做法", body: "外婆从不使用称量工具。据作者母亲回忆，五花肉需切成麻将牌大小，先用开水焯去血沫，再冷油下锅煸出猪油。冰糖的量「看心情」，但从成品来看约占肉重的10%。加入老抽、料酒、八角后，小火焖煮两小时。"),
                EntrySection(title: "家族记忆", body: "这道红烧肉陪伴了作者的整个成长过程。小时候每次考试考得好，外婆就会加做一份。高三那年压力大吃不下饭，外婆专门坐了三小时的大巴从[[宁波]]来送一锅红烧肉。那一锅肉在宿舍里热了三天，被室友们瓜分殆尽。"),
                EntrySection(title: "传承困境", body: "外婆于2022年去世后，这道菜的配方只留在家人模糊的记忆里。母亲尝试复刻过多次，「总是差一点」。作者怀疑缺失的是外婆那口用了三十年的铸铁锅。"),
            ],
            relatedEntryTitles: ["爷爷", "长沙岳麓区青云街17号"],
            tags: ["滋味", "家常菜", "除夕"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 2, 8), summary: "创建词条"),
                Revision(editorName: "妈妈", timestamp: date(2025, 2, 14), summary: "修正配方细节"),
            ],
            authorName: "我",
            authorId: "self",
            contributorNames: ["妈妈"],
            likeCount: 89,
            collectCount: 34,
            commentCount: 12,
            viewCount: 560,
            createdAt: date(2025, 2, 8),
            updatedAt: date(2025, 2, 14)
        )
    }

    // MARK: 4. 长沙岳麓区青云街17号（place）

    private static func makeChangshaSt17() -> Entry {
        Entry(
            title: "长沙岳麓区青云街17号",
            subtitle: "爷爷奶奶的老宅",
            category: .place,
            scope: .collaborative,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "地点名", value: "青云街17号"),
                InfoboxField(key: "类型", value: "住宅"),
                InfoboxField(key: "位置", value: "湖南省长沙市岳麓区"),
                InfoboxField(key: "建成", value: "约1982年"),
                InfoboxField(key: "现状", value: "已拆迁（2020年）"),
                InfoboxField(key: "作者居住时期", value: "1998-2012（暑期）"),
            ]),
            introduction: "长沙岳麓区青云街17号是作者祖父母的住所，一栋建于1980年代的单位分配房。作者在此度过了几乎所有的暑假。2020年因城市改造被拆除，原址现为一座商业综合体。",
            sections: [
                EntrySection(title: "建筑描述", body: "这是一栋六层砖混结构的单位房，外墙为淡黄色瓷砖。[[爷爷]]家位于四楼，两室一厅，面积约65平方米。阳台朝南，可以看到远处的岳麓山。厨房很小，但外婆总能在里面变出一桌子菜。"),
                EntrySection(title: "楼道与邻里", body: "楼道里永远弥漫着各家饭菜的混合气味。三楼的李奶奶每天傍晚在楼下摇蒲扇，见到每个小孩都要塞一颗话梅糖。五楼的张叔叔会在周末拉二胡，声音穿过整栋楼。"),
                EntrySection(title: "拆迁与告别", body: "2020年初收到拆迁通知时，爷爷已经去世一年。奶奶对着空荡荡的房子坐了很久，最后只带走了那台半导体收音机和一本相册。搬家那天下着小雨。"),
            ],
            relatedEntryTitles: ["爷爷", "外婆的红烧肉", "我的高三"],
            tags: ["栖居", "长沙", "已拆迁", "童年"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 4, 5), summary: "创建词条"),
                Revision(editorName: "二叔", timestamp: date(2025, 4, 10), summary: "补充楼道邻里细节"),
            ],
            authorName: "我",
            authorId: "self",
            contributorNames: ["二叔"],
            likeCount: 67,
            collectCount: 29,
            commentCount: 9,
            viewCount: 410,
            createdAt: date(2025, 4, 5),
            updatedAt: date(2025, 4, 10)
        )
    }

    // MARK: 5. 我的高三（era / private）

    private static func makeSeniorHighSchool() -> Entry {
        Entry(
            title: "我的高三",
            subtitle: "2015.9 - 2016.6",
            category: .era,
            scope: .private,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "时期名", value: "高三"),
                InfoboxField(key: "开始", value: "2015年9月"),
                InfoboxField(key: "结束", value: "2016年6月"),
                InfoboxField(key: "作者年龄", value: "17-18岁"),
                InfoboxField(key: "主要居所", value: "学校宿舍 / 家"),
            ]),
            introduction: "高三是作者人生中强度最高的一年。在这一年里，作者经历了三次模拟考试的起伏、一段短暂的暗恋、以及外婆坐三小时大巴送来的一锅红烧肉。",
            sections: [
                EntrySection(title: "日常节奏", body: "每天早上6:10起床，6:30到教室早读。课间十分钟通常用来补作业。午休在课桌上趴着睡，醒来脸上全是课本的印痕。晚自习到22:30，回宿舍后还要再看一小时。"),
                EntrySection(title: "几次模考", body: "一模考砸了，数学只有89分，是高中三年最低分。班主任找作者谈话，说的第一句是「你最近是不是恋爱了」。[来源请求] 二模回到年级前五十。三模发挥正常。"),
                EntrySection(title: "那锅红烧肉", body: "高三下学期有段时间完全吃不下饭。外婆知道后，从宁波坐了三小时大巴到长沙，在学校门口等了半小时。她递过来一个保温桶，里面是[[外婆的红烧肉]]。那天晚自习，整个教室都是红烧肉的味道。"),
            ],
            relatedEntryTitles: ["外婆的红烧肉", "长沙岳麓区青云街17号"],
            tags: ["流年", "高中", "2016"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 5, 1), summary: "创建词条"),
            ],
            authorName: "我",
            authorId: "self",
            likeCount: 0,
            collectCount: 0,
            commentCount: 0,
            viewCount: 5,
            createdAt: date(2025, 5, 1),
            updatedAt: date(2025, 5, 1)
        )
    }

    // MARK: 6. 初雪（moment）

    private static func makeFirstSnow() -> Entry {
        Entry(
            title: "2024年冬天的第一场雪",
            category: .moment,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "事件名", value: "初雪"),
                InfoboxField(key: "类型", value: "天气 / 个人事件"),
                InfoboxField(key: "日期", value: "2024年12月21日"),
                InfoboxField(key: "地点", value: "上海市长宁区"),
                InfoboxField(key: "参与者", value: "我、奶油鸡"),
            ]),
            introduction: "2024年12月21日凌晨，上海迎来了那个冬天的第一场雪。作者在凌晨三点被窗外的异常安静惊醒，拉开窗帘看到整个小区被白色覆盖。奶油鸡第一次见到雪，在窗台上看了整整半小时。",
            sections: [
                EntrySection(title: "发现", body: "那天晚上作者加班到凌晨两点，睡下后不到一小时就醒了。窗外没有平时的车声，安静得不正常。拉开窗帘的那一刻，白色从上到下铺满了整个视野。"),
                EntrySection(title: "奶油鸡的反应", body: "[[奶油鸡]]被作者抱到窗台上后，瞳孔放大，前爪试图去拍玻璃上的雪花。它在窗台上一动不动地看了半小时，尾巴缓慢地左右摇摆。这是它七年生命中第一次见到雪。"),
            ],
            relatedEntryTitles: ["奶油鸡"],
            tags: ["际遇", "上海", "冬天", "2024"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2024, 12, 22), summary: "创建词条"),
            ],
            authorName: "我",
            authorId: "self",
            likeCount: 203,
            collectCount: 78,
            commentCount: 31,
            viewCount: 1420,
            createdAt: date(2024, 12, 22),
            updatedAt: date(2024, 12, 22)
        )
    }

    // MARK: 7. 老手表（keepsake）

    private static func makeOldWristwatch() -> Entry {
        Entry(
            title: "爷爷的上海牌手表",
            category: .keepsake,
            scope: .private,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "物品名", value: "上海牌机械手表"),
                InfoboxField(key: "类型", value: "配饰 / 计时器"),
                InfoboxField(key: "来历", value: "爷爷的遗物"),
                InfoboxField(key: "获得时间", value: "2019年（爷爷去世后）"),
                InfoboxField(key: "当前状态", value: "收藏中（已停走）"),
            ]),
            introduction: "这是一块1970年代生产的上海牌手表，表盘已经泛黄，表带换过三次。爷爷戴了它将近四十年。现在它安静地躺在作者的抽屉里，指针停在10:42。",
            sections: [
                EntrySection(title: "来历", body: "据[[爷爷]]说，这块表是1976年他获得「优秀教师」称号时，学校奖励的。在那个年代，一块上海牌手表相当于半年工资。爷爷把它当宝贝，每天睡前都小心翼翼地放在床头柜上。"),
                EntrySection(title: "停走", body: "不确定是什么时候停的。可能是2019年的某一天，和爷爷同时安静了下来。作者没有送去修，觉得「它该休息了」。"),
            ],
            relatedEntryTitles: ["爷爷"],
            tags: ["旧物", "遗物", "上海牌"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 3, 12), summary: "创建词条"),
            ],
            authorName: "我",
            authorId: "self",
            likeCount: 56,
            collectCount: 22,
            commentCount: 5,
            viewCount: 340,
            createdAt: date(2025, 3, 12),
            updatedAt: date(2025, 3, 12)
        )
    }

    // MARK: 8. 小明（person）

    private static func makeXiaoming() -> Entry {
        Entry(
            title: "小明",
            subtitle: "大学室友兼挚友",
            category: .person,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "全名", value: "李明"),
                InfoboxField(key: "生年", value: "1998年"),
                InfoboxField(key: "关系", value: "大学室友、挚友"),
                InfoboxField(key: "籍贯", value: "四川成都"),
                InfoboxField(key: "职业", value: "程序员"),
                InfoboxField(key: "状态", value: "在世"),
            ]),
            introduction: "小明，本名李明，作者的大学室友兼挚友。两人从大一军训时被分到同一个方阵开始，到毕业四年间几乎形影不离。小明是奶油鸡的「干爹」，也是除作者母亲外最了解作者的人。",
            sections: [
                EntrySection(title: "相识", body: "2016年9月军训第一天，排队领军训服时站在作者前面。他转头问「你也是计算机系的？」。后来发现不仅同系，还被分到了同一间宿舍。"),
                EntrySection(title: "大学四年", body: "一起翘课、一起打游戏、一起在图书馆通宵赶论文。小明负责写代码，作者负责写文档。大三那年合作的课程项目拿了校级奖。小明最经典的口头禅是「没事，还能改」。"),
                EntrySection(title: "现状", body: "毕业后小明去了杭州做程序员，作者留在上海。虽然不住在一个城市了，但每周至少一次的深夜语音通话没断过。[[奶油鸡]]周岁生日那天，小明专门从杭州赶来，带了一条鱼形玩具。"),
            ],
            relatedEntryTitles: ["奶油鸡", "大学四年"],
            tags: ["人物", "朋友", "大学"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 2, 20), summary: "创建词条"),
                Revision(editorName: "小明", timestamp: date(2025, 3, 1), summary: "修改「干爹」措辞争议"),
            ],
            authorName: "我",
            authorId: "self",
            contributorNames: ["小明"],
            likeCount: 35,
            collectCount: 12,
            commentCount: 8,
            viewCount: 280,
            createdAt: date(2025, 2, 20),
            updatedAt: date(2025, 3, 1)
        )
    }

    // MARK: 9. 奶茶店（place）

    private static func makeMilkTeaShop() -> Entry {
        Entry(
            title: "学校后门的奶茶店",
            category: .place,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "地点名", value: "茶里茶气"),
                InfoboxField(key: "类型", value: "奶茶店"),
                InfoboxField(key: "位置", value: "大学后门左拐50米"),
                InfoboxField(key: "建成", value: "约2015年"),
                InfoboxField(key: "现状", value: "已关闭（2021年）"),
                InfoboxField(key: "作者居住时期", value: "2016-2020"),
            ]),
            introduction: "「茶里茶气」是一家开在大学后门的奶茶店，面积不到15平米，只有四张桌子。作者在大学四年间在此消费约800余杯奶茶（保守估计）。老板娘姓陈，能记住每个常客的口味偏好。",
            sections: [
                EntrySection(title: "环境", body: "店面很小，进门左手边是吧台，右手边靠墙摆了四张桌子。墙上贴满了顾客留下的便利贴，有些已经褪色得看不清字迹。空调制冷效果很差，夏天只能靠一台落地扇。"),
                EntrySection(title: "招牌产品", body: "芋泥波波奶茶是作者的固定选择，大杯、少冰、七分甜。陈老板娘看到作者进门就开始做，不用开口点单。[[小明]]则永远点焦糖玛奇朵。"),
                EntrySection(title: "关闭", body: "2021年疫情期间，因为租金压力和客流减少，这家店悄然关闭了。作者毕业后有一次路过，发现已经变成了一家手机维修店。门口再没有奶茶的香味了。"),
            ],
            relatedEntryTitles: ["小明"],
            tags: ["栖居", "大学", "已关闭"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 5, 10), summary: "创建词条"),
            ],
            authorName: "我",
            authorId: "self",
            likeCount: 44,
            collectCount: 15,
            commentCount: 6,
            viewCount: 320,
            createdAt: date(2025, 5, 10),
            updatedAt: date(2025, 5, 10)
        )
    }

    // MARK: 10. 大学四年（era）

    private static func makeCollegeYears() -> Entry {
        Entry(
            title: "大学四年",
            subtitle: "2016.9 - 2020.6",
            category: .era,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "时期名", value: "大学本科"),
                InfoboxField(key: "开始", value: "2016年9月"),
                InfoboxField(key: "结束", value: "2020年6月"),
                InfoboxField(key: "作者年龄", value: "18-22岁"),
                InfoboxField(key: "主要居所", value: "大学宿舍"),
            ]),
            introduction: "2016年至2020年，作者就读于某大学计算机科学与技术专业。这四年间收获了一个挚友（小明）、一只猫（奶油鸡）、一段失败的恋情（此条目尚未创建），以及一个勉强可以找到工作的学位。",
            sections: [
                EntrySection(title: "大一", body: "军训、选课、第一次远离家乡。认识了[[小明]]。发现食堂三楼的麻辣香锅是人间至味，后来吃了四年都没腻。"),
                EntrySection(title: "大二与大三", body: "课业渐重，开始频繁出没于[[学校后门的奶茶店]]。大三下学期捡到了[[奶油鸡]]，从此宿舍多了一个「违规住户」。和小明合作的课程项目拿了校级奖。"),
                EntrySection(title: "大四与毕业", body: "写论文、找工作、和即将分散的朋友们道别。毕业那天下了大雨，学位帽全湿了。拍毕业照时奶油鸡被偷偷带来了，一脸嫌弃地出现在了合影里。"),
            ],
            relatedEntryTitles: ["小明", "奶油鸡", "学校后门的奶茶店"],
            tags: ["流年", "大学", "2016-2020"],
            revisions: [
                Revision(editorName: "我", timestamp: date(2025, 6, 1), summary: "创建词条"),
                Revision(editorName: "小明", timestamp: date(2025, 6, 5), summary: "补充课程项目获奖细节"),
            ],
            authorName: "我",
            authorId: "self",
            contributorNames: ["小明"],
            likeCount: 72,
            collectCount: 28,
            commentCount: 15,
            viewCount: 620,
            createdAt: date(2025, 6, 1),
            updatedAt: date(2025, 6, 5)
        )
    }

    // MARK: === 其他用户的词条 ===

    // MARK: 11. 昱东的奶奶（person / public）

    private static func makeYudongGrandma() -> Entry {
        Entry(
            title: "奶奶",
            subtitle: "王秀兰（1940-2023）",
            category: .person,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "全名", value: "王秀兰"),
                InfoboxField(key: "生年", value: "1940年"),
                InfoboxField(key: "卒年", value: "2023年"),
                InfoboxField(key: "关系", value: "祖孙"),
                InfoboxField(key: "籍贯", value: "山东济南"),
                InfoboxField(key: "职业", value: "纺织厂工人"),
            ]),
            introduction: "王秀兰（1940年—2023年），山东济南人，原济南第三纺织厂挡车工。她一辈子没出过山东省，却把两个儿子都供上了大学。在孙子昱东的记忆里，她的围裙上永远有面粉的味道。",
            sections: [
                EntrySection(title: "关于她的厨房", body: "奶奶的厨房是整个家里最温暖的地方。灶台旁永远挂着一条洗得发白的蓝色围裙。每逢周末，她会从凌晨五点开始和面，包出三百个饺子——韭菜鸡蛋的给孙子，猪肉白菜的给儿子。"),
                EntrySection(title: "纺织厂岁月", body: "1962年进厂，2000年下岗。三十八年里她只请过两次假：一次是大儿子出生，一次是丈夫去世。厂里的姐妹都叫她「铁秀兰」。"),
                EntrySection(title: "最后的冬天", body: "2023年的冬天格外冷。奶奶在病床上还念叨着「冰箱里有包好的饺子」。12月17日，她在睡梦中走了。追悼会上放的是她年轻时最爱的《沂蒙山小调》。"),
            ],
            tags: ["人物", "家族", "山东"],
            comments: [
                Comment(authorName: "我", body: "看哭了，你奶奶和我爷爷好像，都是那种很沉默但很温暖的人", createdAt: date(2025, 4, 20), likeCount: 14),
                Comment(authorName: "妈妈", body: "秀兰阿姨人真的特别好，以前过年总给我们送饺子", createdAt: date(2025, 4, 21), likeCount: 6),
                Comment(authorName: "林清", body: "「铁秀兰」这个名字好有力量", createdAt: date(2025, 4, 22), likeCount: 9),
            ],
            authorName: "昱东",
            authorId: "yudong",
            likeCount: 89,
            collectCount: 37,
            commentCount: 3,
            viewCount: 456,
            createdAt: date(2025, 4, 18),
            updatedAt: date(2025, 4, 22)
        )
    }

    // MARK: 12. 林清的紫砂壶（keepsake / public）

    private static func makeLinqingTeapot() -> Entry {
        Entry(
            title: "外公的紫砂壶",
            subtitle: "一把用了四十年的宜兴紫砂",
            category: .keepsake,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "物品名", value: "宜兴紫砂壶"),
                InfoboxField(key: "类型", value: "茶具"),
                InfoboxField(key: "来历", value: "外公1985年购于宜兴"),
                InfoboxField(key: "获得时间", value: "2022年（外公去世后继承）"),
                InfoboxField(key: "当前状态", value: "每日使用中"),
            ]),
            introduction: "这是一把1985年产的宜兴紫砂壶，壶身已被岁月养出温润的光泽。外公用它泡了四十年的铁观音，壶内早已浸透了茶香——即使只加白开水，倒出来的也带着一丝甘甜。",
            sections: [
                EntrySection(title: "外公与茶", body: "外公每天清晨的第一件事是烧水泡茶。他说好茶不需要好壶，但好壶需要好人养。这把壶跟了他从中年到暮年，壶底磨出了一圈浅浅的痕迹——那是每天在茶盘上旋转留下的。"),
                EntrySection(title: "继承", body: "外公走后，舅舅把这把壶给了我。他说「你是家里唯一还喝茶的年轻人」。第一次用它泡茶的时候，我闻到了外公客厅的味道。"),
            ],
            tags: ["旧物", "茶", "传承"],
            comments: [
                Comment(authorName: "张远", body: "「只加白开水也有茶香」这个细节太动人了", createdAt: date(2025, 5, 3), likeCount: 18),
                Comment(authorName: "我", body: "我爷爷也有一个类似的壶！已经不敢用了怕碎", createdAt: date(2025, 5, 4), likeCount: 4),
            ],
            authorName: "林清",
            authorId: "linqing",
            likeCount: 156,
            collectCount: 68,
            commentCount: 2,
            viewCount: 920,
            createdAt: date(2025, 5, 1),
            updatedAt: date(2025, 5, 3)
        )
    }

    // MARK: 13. 陈小鱼的大橘（companion / public）

    private static func makeXiaoyuDaju() -> Entry {
        Entry(
            title: "大橘",
            subtitle: "比奶油鸡还胖的橘猫",
            category: .companion,
            scope: .public,
            infobox: InfoboxData(fields: [
                InfoboxField(key: "名字", value: "大橘"),
                InfoboxField(key: "物种", value: "猫"),
                InfoboxField(key: "品种", value: "中华田园猫（纯橘）"),
                InfoboxField(key: "性别", value: "公（已绝育）"),
                InfoboxField(key: "毛色", value: "纯橘色"),
                InfoboxField(key: "性情", value: "佛系、贪睡、挑食"),
                InfoboxField(key: "状态", value: "健在（5岁，16斤）"),
            ]),
            introduction: "大橘是一只纯橘色的中华田园猫，2021年被陈小鱼在小区垃圾桶旁捡到。如今体重16斤，超过了互联网上大部分知名橘猫。它的人生哲学是「能躺着绝不坐着」。",
            sections: [
                EntrySection(title: "收养经过", body: "2021年夏天的一个傍晚，一只浑身跳蚤的小橘猫从垃圾桶后面探出头来。陈小鱼蹲下来，它就直接走过来趴在了她的拖鞋上。从此就再也没走过。"),
                EntrySection(title: "日常作息", body: "大橘每天的时间表极其规律：吃、睡、望窗外的鸟、再睡。它唯一会跑起来的场景是听到罐头开启的声音。兽医说它需要减肥，大橘表示「听不懂」。"),
                EntrySection(title: "与奶油鸡的相遇", body: "有一次带大橘去[[奶油鸡]]家做客。两只橘猫对视了三秒，然后各自找了一个角落趴下。主人们期待的「橘猫大战」并没有发生。"),
            ],
            tags: ["相伴", "猫", "橘猫"],
            comments: [
                Comment(authorName: "我", body: "16斤！！比奶油鸡还重两斤", createdAt: date(2025, 3, 20), likeCount: 22),
                Comment(authorName: "昱东", body: "「听不懂」哈哈哈哈橘猫确实是这样", createdAt: date(2025, 3, 21), likeCount: 11),
                Comment(authorName: "林清", body: "两只橘猫对视那段太好笑了", createdAt: date(2025, 3, 22), likeCount: 8),
                Comment(authorName: "张远", body: "求大橘和奶油鸡的合照！", createdAt: date(2025, 3, 23), likeCount: 15),
            ],
            authorName: "陈小鱼",
            authorId: "chenxiaoyu",
            likeCount: 234,
            collectCount: 89,
            commentCount: 4,
            viewCount: 1580,
            createdAt: date(2025, 3, 15),
            updatedAt: date(2025, 3, 23)
        )
    }
}
