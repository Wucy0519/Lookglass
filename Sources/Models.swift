import Foundation

enum StudioPage: String, CaseIterable, Identifiable {
    case design, shop, forum, atelier, motion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .design: "造型"
        case .shop: "寻购"
        case .forum: "社区"
        case .atelier: "工坊"
        case .motion: "动图"
        }
    }

    var symbol: String {
        switch self {
        case .design: "tshirt"
        case .shop: "bag"
        case .forum: "text.bubble"
        case .atelier: "ruler"
        case .motion: "film"
        }
    }
}

enum Wardrobe {
    static let categories = ["整身搭配", "上衣", "衬衫", "外套", "连衣裙", "半裙", "裤装", "套装", "针织", "鞋履", "包袋", "配饰"]
}

enum WearScene: String, CaseIterable, Identifiable {
    case shopping, meeting, commute, cafe, dinner, street, travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shopping: "逛街"
        case .meeting: "开会"
        case .commute: "通勤"
        case .cafe: "咖啡店"
        case .dinner: "晚宴"
        case .street: "街拍"
        case .travel: "旅途"
        }
    }

    var detail: String {
        switch self {
        case .shopping: "在商店街里走动，衣服的正面和侧面都能看见。"
        case .meeting: "走进会议室坐下，看上身和整体是否得体。"
        case .commute: "在街头走向车站，看走路时的轮廓。"
        case .cafe: "在咖啡桌边坐下、起身，看日常穿着。"
        case .dinner: "在暖色餐厅里缓慢走动，看礼服感。"
        case .street: "对着街口停留，像一组街拍。"
        case .travel: "在车站或步道上赶路，看行动时的衣服。"
        }
    }

    var direction: String {
        switch self {
        case .shopping:
            "walking along a sunny shopping street, turning slightly so the front and side of the outfit are visible"
        case .meeting:
            "walking into a bright meeting room and sitting down at the table, calm professional movement"
        case .commute:
            "walking along a city sidewalk toward a station, natural stride, outfit readable"
        case .cafe:
            "sitting down at a cafe table and then standing up, everyday pace"
        case .dinner:
            "walking slowly through a warm restaurant, formal evening light"
        case .street:
            "pausing at a street corner for a fashion photograph, small pose change"
        case .travel:
            "walking through a station or travel path with a light bag, clothes moving naturally"
        }
    }
}

struct DesignStep: Codable, Equatable, Identifiable {
    var id: UUID
    var filename: String
    var prompt: String
    var createdAt: Date
    var kind: String
}

struct DesignHistory: Codable, Equatable {
    var steps: [DesignStep]
    var cursor: Int

    var current: DesignStep {
        steps[min(max(cursor, 0), max(steps.count - 1, 0))]
    }

    var canUndo: Bool { cursor > 0 && steps.count > 1 }
    var canRedo: Bool { cursor + 1 < steps.count }

    mutating func sanitize() {
        if steps.isEmpty { return }
        cursor = min(max(cursor, 0), steps.count - 1)
    }

    mutating func push(_ step: DesignStep) {
        if cursor + 1 < steps.count {
            steps.removeSubrange((cursor + 1)...)
        }
        steps.append(step)
        cursor = steps.count - 1
    }

    mutating func undo() {
        if canUndo { cursor -= 1 }
    }

    mutating func redo() {
        if canRedo { cursor += 1 }
    }

    mutating func jump(_ index: Int) {
        guard steps.indices.contains(index) else { return }
        cursor = index
    }
}

struct LookProject: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var category: String
    var note: String
    var searchText: String
    var references: [String]
    var history: DesignHistory

    static func make(name: String, filename: String) -> LookProject {
        let step = DesignStep(id: UUID(), filename: filename, prompt: "原图", createdAt: Date(), kind: "原图")
        return LookProject(
            id: UUID(),
            name: name,
            createdAt: Date(),
            category: "整身搭配",
            note: "",
            searchText: "",
            references: [],
            history: DesignHistory(steps: [step], cursor: 0)
        )
    }
}

struct ForumReply: Codable, Equatable, Identifiable {
    var id: UUID
    var author: String
    var body: String
    var createdAt: Date
}

struct CommunityPost: Codable, Equatable, Identifiable {
    var id: UUID
    var lookID: UUID?
    var title: String
    var body: String
    var imageFilename: String?
    var author: String
    var createdAt: Date
    var replies: [ForumReply]
}

struct ProductionBrief: Codable, Equatable, Identifiable {
    var id: UUID
    var lookID: UUID?
    var title: String
    var spec: String
    var quantity: Int
    var budget: String
    var contact: String
    var imageFilename: String?
    var status: String
    var detail: String
    var createdAt: Date
}

struct MotionClip: Codable, Equatable, Identifiable {
    var id: UUID
    var lookID: UUID?
    var scene: String
    var prompt: String
    var videoFilename: String?
    var gifFilename: String?
    var createdAt: Date
}

struct LibraryFile: Codable, Equatable {
    var schema: Int
    var looks: [LookProject]
    var activeID: UUID
    var posts: [CommunityPost]
    var briefs: [ProductionBrief]
    var clips: [MotionClip]

    mutating func sanitize() {
        for index in looks.indices {
            looks[index].history.sanitize()
        }
        looks.removeAll { $0.history.steps.isEmpty }
        if looks.isEmpty { return }
        if !looks.contains(where: { $0.id == activeID }) {
            activeID = looks[0].id
        }
    }
}

struct Settings: Codable, Equatable {
    var imageBase: String
    var imageKey: String
    var imageModel: String
    var imagePath: String
    var imageStyle: String
    var imageAuth: String
    var imageSize: String

    var videoBase: String
    var videoKey: String
    var videoModel: String
    var videoCreatePath: String
    var videoStatusPath: String
    var videoStyle: String
    var videoAuth: String
    var videoSeconds: Int

    var searchMode: String
    var searchBase: String
    var searchKey: String
    var searchAuth: String

    var chatBase: String
    var chatKey: String
    var chatModel: String
    var useChatForQuery: Bool

    var forumURL: String
    var atelierURL: String
    var authorName: String
    var seenGuide: Bool

    static let initial = Settings(
        imageBase: "https://dashscope.aliyuncs.com/api/v1",
        imageKey: "",
        imageModel: "qwen-image-2.0-pro",
        imagePath: "/services/aigc/multimodal-generation/generation",
        imageStyle: "qwen",
        imageAuth: "bearer",
        imageSize: "1024*1536",
        videoBase: "https://dashscope.aliyuncs.com/api/v1",
        videoKey: "",
        videoModel: "wan2.6-i2v-flash",
        videoCreatePath: "/services/aigc/video-generation/video-synthesis",
        videoStatusPath: "/tasks/{id}",
        videoStyle: "wan",
        videoAuth: "bearer",
        videoSeconds: 5,
        searchMode: "web",
        searchBase: "",
        searchKey: "",
        searchAuth: "bearer",
        chatBase: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        chatKey: "",
        chatModel: "qwen-vl-plus",
        useChatForQuery: false,
        forumURL: "",
        atelierURL: "",
        authorName: "我",
        seenGuide: false
    )

    init(
        imageBase: String, imageKey: String, imageModel: String, imagePath: String, imageStyle: String, imageAuth: String, imageSize: String,
        videoBase: String, videoKey: String, videoModel: String, videoCreatePath: String, videoStatusPath: String, videoStyle: String, videoAuth: String, videoSeconds: Int,
        searchMode: String, searchBase: String, searchKey: String, searchAuth: String,
        chatBase: String, chatKey: String, chatModel: String, useChatForQuery: Bool,
        forumURL: String, atelierURL: String, authorName: String, seenGuide: Bool
    ) {
        self.imageBase = imageBase
        self.imageKey = imageKey
        self.imageModel = imageModel
        self.imagePath = imagePath
        self.imageStyle = imageStyle
        self.imageAuth = imageAuth
        self.imageSize = imageSize
        self.videoBase = videoBase
        self.videoKey = videoKey
        self.videoModel = videoModel
        self.videoCreatePath = videoCreatePath
        self.videoStatusPath = videoStatusPath
        self.videoStyle = videoStyle
        self.videoAuth = videoAuth
        self.videoSeconds = videoSeconds
        self.searchMode = searchMode
        self.searchBase = searchBase
        self.searchKey = searchKey
        self.searchAuth = searchAuth
        self.chatBase = chatBase
        self.chatKey = chatKey
        self.chatModel = chatModel
        self.useChatForQuery = useChatForQuery
        self.forumURL = forumURL
        self.atelierURL = atelierURL
        self.authorName = authorName
        self.seenGuide = seenGuide
    }

    init(from decoder: Decoder) throws {
        let base = Settings.initial
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys, _ fallback: String) -> String {
            (try? container.decodeIfPresent(String.self, forKey: key)) ?? fallback
        }
        imageBase = text(.imageBase, base.imageBase)
        imageKey = text(.imageKey, base.imageKey)
        imageModel = text(.imageModel, base.imageModel)
        imagePath = text(.imagePath, base.imagePath)
        imageStyle = text(.imageStyle, base.imageStyle)
        imageAuth = text(.imageAuth, base.imageAuth)
        imageSize = text(.imageSize, base.imageSize)
        videoBase = text(.videoBase, base.videoBase)
        videoKey = text(.videoKey, base.videoKey)
        videoModel = text(.videoModel, base.videoModel)
        videoCreatePath = text(.videoCreatePath, base.videoCreatePath)
        videoStatusPath = text(.videoStatusPath, base.videoStatusPath)
        videoStyle = text(.videoStyle, base.videoStyle)
        videoAuth = text(.videoAuth, base.videoAuth)
        videoSeconds = (try? container.decodeIfPresent(Int.self, forKey: .videoSeconds)) ?? base.videoSeconds
        searchMode = text(.searchMode, base.searchMode)
        searchBase = text(.searchBase, base.searchBase)
        searchKey = text(.searchKey, base.searchKey)
        searchAuth = text(.searchAuth, base.searchAuth)
        chatBase = text(.chatBase, base.chatBase)
        chatKey = text(.chatKey, base.chatKey)
        chatModel = text(.chatModel, base.chatModel)
        useChatForQuery = (try? container.decodeIfPresent(Bool.self, forKey: .useChatForQuery)) ?? base.useChatForQuery
        forumURL = text(.forumURL, base.forumURL)
        atelierURL = text(.atelierURL, base.atelierURL)
        authorName = text(.authorName, base.authorName)
        seenGuide = (try? container.decodeIfPresent(Bool.self, forKey: .seenGuide)) ?? base.seenGuide
        if !["openai", "json", "qwen"].contains(imageStyle) {
            imageStyle = base.imageStyle
            imageBase = base.imageBase
            imagePath = base.imagePath
            imageModel = base.imageModel
            imageSize = base.imageSize
            imageAuth = base.imageAuth
            imageKey = ""
            chatBase = base.chatBase
            chatModel = base.chatModel
            chatKey = ""
        }
        if !["generic", "kling", "openai", "wan"].contains(videoStyle) {
            videoStyle = base.videoStyle
            videoBase = base.videoBase
            videoCreatePath = base.videoCreatePath
            videoStatusPath = base.videoStatusPath
            videoModel = base.videoModel
            videoAuth = base.videoAuth
            videoKey = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imageBase, forKey: .imageBase)
        try container.encode(imageKey, forKey: .imageKey)
        try container.encode(imageModel, forKey: .imageModel)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(imageStyle, forKey: .imageStyle)
        try container.encode(imageAuth, forKey: .imageAuth)
        try container.encode(imageSize, forKey: .imageSize)
        try container.encode(videoBase, forKey: .videoBase)
        try container.encode(videoKey, forKey: .videoKey)
        try container.encode(videoModel, forKey: .videoModel)
        try container.encode(videoCreatePath, forKey: .videoCreatePath)
        try container.encode(videoStatusPath, forKey: .videoStatusPath)
        try container.encode(videoStyle, forKey: .videoStyle)
        try container.encode(videoAuth, forKey: .videoAuth)
        try container.encode(videoSeconds, forKey: .videoSeconds)
        try container.encode(searchMode, forKey: .searchMode)
        try container.encode(searchBase, forKey: .searchBase)
        try container.encode(searchKey, forKey: .searchKey)
        try container.encode(searchAuth, forKey: .searchAuth)
        try container.encode(chatBase, forKey: .chatBase)
        try container.encode(chatKey, forKey: .chatKey)
        try container.encode(chatModel, forKey: .chatModel)
        try container.encode(useChatForQuery, forKey: .useChatForQuery)
        try container.encode(forumURL, forKey: .forumURL)
        try container.encode(atelierURL, forKey: .atelierURL)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(seenGuide, forKey: .seenGuide)
    }

    enum CodingKeys: String, CodingKey {
        case imageBase, imageKey, imageModel, imagePath, imageStyle, imageAuth, imageSize
        case videoBase, videoKey, videoModel, videoCreatePath, videoStatusPath, videoStyle, videoAuth, videoSeconds
        case searchMode, searchBase, searchKey, searchAuth
        case chatBase, chatKey, chatModel, useChatForQuery
        case forumURL, atelierURL, authorName, seenGuide
    }
}

struct ProductHit: Identifiable, Hashable {
    var id: String
    var platform: String
    var title: String
    var price: String
    var shop: String
    var url: URL
    var imageURL: URL?
    var kind: String
}

enum Market: String, CaseIterable, Identifiable {
    case taobao, tmall, jd, pdd, vip, amazonCN, amazon, farfetch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taobao: "淘宝"
        case .tmall: "天猫"
        case .jd: "京东"
        case .pdd: "拼多多"
        case .vip: "唯品会"
        case .amazonCN: "亚马逊中国"
        case .amazon: "Amazon"
        case .farfetch: "FARFETCH"
        }
    }

    func searchURL(_ query: String) -> URL {
        let q = query.isEmpty ? "衣服" : query
        switch self {
        case .taobao:
            return APIURL.page("https://s.taobao.com/search", [URLQueryItem(name: "q", value: q)])
        case .tmall:
            return APIURL.page("https://list.tmall.com/search_product.htm", [URLQueryItem(name: "q", value: q)])
        case .jd:
            return APIURL.page("https://search.jd.com/Search", [
                URLQueryItem(name: "keyword", value: q),
                URLQueryItem(name: "enc", value: "utf-8")
            ])
        case .pdd:
            return APIURL.page("https://mobile.yangkeduo.com/search_result.html", [URLQueryItem(name: "search_key", value: q)])
        case .vip:
            return APIURL.page("https://category.vip.com/suggest.php", [URLQueryItem(name: "keyword", value: q)])
        case .amazonCN:
            return APIURL.page("https://www.amazon.cn/s", [URLQueryItem(name: "k", value: q)])
        case .amazon:
            return APIURL.page("https://www.amazon.com/s", [URLQueryItem(name: "k", value: q)])
        case .farfetch:
            return APIURL.page("https://www.farfetch.com/cn/shopping/women/search/items.aspx", [URLQueryItem(name: "q", value: q)])
        }
    }

    static func links(for query: String) -> [ProductHit] {
        allCases.map { market in
            ProductHit(
                id: "market-\(market.rawValue)",
                platform: market.title,
                title: "在\(market.title)搜索「\(query.isEmpty ? "衣服" : query)」",
                price: "",
                shop: "打开平台搜索",
                url: market.searchURL(query),
                imageURL: nil,
                kind: "平台"
            )
        }
    }

    static func name(for host: String) -> String {
        let host = host.lowercased()
        if host.contains("taobao") || host.contains("tmall") { return "淘宝" }
        if host.contains("jd.com") || host.contains("jd.hk") { return "京东" }
        if host.contains("yangkeduo") || host.contains("pinduoduo") { return "拼多多" }
        if host.contains("vip.com") { return "唯品会" }
        if host.contains("amazon.") { return "亚马逊" }
        if host.contains("farfetch") { return "FARFETCH" }
        if host.contains("dewu") || host.contains("poizon") { return "得物" }
        if host.contains("xiaohongshu") { return "小红书" }
        if host.contains("bing.com") { return "必应" }
        if host.contains("baidu.com") { return "百度" }
        return "网页"
    }
}

enum APIURL {
    static func join(_ base: String, _ path: String) -> String {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.hasPrefix("http://") || trimmedPath.hasPrefix("https://") {
            return trimmedPath
        }
        let suffix = trimmedPath.hasPrefix("/") ? trimmedPath : "/" + trimmedPath
        return trimmedBase + suffix
    }

    static func page(_ base: String, _ items: [URLQueryItem]) -> URL {
        var components = URLComponents(string: base) ?? URLComponents()
        components.queryItems = items
        return components.url ?? URL(string: "https://www.bing.com/search?q=clothes")!
    }
}

enum OutfitQuery {
    static let lexicon = [
        "米白色", "燕麦色", "奶油色", "卡其色", "驼色", "藏青色", "酒红色", "黑色", "白色", "灰色", "红色", "绿色", "蓝色", "粉色", "紫色", "棕色", "黄色", "杏色", "米色", "咖色",
        "米白", "燕麦", "奶油", "卡其", "藏青", "酒红",
        "亚麻", "真丝", "丝绸", "羊毛", "羊绒", "牛仔", "皮革", "针织", "雪纺", "棉麻", "纯棉",
        "西装外套", "连衣裙", "半身裙", "风衣", "大衣", "羽绒服", "针织衫", "开衫", "卫衣", "衬衫", "西装", "夹克", "马甲", "旗袍", "阔腿裤", "直筒裤", "西裤", "短裤", "长裙", "半裙", "吊带", "背心", "T恤",
        "新中式", "极简", "通勤", "法式", "复古", "街头", "学院", "度假", "礼服", "运动", "工装", "宽松", "修身", "oversize", "短款", "中长款", "长款",
        "外套", "上衣", "裤装", "套装", "鞋", "包", "配饰"
    ]

    static func make(note: String, category: String) -> String {
        let found = terms(in: note)
        var parts = found
        if category != "整身搭配" && !parts.contains(where: { $0.contains(category) || category.contains($0) }) {
            parts.append(category)
        }
        if parts.isEmpty {
            let cleaned = note
                .replacingOccurrences(of: "[\\p{P}\\p{S}]+", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { return category == "整身搭配" ? "衣服" : category }
            return String(cleaned.prefix(32))
        }
        return parts.joined(separator: " ")
    }

    static func terms(in note: String) -> [String] {
        let sorted = lexicon.sorted { $0.count > $1.count }
        var found: [String] = []
        var index = note.startIndex
        while index < note.endIndex {
            var matched: String?
            for word in sorted where note[index...].hasPrefix(word) {
                matched = word
                break
            }
            if let matched {
                if !found.contains(matched) { found.append(matched) }
                index = note.index(index, offsetBy: matched.count)
            } else {
                index = note.index(after: index)
            }
        }
        return found
    }
}

enum PromptText {
    static func design(note: String, category: String, referenceCount: Int) -> String {
        let request = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let brief = request.isEmpty ? "按照参考图更换人物身上的衣服。" : request
        let refs = referenceCount > 0 ? "后面 \(referenceCount) 张是服装参考图。参考图如果里有人，只借鉴衣服的版型、颜色、面料和细节，不要换成参考图里的人。" : "没有另外的参考图，只按文字改衣服。"
        return """
        编辑第一张人物图的服装。保持人物的脸、发型、体态、姿势和背景不变，只更换或增加衣服。
        目标品类：\(category)。
        设计要求：\(brief)。
        \(refs)
        输出一张完整、写实的人物图，衣服要像可以购买的成衣。不要文字，不要水印，不要拼贴边框。
        """
    }

    static func motion(scene: WearScene, outfit: String) -> String {
        let clothes = outfit.trimmingCharacters(in: .whitespacesAndNewlines)
        let keep = clothes.isEmpty ? "Keep the exact outfit already worn in the image." : "Keep this outfit unchanged: \(clothes)."
        return """
        The same person from the image, identity, face, and outfit unchanged. \(scene.direction).
        \(keep)
        Natural human motion, stable camera, the clothes stay fully readable, photorealistic fashion film, no text, no watermark.
        """
    }

    static func openAISeconds(_ value: Int) -> String {
        let allowed = [4, 8, 12]
        let best = allowed.min { abs($0 - value) < abs($1 - value) } ?? 4
        return String(best)
    }
}

enum ImagePayload: Equatable {
    case bytes(Data)
    case remote(URL)
}

struct VideoJob {
    var id: String?
    var phase: VideoPhase
    var videoURL: URL?
    var message: String?
}

enum VideoPhase {
    case pending, done, failed
}

struct ProductDraft: Equatable {
    var title: String
    var price: String
    var url: String
    var image: String
    var platform: String
    var shop: String
}

enum PayloadParse {
    static func image(from data: Data) throws -> ImagePayload {
        if let magic = imageMagic(data) { return .bytes(magic) }
        let json = try jsonObject(data)
        if let encoded = firstString(in: json, keys: ["b64_json", "base64", "image_base64", "b64"]),
           let bytes = Data(base64Encoded: encoded) {
            return .bytes(bytes)
        }
        if let embedded = embeddedImage(json) {
            return .bytes(embedded)
        }
        if let urlText = preferredURL(in: json, keys: ["url", "image_url", "imageUrl", "output_url", "image"], images: true),
           let url = URL(string: urlText) {
            return .remote(url)
        }
        if let message = apiMessage(from: json) {
            throw StudioError.message(message)
        }
        throw StudioError.message("图像接口没有返回图片")
    }

    static func videoJob(from data: Data) throws -> VideoJob {
        if isVideo(data) {
            return VideoJob(id: nil, phase: .done, videoURL: nil, message: nil)
        }
        let json = try jsonObject(data)
        let id = firstString(in: json, keys: ["task_id", "taskId", "video_id", "id"])
        let statuses = strings(in: json, keys: ["task_status", "status", "state"]).map { $0.lowercased() }
        let urlText = preferredURL(in: json, keys: ["video_url", "videoUrl", "download_url", "output_url", "url"], images: false)
        let pending: Set<String> = ["queued", "queue", "processing", "submitted", "running", "in_progress", "pending", "starting", "created"]
        let done: Set<String> = ["succeed", "succeeded", "success", "completed", "complete", "done", "finished", "ready"]
        let failed: Set<String> = ["fail", "failed", "error", "cancelled", "canceled", "unknown"]
        let hasPending = statuses.contains { pending.contains($0) }
        let hasDone = statuses.contains { done.contains($0) }
        let hasFailed = statuses.contains { failed.contains($0) }
        let videoURL = urlText.flatMap(URL.init(string:))
        let phase: VideoPhase
        if hasPending {
            phase = .pending
        } else if videoURL != nil || hasDone || isVideo(data) {
            phase = .done
        } else if hasFailed {
            phase = .failed
        } else if id != nil {
            phase = .pending
        } else {
            phase = .failed
        }
        let message = apiMessage(from: json)
        if phase == .failed {
            return VideoJob(id: id, phase: .failed, videoURL: videoURL, message: message ?? "视频生成失败")
        }
        return VideoJob(id: id, phase: phase, videoURL: videoURL, message: message)
    }

    static func products(from data: Data) -> [ProductDraft] {
        guard let json = try? jsonObject(data) else { return [] }
        let arrays = arrayValues(in: json, keys: ["shopping_results", "organic_results", "items", "products", "data"])
        var drafts: [ProductDraft] = []
        for item in arrays {
            guard let dict = item as? [String: Any] else { continue }
            let title = (dict["title"] as? String) ?? (dict["name"] as? String) ?? ""
            let url = (dict["link"] as? String) ?? (dict["url"] as? String) ?? (dict["product_url"] as? String) ?? ""
            if title.isEmpty || url.isEmpty { continue }
            drafts.append(ProductDraft(
                title: title,
                price: (dict["price"] as? String) ?? (dict["price_str"] as? String) ?? "",
                url: url,
                image: (dict["thumbnail"] as? String) ?? (dict["image"] as? String) ?? (dict["img"] as? String) ?? "",
                platform: (dict["platform"] as? String) ?? (dict["source"] as? String) ?? "",
                shop: (dict["shop"] as? String) ?? (dict["source"] as? String) ?? ""
            ))
        }
        return drafts
    }

    static func chatText(from data: Data) -> String? {
        guard let json = try? jsonObject(data) as? [String: Any] else { return nil }
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any] {
            if let text = message["content"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        if let text = json["output_text"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    static func htmlResults(_ html: String) -> [(title: String, url: String)] {
        guard let heading = try? NSRegularExpression(pattern: "<h[23][^>]*>(.*?)</h[23]>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let anchor = try? NSRegularExpression(pattern: "href=\"(https?://[^\"]+)\"[^>]*>(.*?)</a>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        var results: [(title: String, url: String)] = []
        var seen = Set<String>()
        for match in heading.matches(in: html, range: range) {
            guard let blockRange = Range(match.range(at: 1), in: html) else { continue }
            let block = String(html[blockRange])
            let blockNS = NSRange(block.startIndex..., in: block)
            guard let link = anchor.firstMatch(in: block, range: blockNS),
                  let urlRange = Range(link.range(at: 1), in: block),
                  let titleRange = Range(link.range(at: 2), in: block) else { continue }
            let url = String(block[urlRange])
            let title = plain(String(block[titleRange]))
            guard title.count >= 2, let host = URL(string: url)?.host?.lowercased() else { continue }
            if host.contains("microsoft.com") || host.contains("bing.com/account") { continue }
            let key = title + "|" + host
            if seen.contains(key) { continue }
            seen.insert(key)
            results.append((title, url))
            if results.count == 16 { break }
        }
        return results
    }

    static func apiMessage(from data: Data) -> String? {
        guard let json = try? jsonObject(data) else { return nil }
        return apiMessage(from: json)
    }

    static func isVideo(_ data: Data) -> Bool {
        if data.starts(with: Data([0x1A, 0x45, 0xDF, 0xA3])) { return true }
        if data.count > 12, let text = String(data: data.prefix(16), encoding: .ascii), text.contains("ftyp") { return true }
        return false
    }

    private static func apiMessage(from json: Any) -> String? {
        if let dict = json as? [String: Any] {
            if let error = dict["error"] as? [String: Any], let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let message = dict["message"] as? String,
               !message.isEmpty,
               message.lowercased() != "succeed",
               message != "SUCCEED" {
                if let code = dict["code"] as? Int, code != 0 { return message }
                if let code = dict["code"] as? String, !code.isEmpty, code != "0" { return message }
            }
            for value in dict.values {
                if let found = apiMessage(from: value) { return found }
            }
        } else if let array = json as? [Any] {
            for value in array {
                if let found = apiMessage(from: value) { return found }
            }
        }
        return nil
    }

    private static func embeddedImage(_ json: Any) -> Data? {
        var urls: [String] = []
        func walk(_ any: Any) {
            if let text = any as? String, text.hasPrefix("data:image") {
                urls.append(text)
            } else if let dict = any as? [String: Any] {
                dict.values.forEach(walk)
            } else if let array = any as? [Any] {
                array.forEach(walk)
            }
        }
        walk(json)
        for item in urls {
            let parts = item.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let bytes = Data(base64Encoded: String(parts[1])), !bytes.isEmpty else { continue }
            return bytes
        }
        return nil
    }

    private static func imageMagic(_ data: Data) -> Data? {
        if data.starts(with: Data([0xFF, 0xD8, 0xFF])) { return data }
        if data.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) { return data }
        if data.starts(with: Data("GIF8".utf8)) { return data }
        return nil
    }

    private static func jsonObject(_ data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw StudioError.message("接口返回的不是 JSON")
        }
    }

    private static func firstString(in json: Any, keys: [String]) -> String? {
        for key in keys {
            if let value = strings(in: json, keys: [key]).first(where: { !$0.isEmpty }) {
                return value
            }
        }
        return nil
    }

    private static func strings(in json: Any, keys: [String]) -> [String] {
        var found: [String] = []
        func walk(_ any: Any) {
            if let dict = any as? [String: Any] {
                for (key, value) in dict {
                    if keys.contains(key), let text = value as? String {
                        found.append(text)
                    }
                    walk(value)
                }
            } else if let array = any as? [Any] {
                array.forEach(walk)
            }
        }
        walk(json)
        return found
    }

    private static func arrayValues(in json: Any, keys: [String]) -> [Any] {
        var found: [Any] = []
        func walk(_ any: Any) {
            if let dict = any as? [String: Any] {
                for (key, value) in dict {
                    if keys.contains(key), let array = value as? [Any], array.first is [String: Any] {
                        found.append(contentsOf: array)
                    }
                    walk(value)
                }
            } else if let array = any as? [Any] {
                array.forEach(walk)
            }
        }
        walk(json)
        return found
    }

    private static func preferredURL(in json: Any, keys: [String], images: Bool) -> String? {
        let values = strings(in: json, keys: keys).filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        if images {
            return values.first { looksLikeImage($0) } ?? values.first { !looksLikeVideo($0) }
        }
        return values.first { looksLikeVideo($0) } ?? values.first { !looksLikeImage($0) }
    }

    private static func looksLikeImage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains(".png") || lower.contains(".jpg") || lower.contains(".jpeg") || lower.contains(".webp") || lower.contains(".gif")
    }

    private static func looksLikeVideo(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains(".mp4") || lower.contains(".webm") || lower.contains(".mov")
    }

    private static func plain(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum StudioError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

enum FailureText {
    static func describe(_ error: Error) -> String {
        if error is CancellationError { return "已取消" }
        if let url = error as? URLError {
            switch url.code {
            case .cancelled: return "已取消"
            case .notConnectedToInternet: return "没有网络"
            case .timedOut: return "接口超时"
            case .cannotFindHost, .cannotConnectToHost: return "连不上接口地址"
            default: return "网络错误：\(url.localizedDescription)"
            }
        }
        if let error = error as? LocalizedError, let text = error.errorDescription, !text.isEmpty {
            return text
        }
        return error.localizedDescription
    }
}
