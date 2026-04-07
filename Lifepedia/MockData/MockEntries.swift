import Foundation

struct MockEntries {
    
    static func loadAll() -> [Entry] {
        return [grandmother, braisedPork, oldHouse, springFestival, childhoodSummer]
    }
    
    // MARK: - 张薇（外婆）
    
    static let grandmother = Entry(
        title: "张薇",
        subtitle: "1941年—2019年",
        type: .person,
        infobox: InfoboxData(fields: [
            InfoboxField(key: "全名", value: "张薇"),
            InfoboxField(key: "出生", value: "1941年 · 湖南长沙"),
            InfoboxField(key: "逝世", value: "2019年3月15日（77岁）"),
            InfoboxField(key: "籍贯", value: "湖南省长沙市"),
            InfoboxField(key: "关系", value: "词条创建者之外祖母"),
            InfoboxField(key: "知名于", value: "[[红烧肉]]配方（已失传）"),
        ]),
        sections: [
            EntrySection(
                title: "生平",
                content: "**张薇**（1941年—2019年），湖南长沙人。1941年生于长沙市岳麓区一户普通人家，家中排行第三。张薇一生未离开过湖南省，在[[长沙岳麓区老房子]]中居住超过四十年。其性格被家族成员描述为"极度温和但异常固执"，尤其在烹饪相关的事务上从不接受他人意见。"
            ),
            EntrySection(
                title: "烹饪",
                content: "张薇以其独创的[[红烧肉]]配方闻名于家族内部。该配方据信源自其母亲口传，未有文字记录[来源请求]。据词条创建者回忆，该红烧肉的核心特征为"极甜、极软、入口即化"，与湘菜传统的辛辣风格形成鲜明对比。\n\n张薇去世后，其外孙女曾多次尝试复原该配方，均未成功。2020年至2023年间的多次尝试被记录在案，失败原因被归结为"火候判断完全依赖直觉，无法量化"[来源请求]。",
                citationsNeeded: [
                    CitationNeeded(text: "该配方据信源自其母亲口传", reason: "仅基于创建者口述"),
                    CitationNeeded(text: "失败原因被归结为"火候判断完全依赖直觉"", reason: "缺乏其他家族成员交叉验证"),
                ]
            ),
            EntrySection(
                title: "与词条创建者的关系",
                content: "张薇与词条创建者（其外孙女）之间维持着一种被后者描述为"沉默但确定"的亲密关系。两人之间的互动集中于每年[[春节家庭聚餐]]期间，以共同烹饪和进食为主要形式。词条创建者在访谈中承认，她从未当面向张薇表达过感谢或爱意[来源请求]。"
            ),
        ],
        categories: ["家族成员", "湖南人物", "已故人物", "烹饪遗产"],
        seeAlso: ["红烧肉", "长沙岳麓区老房子", "春节家庭聚餐"],
        isPublic: true,
        authorName: "林小鹿"
    )
    
    // MARK: - 红烧肉
    
    static let braisedPork = Entry(
        title: "红烧肉",
        subtitle: "张薇配方",
        type: .object,
        infobox: InfoboxData(fields: [
            InfoboxField(key: "名称", value: "红烧肉（张薇配方）"),
            InfoboxField(key: "类型", value: "家族食物"),
            InfoboxField(key: "创作者", value: "[[张薇]]"),
            InfoboxField(key: "来源", value: "口传配方，无文字记录"),
            InfoboxField(key: "当前状态", value: "配方已失传"),
        ]),
        sections: [
            EntrySection(
                title: "概述",
                content: "**红烧肉**（张薇配方）是[[张薇]]一生中最具代表性的烹饪作品，在其家族内部享有极高声誉。该菜品的口味特征被描述为"极甜、极软、入口即化"，与标准湘菜红烧肉存在显著差异[来源请求]。"
            ),
            EntrySection(
                title: "配方争议",
                content: "张薇配方的核心技术要素被认为包括：特定品牌的老抽（品牌不详）、精确但未被记录的糖肉比例、以及一种被描述为"看颜色就知道好了"的火候判断方法。\n\n由于张薇本人从未将配方诉诸文字，且在生前多次拒绝了家族成员的录制请求（理由为"有什么好录的"），该配方于2019年张薇去世后被视为永久失传。此事件在家族内部引发了持续至今的关于{{烹饪遗产保护}}必要性的讨论。"
            ),
        ],
        categories: ["家族食物", "已失传技艺", "烹饪遗产"],
        seeAlso: ["张薇", "春节家庭聚餐"],
        isPublic: true,
        authorName: "林小鹿"
    )
    
    // MARK: - 长沙岳麓区老房子
    
    static let oldHouse = Entry(
        title: "长沙岳麓区老房子",
        subtitle: "约1978年—2021年",
        type: .place,
        infobox: InfoboxData(fields: [
            InfoboxField(key: "名称", value: "岳麓区老房子"),
            InfoboxField(key: "位置", value: "湖南省长沙市岳麓区"),
            InfoboxField(key: "存续时间", value: "约1978年—2021年"),
            InfoboxField(key: "当前状态", value: "已拆除"),
            InfoboxField(key: "关联人物", value: "[[张薇]]"),
        ]),
        sections: [
            EntrySection(
                title: "概述",
                content: "**长沙岳麓区老房子**是[[张薇]]自1978年起的长期居所，位于湖南省长沙市岳麓区某老旧住宅区内（具体门牌号已不可考）。该建筑于2021年在城市改造工程中被拆除，词条创建者未能在拆除前最后一次到访[来源请求]。"
            ),
            EntrySection(
                title: "建筑特征",
                content: "该住宅为典型的1970年代南方城市居民楼，砖混结构，六层无电梯。[[张薇]]居住于四楼。据词条创建者回忆，该住宅最显著的感官特征为"永远弥漫着红烧肉的气味"，这一说法的客观性存疑[来源请求]。\n\n楼道内的墙壁在2010年后从未重新粉刷，词条创建者记得墙上有一处她幼年时用蜡笔画的太阳，直到建筑拆除时仍在。"
            ),
        ],
        categories: ["家族地点", "已消失的地方", "长沙建筑"],
        seeAlso: ["张薇", "春节家庭聚餐"],
        isPublic: true,
        authorName: "林小鹿"
    )
    
    // MARK: - 春节家庭聚餐
    
    static let springFestival = Entry(
        title: "春节家庭聚餐",
        subtitle: "年度循环事件",
        type: .event,
        infobox: InfoboxData(fields: [
            InfoboxField(key: "名称", value: "春节家庭聚餐"),
            InfoboxField(key: "时间", value: "每年农历除夕"),
            InfoboxField(key: "地点", value: "[[长沙岳麓区老房子]]"),
            InfoboxField(key: "参与者", value: "[[张薇]]及全体家族成员"),
        ]),
        sections: [
            EntrySection(
                title: "概述",
                content: "**春节家庭聚餐**是词条创建者家族中持续时间最长的年度传统活动，通常在每年农历除夕于[[长沙岳麓区老房子]]举行。该传统自词条创建者有记忆以来从未间断，直至2019年[[张薇]]去世后自然终止。"
            ),
            EntrySection(
                title: "流程",
                content: "据词条创建者回忆，聚餐的固定流程为：上午由张薇独自采购食材（不接受任何人陪同），下午开始烹饪（同样不接受帮助），傍晚全家围坐于客厅的圆桌旁进食。[[红烧肉]]是每年固定的核心菜品。\n\n饭后活动包括看春晚和打麻将。词条创建者通常在此期间独自坐在阳台上，原因被记录为"不会打麻将且觉得春晚无聊"[来源请求]。"
            ),
            EntrySection(
                title: "最后一次",
                content: "2019年春节是该传统的最后一次实施。词条创建者在访谈中表示，她对那次聚餐的具体细节已无法准确回忆，仅记得"走的时候外婆站在楼道里看我下楼，我没有回头"。\n\n此后，张薇于同年3月去世。该年度传统随之永久终止。至本词条撰写时，词条创建者尚未建立任何替代性的家族聚会传统。"
            ),
        ],
        categories: ["家族传统", "年度事件", "已终止的传统"],
        seeAlso: ["张薇", "红烧肉", "长沙岳麓区老房子"],
        isPublic: true,
        authorName: "林小鹿"
    )
    
    // MARK: - 童年的暑假
    
    static let childhoodSummer = Entry(
        title: "童年的暑假",
        subtitle: "约2003年—2009年",
        type: .period,
        infobox: InfoboxData(fields: [
            InfoboxField(key: "名称", value: "童年的暑假"),
            InfoboxField(key: "起止时间", value: "约2003年—2009年"),
            InfoboxField(key: "定义特征", value: "往返于上海与长沙之间"),
            InfoboxField(key: "关键事件", value: "3 件"),
        ]),
        sections: [
            EntrySection(
                title: "概述",
                content: "**童年的暑假**是词条创建者对其小学阶段（约2003年—2009年）每年暑期的统称。该时期的核心体验模式为：学期结束后乘火车从上海前往长沙，在[[张薇]]家中度过一至两个月，学期开始前返回上海。\n\n词条创建者将这一时期描述为"人生中最没有焦虑的阶段"[来源请求]。"
            ),
            EntrySection(
                title: "日常",
                content: "在长沙期间，词条创建者的日常活动包括：上午在客厅看电视（主要为动画频道）、中午吃[[张薇]]做的饭、下午在小区院子里和邻居孩子玩耍、晚上和张薇一起在阳台上乘凉。\n\n据词条创建者回忆，她在这些暑假中从未完成过任何暑假作业，而张薇对此的态度是"完全纵容"。"
            ),
        ],
        categories: ["童年", "上海-长沙", "暑假", "已结束的时期"],
        seeAlso: ["张薇", "长沙岳麓区老房子"],
        isPublic: true,
        authorName: "林小鹿"
    )
}
