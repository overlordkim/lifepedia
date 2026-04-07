# 人间词条 — 技术路线

## 一、整体架构

```
┌─────────────────────────────────────────────┐
│              iOS App (SwiftUI)               │
│                                              │
│  发现页 · 百科页 · 编纂页 · 图谱页 · 我的页  │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ 词条渲染  │  │ 图谱渲染  │  │ 对话管理   │  │
│  │ 引擎     │  │ 引擎     │  │           │  │
│  └──────────┘  └──────────┘  └───────────┘  │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │         SwiftData 本地持久化          │    │
│  └──────────────────────────────────────┘    │
└─────────────┬──────────────┬────────────────┘
              │              │
              ▼              ▼
     ┌────────────┐  ┌──────────────┐
     │ Claude API │  │ 图像生成 API  │
     │ (对话+生成) │  │ (词条插画)    │
     └────────────┘  └──────────────┘
              │              │
              ▼              ▼
     ┌──────────────────────────────┐
     │    Supabase (云端同步+社交)    │
     │  Auth · PostgreSQL · Storage  │
     └──────────────────────────────┘
```

### 架构决策

- **客户端优先**：核心体验（对话、词条渲染、图谱）全部在本地运行，不依赖后端延迟
- **AI 直连**：App 直接调用 Claude API，不经过自建后端中转，减少一跳延迟
- **本地先行，云端同步**：词条先存 SwiftData，后台静默同步到 Supabase；断网时完全可用
- **黑客松 MVP 可以砍掉 Supabase**：社交信息流用预置 mock 数据，先跑通核心链路

## 二、数据模型（SwiftData）

### 2.1 Entry（词条）— 核心模型

```swift
@Model
class Entry {
    @Attribute(.unique) var id: UUID
    var title: String                    // "张薇"
    var subtitle: String?                // "1941年—2019年"
    var type: EntryType                  // .person / .place / .object / .event / .period
    var infobox: InfoboxData             // 结构化信息框，Codable JSON
    var sections: [Section]              // 正文章节列表
    var categories: [String]             // ["家族成员", "湖南人物", "已故人物"]
    var coverImageURL: String?           // 封面图 URL（本地路径或远程）
    var coverImagePrompt: String?        // AI 生成封面图用的 prompt
    var isPublic: Bool                   // 是否公开到发现页
    var createdAt: Date
    var updatedAt: Date
    
    // 关系
    @Relationship var author: User?
    @Relationship var revisions: [Revision]
    @Relationship(inverse: \EntryLink.sourceEntry) var outgoingLinks: [EntryLink]
    @Relationship(inverse: \EntryLink.targetEntry) var incomingLinks: [EntryLink]
    @Relationship var conversation: Conversation?  // 产出这篇词条的对话
}
```

### 2.2 EntryType（词条类型枚举）

```swift
enum EntryType: String, Codable {
    case person    // 人物
    case place     // 地点
    case object    // 物品
    case event     // 事件
    case period    // 时期
}
```

### 2.3 InfoboxData（信息框）— 按类型变化

```swift
struct InfoboxData: Codable {
    var fields: [InfoboxField]
}

struct InfoboxField: Codable {
    var key: String       // "出生", "逝世", "关系"
    var value: String     // "1941年 · 湖南长沙"
    var linkedEntryId: UUID?  // 如果 value 是另一个词条的链接
}
```

各类型的默认字段：
- **人物**：全名、出生、逝世、籍贯、与创建者关系、知名于
- **地点**：名称、位置、存续时间、当前状态、关联人物
- **物品**：名称、类型、来源、获得时间、当前状态
- **事件**：名称、日期、地点、参与者
- **时期**：名称、起止时间、定义特征

### 2.4 Section（正文章节）

```swift
struct Section: Codable {
    var title: String           // "生平", "烹饪", "影响"
    var content: String         // Markdown 格式正文，含链接标记
    var citationsNeeded: [CitationNeeded]
}

struct CitationNeeded: Codable {
    var text: String            // 被标记的原文片段
    var reason: String          // AI 标记的理由
}
```

### 2.5 EntryLink（词条间链接）

```swift
@Model
class EntryLink {
    var id: UUID
    var displayText: String          // 链接在正文中显示的文字
    var relation: String?            // "代表作", "居住地" 等
    var isRedLink: Bool              // true = 目标词条尚未创建
    var redLinkTitle: String?        // 红色链接的暂定标题
    
    @Relationship var sourceEntry: Entry?
    @Relationship var targetEntry: Entry?   // 红色链接时为 nil
}
```

### 2.6 Conversation（对话）

```swift
@Model
class Conversation {
    var id: UUID
    var messages: [ChatMessage]      // 对话消息列表
    var status: ConversationStatus   // .active / .completed
    var createdAt: Date
    
    @Relationship var draftEntries: [Entry]  // 本次对话产出的词条
}

struct ChatMessage: Codable {
    var role: MessageRole            // .user / .assistant
    var content: String
    var timestamp: Date
    var identifiedEntryCount: Int?   // AI 消息附带的已识别词条数
}
```

### 2.7 Revision（编辑历史）

```swift
@Model
class Revision {
    var id: UUID
    var summary: String              // "扩充了'烹饪'章节"
    var timestamp: Date
    var snapshotJSON: Data           // 该版本的完整词条 JSON 快照
    
    @Relationship var entry: Entry?
}
```

### 2.8 User（用户）

```swift
@Model
class User {
    var id: String
    var name: String
    var encyclopediaName: String     // "金群琳百科全书"
    var bio: String?
    var avatarURL: String?
    var entryCount: Int
    var createdAt: Date
    
    @Relationship var entries: [Entry]
}
```

## 三、AI 层设计

### 3.1 两阶段 AI 调用

整个编纂流程分成两个阶段，各用不同的 system prompt：

**阶段一：对话采访**（流式，多轮）
- 模型：Claude 3.5 Sonnet（平衡速度和质量）
- 职责：扮演维基百科编辑搭档，主动追问，识别潜在词条
- 输入：用户消息 + 对话历史
- 输出：回复文本 + 结构化元数据（已识别的潜在词条列表）

**阶段二：词条生成**（单次，长输出）
- 模型：Claude 3.5 Sonnet 或 Claude 3 Opus（质量优先）
- 职责：基于对话全文，一次性生成所有词条的结构化 JSON
- 输入：完整对话记录 + 用户确认的词条列表
- 输出：完整的词条 JSON 数组（含信息框、正文、链接、分类、来源请求标注）

### 3.2 阶段一 System Prompt（对话采访）

```
你是「人间词条」的 AI 编辑搭档。你的职责是帮助用户把他们生命中的
人、物、地点、事件、时期编纂成维基百科品质的词条。

你的行为准则：
1. 你像一个温和但专业的维基百科资深编辑在做人物采访
2. 用户说什么你都认真倾听，然后追问关键的百科级细节：全名、时间、
   地点、因果关系、现状
3. 不要一次问太多问题，每次最多追问 1-2 个点
4. 在对话中持续识别可以成为独立词条的实体（人物、地点、物品、事件、
   时期），但不要每识别一个就打断用户，自然地积累
5. 当你认为某些实体值得成为独立词条时，主动和用户确认："我听到了
   X、Y、Z 这几件值得记录的事，你觉得这次要落实哪几篇？"
6. 在精不在多——一次对话落实 3-5 篇高质量词条比 10 篇空壳好
7. 当素材足够时主动说"我开始编纂了"

你每条回复必须附带一个 JSON 元数据块（用 <metadata> 标签包裹），
格式如下：
<metadata>
{
  "identified_entries": [
    {"title": "张薇", "type": "person", "confidence": "high"},
    {"title": "红烧肉", "type": "object", "confidence": "medium"}
  ],
  "ready_to_generate": false
}
</metadata>

- identified_entries：当前对话中已识别的所有潜在词条
- confidence：high = 信息已充足可生成 / medium = 还需补充 / low = 刚提到
- ready_to_generate：当所有确认的词条 confidence 都是 high 时设为 true
```

### 3.3 阶段二 System Prompt（词条生成）

```
你是「人间词条」的词条编纂引擎。基于用户和编辑搭档的对话记录，
生成维基百科品质的个人生命词条。

写作规范：
1. 使用维基百科的正式、客观、第三人称语气
2. 用对待帝王将相和文明遗产的庄重，对待每一个普通人的日常
3. "均未成功"比"我好想她"杀伤力大十倍——克制即力量
4. 正文中提到其他词条时用 [[词条标题]] 标记（蓝色链接）
5. 提到了但本次不生成的实体用 {{红色链接标题}} 标记（红色链接）
6. 对仅基于用户单一叙述、缺乏交叉验证的事实陈述标注 [来源请求]
7. 为每篇词条生成 2-4 个分类
8. AI 自动发现跨词条的隐藏分类（如"因为害怕而做的决定"）
9. 每篇词条的参考来源统一标注为"词条创建者口述，{日期}"

输出格式（严格 JSON）：
{
  "entries": [
    {
      "title": "张薇",
      "subtitle": "1941年—2019年",
      "type": "person",
      "infobox": {
        "fields": [
          {"key": "全名", "value": "张薇"},
          {"key": "出生", "value": "1941年 · 湖南长沙"},
          {"key": "逝世", "value": "2019年3月15日（77岁）"},
          {"key": "关系", "value": "词条创建者之外祖母"},
          {"key": "知名于", "value": "[[红烧肉]]配方（已失传）"}
        ]
      },
      "sections": [
        {
          "title": "生平",
          "content": "**张薇**（1941年—2019年），湖南长沙人...",
          "citations_needed": []
        },
        {
          "title": "烹饪",
          "content": "张薇以其独创的[[红烧肉]]配方闻名于家族内部。该配方据信源自其母亲口传，未有文字记录[来源请求]。...",
          "citations_needed": [
            {"text": "该配方据信源自其母亲口传", "reason": "仅基于创建者口述"}
          ]
        }
      ],
      "categories": ["家族成员", "湖南人物", "已故人物"],
      "see_also": ["红烧肉", "长沙岳麓区老房子", "春节家庭聚餐"],
      "cover_image_prompt": "Soft watercolor portrait of an elderly Chinese woman, warm kitchen background, gentle nostalgic lighting, side profile, muted warm tones"
    }
  ],
  "inter_links": [
    {"from": "张薇", "to": "红烧肉", "relation": "代表作"},
    {"from": "张薇", "to": "长沙岳麓区老房子", "relation": "居住地"},
    {"from": "红烧肉", "to": "张薇", "relation": "创作者"}
  ],
  "discovered_categories": [
    {"name": "已失传的家族技艺", "entries": ["红烧肉"]}
  ]
}
```

### 3.4 正文标记语法

词条正文使用简化 Markdown + 自定义标记：

| 标记 | 含义 | 渲染效果 |
|------|------|----------|
| `[[张薇]]` | 蓝色链接（目标词条存在） | 蓝色可点击文字 |
| `{{张薇之母}}` | 红色链接（目标词条不存在） | 红色可点击文字 |
| `[来源请求]` | 来源请求标注 | 灰色上标，可点击 |
| `**粗体**` | 标准 Markdown 粗体 | 首次出现词条标题时加粗 |
| `[1]` | 参考来源编号 | 上标数字，对应底部参考 |

### 3.5 AI 调用的客户端封装

```swift
class AIService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    // 阶段一：对话采访（流式）
    func streamConversation(
        messages: [ChatMessage],
        onText: @escaping (String) -> Void,
        onMetadata: @escaping (ConversationMetadata) -> Void
    ) async throws { ... }
    
    // 阶段二：词条生成（单次）
    func generateEntries(
        conversation: [ChatMessage],
        confirmedEntries: [String]  // 用户确认的词条标题列表
    ) async throws -> GenerationResult { ... }
    
    // 生成封面图 prompt → 调用图像 API
    func generateCoverImage(
        prompt: String
    ) async throws -> Data { ... }
}

struct ConversationMetadata: Codable {
    var identifiedEntries: [IdentifiedEntry]
    var readyToGenerate: Bool
}

struct GenerationResult: Codable {
    var entries: [GeneratedEntry]
    var interLinks: [InterLink]
    var discoveredCategories: [DiscoveredCategory]
}
```

## 四、前端实现方案（逐页面）

### 4.1 发现页（双列瀑布流）

**技术选型**：SwiftUI `LazyVGrid` + 两列 `columns` 布局，或使用第三方库 `WaterfallGrid`。

```swift
struct DiscoverView: View {
    @State private var entries: [PublicEntry] = []
    @State private var selectedFilter: EntryType? = nil
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            // 顶部筛选标签栏
            FilterTabBar(selected: $selectedFilter)
            
            // 双列瀑布流
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(filteredEntries) { entry in
                    EntryCard(entry: entry)
                        .onTapGesture {
                            // 跳转词条详情
                        }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}
```

**EntryCard（瀑布流卡片）核心组件**：
- 封面图区域：`AsyncImage` 加载，高度按图片比例自适应（瀑布流高度不等的来源）
- 标题：衬线体（`.font(.custom("NewYork-Bold", size: 16))`）
- 摘要：两行截断，正文中的 `[[]]` 标记渲染为蓝色文字
- 底部：作者头像 + 名字 + 点赞数

### 4.2 百科页（我的百科全书）

**页面结构**：`ScrollView` 内嵌多个板块。

```swift
struct EncyclopediaView: View {
    @Query private var entries: [Entry]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // 搜索框
                SearchBar()
                
                // 百科全书封面统计
                EncyclopediaHeader(
                    name: user.encyclopediaName,
                    entryCount: entries.count,
                    redLinkCount: totalRedLinks
                )
                
                // 历史上的今天
                TodayInHistorySection(entries: entriesToday)
                
                // 最近编辑
                RecentEditsSection(entries: recentEntries)
                
                // 等待编纂（红色链接）
                RedLinksSection(redLinks: allRedLinks)
                
                // 分类发现
                CategoriesSection(categories: discoveredCategories)
            }
            .navigationTitle("我的百科")
        }
    }
}
```

**搜索**：SwiftData 的 `#Predicate` 支持模糊匹配，对 title + sections.content 做全文搜索。

**"历史上的今天"逻辑**：扫描所有词条的 infobox 和正文中的日期字段，匹配今天的月/日。

### 4.3 词条详情页（核心渲染页）

这是产品视觉的核心，需要一个自定义的**词条渲染引擎**。

**渲染引擎的职责**：把结构化的 Entry 数据渲染成维基百科风格的页面。

```swift
struct EntryDetailView: View {
    let entry: Entry
    @Environment(\.modelContext) private var context
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                EntryTitleView(title: entry.title, subtitle: entry.subtitle)
                
                // 横幅提示（中立性争议等）
                if entry.hasNeutralityDispute {
                    DisputeBanner()
                }
                
                // 信息框
                InfoboxView(infobox: entry.infobox, type: entry.type)
                
                // 目录（章节数 > 3 时显示）
                if entry.sections.count > 3 {
                    TableOfContents(sections: entry.sections)
                }
                
                // 正文章节
                ForEach(entry.sections) { section in
                    SectionView(section: section, onLinkTap: handleLinkTap)
                }
                
                // 参见
                SeeAlsoSection(links: entry.seeAlso)
                
                // 参考来源
                ReferencesSection(entry: entry)
                
                // 分类标签
                CategoriesFooter(categories: entry.categories)
                
                // 编辑历史入口
                RevisionHistoryLink(entry: entry)
            }
            .padding(.horizontal, 16)
        }
    }
}
```

**正文渲染的关键：WikiTextRenderer**

正文中的 `[[]]`、`{{}}`、`[来源请求]` 标记需要解析成可交互的 SwiftUI 视图。

```swift
struct WikiTextRenderer: View {
    let text: String
    let onBlueLinkTap: (String) -> Void
    let onRedLinkTap: (String) -> Void
    let onCitationTap: (CitationNeeded) -> Void
    
    var body: some View {
        // 解析 text，把 [[xx]]、{{xx}}、[来源请求] 转换为
        // 带颜色和点击事件的 Text 片段拼接
        // 使用 Text concatenation: Text("正文") + Text("张薇").foregroundColor(.wikiBlue) + ...
    }
}
```

**实现方式**：用正则表达式解析标记，拆分成 `[TextSegment]` 数组，每个 segment 标记类型（普通/蓝链/红链/来源请求），然后用 `Text` 的 `+` 运算符拼接成富文本。

### 4.4 编纂页（AI 对话 + 词条草稿栏）

**页面结构**：三层叠加。

```swift
struct ComposeView: View {
    @State private var messages: [ChatMessage] = []
    @State private var draftEntries: [DraftEntry] = []
    @State private var isDraftBarExpanded = false
    @State private var phase: ComposePhase = .conversation
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            ComposeHeader(
                draftCount: draftEntries.count,
                onFinish: finishComposing
            )
            
            // 词条草稿栏（可展开/收起）
            DraftBar(
                entries: draftEntries,
                isExpanded: $isDraftBarExpanded
            )
            
            // 主区域：对话 或 编纂成果
            switch phase {
            case .conversation:
                ConversationView(
                    messages: $messages,
                    onSend: sendMessage
                )
            case .generating:
                GeneratingView(draftEntries: $draftEntries)
            case .result:
                ConstellationResultView(entries: draftEntries)
            }
        }
    }
}
```

**DraftBar（词条草稿栏）**：

```swift
struct DraftBar: View {
    let entries: [DraftEntry]
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 收起状态：窄横条
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("正在编纂 \(entries.count) 篇词条")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
            }
            
            // 展开状态：横向滚动的草稿卡片
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(entries) { draft in
                            DraftEntryCard(draft: draft)
                                .frame(width: UIScreen.main.bounds.width * 0.7)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 280)
                .background(Color(.systemGray6))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
```

**DraftEntryCard（草稿卡片）** 显示词条实时状态：
- 标题 + 类型标签
- 迷你信息框（已填字段显示黑色，未填字段显示灰色虚线占位）
- 正文预览（已生成的部分，灰色提示"等待更多信息"）
- 底部进度条（字段填充率）

**ConstellationResultView（编纂成果星座图）**：

```swift
struct ConstellationResultView: View {
    let entries: [DraftEntry]
    @State private var animationProgress: Double = 0
    
    var body: some View {
        ZStack {
            // 连接线（蓝色链接线）
            ForEach(interLinks) { link in
                LinkLine(from: link.fromPosition, to: link.toPosition)
                    .trim(from: 0, to: animationProgress)
                    .stroke(Color.wikiBlue, lineWidth: 1.5)
            }
            
            // 词条节点
            ForEach(entries) { entry in
                EntryNode(entry: entry)
                    .position(entry.layoutPosition)
                    .opacity(animationProgress)
                    .scaleEffect(animationProgress)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5)) {
                animationProgress = 1.0
            }
        }
    }
}
```

节点布局使用力导向算法简化版，或者预设好几种 3/4/5 节点的布局模板（三角形、菱形、五角形），根据词条数量选择。

### 4.5 图谱页

**技术选型**：`Canvas` + 手势（UIPanGestureRecognizer + UIPinchGestureRecognizer）。

所有词条是节点，词条间的 EntryLink 是边。节点颜色按 EntryType 区分。

```swift
struct GraphView: View {
    @Query private var entries: [Entry]
    @Query private var links: [EntryLink]
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        Canvas { context, size in
            // 绘制连接线
            for link in links {
                // 画线 from source.position to target.position
            }
            // 绘制节点
            for entry in entries {
                let color = colorForType(entry.type)
                let radius = radiusForEntry(entry) // 按链接数/字数加权
                // 画圆 + 标题文字
            }
        }
        .gesture(
            MagnificationGesture().onChanged { scale = $0 }
            .simultaneously(with: DragGesture().onChanged { offset = $0.translation })
        )
    }
}
```

节点位置初始化用力导向布局算法（ForceDirectedLayout），每次打开页面计算一次，缓存布局结果。

黑客松 MVP 可以用简化版：节点按创建时间排列成螺旋形或同心圆，不做力导向。

## 五、图像生成

### 5.1 封面插画生成

每篇词条可以有一张封面插画，用于信息框顶部和发现页瀑布流卡片。

**调用时机**：词条生成完成后（阶段二），后台异步调用图像 API 生成。不阻塞词条展示。

**技术选型**（按优先级）：
1. **即梦 API / Seedream**：国内访问快，中文 prompt 友好
2. **DALL-E 3 API**：质量高，英文 prompt
3. **备选 — 不生图**：黑客松时如果图像 API 不稳定，直接用 SF Symbols 大图标 + 渐变背景色作为封面占位

**Prompt 模板**（由阶段二 AI 生成，存入 `coverImagePrompt` 字段）：

```
风格统一约束前缀：
"Soft watercolor illustration, muted warm tones, gentle lighting, 
minimalist composition, no text, no words — "

+ 词条特定描述（由 AI 生成）：
"an elderly Chinese woman's hands preparing braised pork belly 
in a sunlit kitchen"
```

风格统一是关键——所有词条的插画必须是同一种柔和水彩风，这样发现页瀑布流看起来才有整体美感。

### 5.2 图像缓存

```swift
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    // 内存缓存 + 本地文件缓存双层
    func image(for entryId: UUID) async -> UIImage? { ... }
    func store(_ image: UIImage, for entryId: UUID) { ... }
}
```

## 六、分享截图生成

### 6.1 截图渲染

词条详情页点击"分享"时，用 `ImageRenderer`（iOS 16+）把一个自定义的 SwiftUI 视图渲染成 `UIImage`。

```swift
struct ShareableEntryView: View {
    let entry: Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：来源标注
            Text("来自 \(entry.author?.name ?? "") 的百科全书")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 词条标题
            Text(entry.title)
                .font(.custom("NewYork-Bold", size: 28))
            
            // 信息框
            InfoboxView(infobox: entry.infobox, type: entry.type)
            
            // 正文前两段
            ForEach(entry.sections.prefix(2)) { section in
                SectionView(section: section)
            }
            
            // 分类
            CategoriesFooter(categories: entry.categories)
            
            Divider()
            
            // 底部品牌栏
            HStack {
                Text("人间词条")
                    .font(.custom("NewYork-Bold", size: 14))
                Spacer()
                Text("每个普通人的一生，都值得一整座维基百科。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(.white)
        .frame(width: 375) // 固定宽度保证截图一致
    }
}

// 生成截图
func generateShareImage(entry: Entry) -> UIImage? {
    let renderer = ImageRenderer(content: ShareableEntryView(entry: entry))
    renderer.scale = UIScreen.main.scale
    return renderer.uiImage
}
```

### 6.2 分享调用

```swift
func shareEntry(_ entry: Entry) {
    guard let image = generateShareImage(entry: entry) else { return }
    let activityVC = UIActivityViewController(
        activityItems: [image],
        applicationActivities: nil
    )
    // present activityVC
}
```

## 七、关键技术难点 & 解决方案

### 7.1 正文标记解析与富文本渲染

**难点**：SwiftUI 原生 `Text` 不支持内联的可点击链接。

**方案 A（推荐）**：用 `AttributedString` + `Text` 拼接。iOS 15+ 的 `AttributedString` 支持 `.link` 属性，配合 `.environment(\.openURL)` 自定义处理点击。将 `[[张薇]]` 解析为带 `wikilink://张薇` 的 link attribute。

```swift
func parseWikiText(_ raw: String) -> AttributedString {
    var result = AttributedString()
    // 正则匹配 [[...]], {{...}}, [来源请求]
    // 蓝色链接 → .foregroundColor(.wikiBlue) + .link(URL("wikilink://title"))
    // 红色链接 → .foregroundColor(.wikiRed) + .link(URL("redlink://title"))
    // 来源请求 → .foregroundColor(.gray) + .font(.caption) + .baselineOffset(6)
    return result
}
```

**方案 B（备选）**：用 `WKWebView` 渲染 HTML。优点是排版灵活度高，缺点是和 SwiftUI 交互复杂，性能稍差。

### 7.2 对话中实时更新草稿卡片

**难点**：AI 回复是流式的，需要实时解析 `<metadata>` 标签更新草稿栏。

**方案**：Claude API 的流式响应（SSE）逐 token 返回。客户端维护一个 buffer，每次收到 token 就追加到 buffer。用正则持续检测 buffer 中是否出现完整的 `<metadata>...</metadata>` 块。一旦检测到，解析 JSON 并更新 `draftEntries` 状态，触发草稿栏 UI 刷新。

```swift
class StreamParser {
    private var buffer = ""
    
    func append(_ token: String) -> ConversationMetadata? {
        buffer += token
        if let range = buffer.range(of: #"<metadata>(.*?)</metadata>"#, 
                                     options: .regularExpression) {
            let json = String(buffer[range])
                .replacingOccurrences(of: "<metadata>", with: "")
                .replacingOccurrences(of: "</metadata>", with: "")
            buffer = String(buffer[range.upperBound...])
            return try? JSONDecoder().decode(ConversationMetadata.self, 
                                             from: json.data(using: .utf8)!)
        }
        return nil
    }
}
```

### 7.3 星座图节点布局

**难点**：3-5 个节点 + 若干连接线，需要看起来美观且不重叠。

**方案**：预设布局模板，不做实时物理模拟。

```swift
enum ConstellationLayout {
    static func positions(for count: Int, in size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let radius = min(size.width, size.height) * 0.3
        
        // 节点均匀分布在圆周上，第一个节点在顶部
        return (0..<count).map { i in
            let angle = -CGFloat.pi/2 + CGFloat(i) * 2 * .pi / CGFloat(count)
            return CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
    }
}
```

### 7.4 维基百科色值的精确复刻

关键色值硬编码为 Color extension：

```swift
extension Color {
    static let wikiBlue = Color(hex: "#0645AD")      // 蓝色链接
    static let wikiRed = Color(hex: "#BA0000")        // 红色链接
    static let wikiText = Color(hex: "#202122")       // 正文
    static let wikiGray = Color(hex: "#72777D")       // 辅助文字
    static let wikiInfobox = Color(hex: "#F8F9FA")    // 信息框背景
    static let wikiInfoboxBorder = Color(hex: "#A2A9B1") // 信息框边框
    static let wikiBanner = Color(hex: "#FEF6E7")     // 横幅黄
    static let wikiAccent = Color(hex: "#3366CC")      // 系统蓝
}
```

## 八、黑客松 MVP 裁剪方案

两天两夜时间有限，按优先级砍：

### 必须做（核心体验链路）

| 功能 | 说明 | 预估工时 |
|------|------|----------|
| 词条详情页渲染 | 信息框 + 正文 + 蓝色链接 + 分类标签 | 4h |
| AI 对话 → 词条生成 | 两阶段 prompt + JSON 解析 | 4h |
| 编纂页对话 UI | 对话界面 + 草稿栏（简化版） | 3h |
| 编纂成果星座图 | 节点 + 连接线 + 淡入动画 | 3h |
| 百科页 | 词条列表 + 搜索 + 红色链接列表 | 2h |
| 蓝色链接跳转 | 点击蓝色链接 → 打开目标词条 | 1h |
| Tab 骨架 | 5 个 tab + 导航结构 | 1h |

**合计约 18 小时**，两个人分工的话一天可以完成核心链路。

### 尽量做（加分项）

| 功能 | 说明 | 预估工时 |
|------|------|----------|
| 发现页双列瀑布流 | 预置 mock 数据的公开词条浏览 | 3h |
| 封面插画生成 | 调用图像 API 为词条生成水彩插画 | 2h |
| 分享截图 | 渲染词条为长图 + 分享 sheet | 2h |
| 图谱页 | Canvas 绘制简化版知识图谱 | 3h |
| \[来源请求\] 交互 | 点击后弹出反思浮层 | 1h |
| 历史上的今天 | 百科页板块 | 1h |

### 可以砍（路演口头描述即可）

- Supabase 后端 / 用户注册登录
- 社交关注/粉丝体系
- 跨百科链接（"我在别人的百科全书里"）
- 编辑历史 / 版本对比
- 分类自动发现（AI 功能已有，UI 可简化为列表）
- 消歧义页面
- 中立性争议横幅
- 深夜模式

### MVP 的 mock 数据策略

发现页的信息流需要内容，但没时间做真的后端和用户体系。解决方案：

**提前用 AI 批量生成 15-20 篇高质量词条**，覆盖不同类型（人物、地点、物品、事件、时期），存成 JSON 文件打包进 App。这些词条就是发现页的预置内容。

可以用真实但脱敏的素材——比如你自己的记忆、队友的记忆、甚至文学作品里的场景用维基百科语气改写。关键是让评委刷发现页的时候，每一张卡片都是一篇能让人停下来细看的词条。

```
MockData/
├── entries.json          // 15-20 篇预置词条
├── users.json            // 5-8 个虚拟用户
└── images/               // 预生成的封面插画
    ├── grandmother.png
    ├── old_house.png
    └── ...
```

## 九、项目文件结构

```
Lifepedia/
├── LifepediaApp.swift                  // App 入口
├── Models/
│   ├── Entry.swift                     // 词条模型
│   ├── EntryLink.swift                 // 链接模型
│   ├── Conversation.swift              // 对话模型
│   ├── Revision.swift                  // 修订模型
│   └── User.swift                      // 用户模型
├── Services/
│   ├── AIService.swift                 // Claude API 封装
│   ├── ImageGenerationService.swift    // 图像生成 API
│   ├── WikiTextParser.swift            // 正文标记解析器
│   ├── ImageCache.swift                // 图片缓存
│   └── MockDataLoader.swift            // 加载预置 mock 数据
├── Views/
│   ├── MainTabView.swift               // 底部 Tab 栏
│   ├── Discover/
│   │   ├── DiscoverView.swift          // 发现页（双列瀑布流）
│   │   └── EntryCard.swift             // 瀑布流卡片
│   ├── Encyclopedia/
│   │   ├── EncyclopediaView.swift      // 百科主页
│   │   ├── TodaySection.swift          // 历史上的今天
│   │   ├── RedLinksSection.swift       // 待编纂
│   │   └── CategoriesSection.swift     // 分类发现
│   ├── Entry/
│   │   ├── EntryDetailView.swift       // 词条详情页
│   │   ├── InfoboxView.swift           // 信息框组件
│   │   ├── WikiTextRenderer.swift      // 富文本渲染
│   │   ├── SectionView.swift           // 章节组件
│   │   └── ShareableEntryView.swift    // 分享截图视图
│   ├── Compose/
│   │   ├── ComposeView.swift           // 编纂主页面
│   │   ├── ConversationView.swift      // 对话区域
│   │   ├── DraftBar.swift              // 词条草稿栏
│   │   ├── DraftEntryCard.swift        // 草稿卡片
│   │   └── ConstellationView.swift     // 编纂成果星座图
│   ├── Graph/
│   │   └── GraphView.swift             // 知识图谱
│   └── Profile/
│       └── ProfileView.swift           // 我的页面
├── Theme/
│   ├── WikiColors.swift                // 维基百科色值
│   ├── WikiFonts.swift                 // 字体定义
│   └── WikiStyles.swift                // 公共样式
├── Prompts/
│   ├── conversation_system.txt         // 阶段一 system prompt
│   └── generation_system.txt           // 阶段二 system prompt
├── MockData/
│   ├── entries.json                    // 预置词条
│   ├── users.json                      // 虚拟用户
│   └── images/                         // 预置插画
└── Assets.xcassets/                    // 图片资源
```

## 十、开发分工建议（两人团队）

### 人员 A：前端渲染 + 页面

- Day 1 上午：Tab 骨架 + 词条详情页（标题、信息框、正文基础渲染）
- Day 1 下午：WikiTextParser（蓝色链接、红色链接解析渲染）+ 蓝色链接跳转
- Day 1 晚上：百科页 + 发现页双列瀑布流
- Day 2 上午：分享截图 + 图谱页
- Day 2 下午：全局 UI 打磨 + 路演准备

### 人员 B：AI + 数据 + 编纂流程

- Day 1 上午：SwiftData 模型定义 + Mock 数据加载 + AIService 框架
- Day 1 下午：两阶段 prompt 调试（对话采访 + 词条生成 JSON）
- Day 1 晚上：编纂页对话 UI + 草稿栏 + 流式响应解析
- Day 2 上午：编纂成果星座图 + 词条入库逻辑
- Day 2 下午：封面插画生成 + 端到端联调 + 路演准备

### 路演前检查清单

- [ ] 核心链路：打开 App → 编纂 → 对话 → 生成词条 → 看到星座图 → 收录 → 在百科页看到 → 点蓝色链接跳转
- [ ] 发现页有足够多的预置词条（15+）且视觉好看
- [ ] 词条详情页的维基百科视觉精确复刻
- [ ] 至少有一张 AI 生成的封面插画可以展示
- [ ] 分享截图功能可用
- [ ] 网络不稳定的兜底方案（预置一组已生成好的词条，手动切换展示）
