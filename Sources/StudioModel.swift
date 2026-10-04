import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StudioModel: ObservableObject {
    @Published var settings: Settings {
        didSet { Store.saveSettings(settings) }
    }
    @Published var looks: [LookProject]
    @Published var activeID: UUID
    @Published var posts: [CommunityPost]
    @Published var briefs: [ProductionBrief]
    @Published var clips: [MotionClip]
    @Published var page: StudioPage = .design
    @Published var cache: [String: NSImage] = [:]
    @Published var webHits: [ProductHit] = []
    @Published var busy: String?
    @Published var status = "选择人物，再用参考图说明想要的衣服。"
    @Published var error: String?
    @Published var showSettings = false
    @Published var confirmReplace = false
    @Published var confirmDeleteLook = false
    @Published var showComposer = false
    @Published var draftTitle = ""
    @Published var draftBody = ""
    @Published var draftImage: String?
    @Published var selectedPostID: UUID?
    @Published var scene: WearScene = .shopping
    @Published var pickPerson = false
    @Published var pickReference = false

    private var stagedPerson: Data?
    private var job: Task<Void, Never>?
    private var jobToken: UUID?

    var look: LookProject {
        looks.first { $0.id == activeID } ?? looks[0]
    }

    var canUndo: Bool { look.history.canUndo }
    var canRedo: Bool { look.history.canRedo }

    var marketLinks: [ProductHit] {
        let query = look.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = query.isEmpty ? OutfitQuery.make(note: look.note, category: look.category) : query
        return Market.links(for: text)
    }

    init() {
        Store.prepare()
        settings = Store.loadSettings()
        if let library = Store.loadLibrary() {
            looks = library.looks
            activeID = library.activeID
            posts = library.posts
            briefs = library.briefs
            clips = library.clips
        } else {
            let filename = StudioModel.storeModel("woman")
            let created = LookProject.make(name: "造型 1", filename: filename)
            looks = [created]
            activeID = created.id
            posts = []
            briefs = []
            clips = []
            persist()
        }
        warmCache()
    }

    func picture(_ name: String?) -> NSImage? {
        guard let name else { return nil }
        return cache[name]
    }

    func undo() {
        updateActive { $0.history.undo() }
        status = "已撤销"
    }

    func redo() {
        updateActive { $0.history.redo() }
        status = "已重做"
    }

    func jump(_ index: Int) {
        updateActive { $0.history.jump(index) }
    }

    func selectLook(_ id: UUID) {
        guard looks.contains(where: { $0.id == id }) else { return }
        activeID = id
        persist()
    }

    func newLook() {
        let filename = StudioModel.storeModel("woman")
        let created = LookProject.make(name: "造型 \(looks.count + 1)", filename: filename)
        looks.append(created)
        activeID = created.id
        page = .design
        persist()
        status = "已新建造型"
    }

    func askDeleteLook() {
        guard looks.count > 1 else {
            status = "至少留一个造型"
            return
        }
        confirmDeleteLook = true
    }

    func deleteActiveLook() {
        guard looks.count > 1 else { return }
        looks.removeAll { $0.id == activeID }
        activeID = looks[0].id
        confirmDeleteLook = false
        persist()
    }

    func setCategory(_ category: String) {
        updateActive { $0.category = category }
    }

    func setNote(_ note: String) {
        updateActive { $0.note = note }
    }

    func setName(_ name: String) {
        updateActive { $0.name = name }
    }

    func setSearchText(_ text: String) {
        updateActive { $0.searchText = text }
    }

    func ensureSearchDraft() {
        if look.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateActive { $0.searchText = OutfitQuery.make(note: $0.note, category: $0.category) }
        }
    }

    func dismissGuide() {
        settings.seenGuide = true
    }

    func useDefaultModel(_ id: String) {
        stagePerson(StudioModel.modelData(id))
    }

    func importFile(_ url: URL, asPerson: Bool) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            error = "这张图片打不开"
            return
        }
        if asPerson { stagePerson(data) } else { addReference(data) }
    }

    func takeProviders(_ providers: [NSItemProvider], asPerson: Bool) {
        let images = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        let chosen = images.isEmpty ? providers : images
        for provider in chosen {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in
                        if asPerson { self.stagePerson(data) } else { self.addReference(data) }
                    }
                }
            }
        }
    }

    func confirmPersonReplace() {
        guard let data = stagedPerson else { return }
        stagedPerson = nil
        confirmReplace = false
        applyPerson(data)
    }

    func cancelPersonReplace() {
        stagedPerson = nil
        confirmReplace = false
    }

    func addReference(_ data: Data) {
        guard look.references.count < (settings.imageStyle == "qwen" ? 2 : 4) else {
            status = settings.imageStyle == "qwen" ? "千问图像编辑最多 2 张参考图" : "参考图最多 4 张"
            return
        }
        guard let name = storeImage(data) else {
            error = "参考图打不开"
            return
        }
        updateActive { $0.references.append(name) }
        status = "已加入参考图"
    }

    func removeReference(_ name: String) {
        updateActive { $0.references.removeAll { $0 == name } }
    }

    func design() {
        let note = look.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty || !look.references.isEmpty else {
            error = "先写设计说明，或放一张参考图。"
            return
        }
        let lookID = look.id
        let category = look.category
        let prompt = PromptText.design(note: note, category: category, referenceCount: min(look.references.count, settings.imageStyle == "qwen" ? 2 : 4))
        let shown = note.isEmpty ? "按参考图设计" : note
        guard let person = Store.readMedia(look.history.current.filename) else {
            error = "找不到当前人物图"
            return
        }
        let cap = settings.imageStyle == "qwen" ? 2 : 4
        let references = look.references.prefix(cap).compactMap { Store.readMedia($0) }
        let currentSettings = settings
        run(busy: "正在把参考图穿到人物身上…") {
            let data = try await APIClient.editImage(settings: currentSettings, person: person, references: references, prompt: prompt)
            self.commitDesign(lookID: lookID, data: data, prompt: shown)
            self.status = "设计已生成，可以撤销"
        }
    }

    func search() {
        let lookID = look.id
        let note = look.note
        let category = look.category
        var query = look.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            query = OutfitQuery.make(note: note, category: category)
            update(lookID) { $0.searchText = query }
        }
        let currentSettings = settings
        let imageName = look.history.current.filename
        run(busy: currentSettings.useChatForQuery ? "正在看图提炼搜索词…" : "正在全网检索同款…") {
            var text = query
            if currentSettings.useChatForQuery, let image = Store.readMedia(imageName) {
                text = try await APIClient.describeOutfit(settings: currentSettings, image: image, note: note, category: category)
                self.update(lookID) { $0.searchText = text }
                self.busy = "正在全网检索同款…"
            }
            let drafts = try await APIClient.shopping(settings: currentSettings, query: text)
            self.webHits = drafts.compactMap { draft in
                guard let url = URL(string: draft.url) else { return nil }
                let host = url.host ?? ""
                let platform = draft.platform.isEmpty ? Market.name(for: host) : draft.platform
                return ProductHit(
                    id: draft.url,
                    platform: platform,
                    title: draft.title,
                    price: draft.price,
                    shop: draft.shop,
                    url: url,
                    imageURL: URL(string: draft.image),
                    kind: "网页"
                )
            }
            self.status = self.webHits.isEmpty ? "没有抓到网页结果，可以用下面的平台入口继续找。" : "找到 \(self.webHits.count) 条网页线索"
        }
    }

    func copySearch() {
        let text = look.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        status = "已复制搜索词"
    }

    func startPost() {
        let query = look.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? OutfitQuery.make(note: look.note, category: look.category)
            : look.searchText
        draftTitle = look.category == "整身搭配" ? "找一件类似的衣服" : "找类似的\(look.category)"
        draftBody = "我想找和这套类似的衣服。\n搜索词：\(query)\n\(look.note)".trimmingCharacters(in: .whitespacesAndNewlines)
        draftImage = look.history.current.filename
        page = .forum
        showComposer = true
    }

    func publishDraft() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            error = "标题和内容都要写"
            return
        }
        let post = CommunityPost(
            id: UUID(),
            lookID: look.id,
            title: title,
            body: body,
            imageFilename: draftImage,
            author: settings.authorName.isEmpty ? "我" : settings.authorName,
            createdAt: Date(),
            replies: []
        )
        posts.insert(post, at: 0)
        selectedPostID = post.id
        showComposer = false
        persist()
        status = "已发到这台 Mac 上的社区"
        let endpoint = settings.forumURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { return }
        var payload: [String: Any] = ["title": title, "body": body, "author": post.author]
        if let name = draftImage, let data = Store.readMedia(name) {
            payload["image_base64"] = data.base64EncodedString()
        }
        let forum = endpoint
        run(busy: "正在同步到论坛…") {
            try await APIClient.postJSON(urlString: forum, payload: payload)
            self.status = "已发到社区，并同步到填写的论坛地址"
        }
    }

    func reply(to postID: UUID, text: String) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].replies.append(ForumReply(
            id: UUID(),
            author: settings.authorName.isEmpty ? "我" : settings.authorName,
            body: body,
            createdAt: Date()
        ))
        persist()
    }

    func deletePost(_ id: UUID) {
        posts.removeAll { $0.id == id }
        if selectedPostID == id { selectedPostID = posts.first?.id }
        persist()
    }

    func submitBrief(title: String, spec: String, quantity: Int, budget: String, contact: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSpec = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanSpec.isEmpty else {
            error = "请写上款式名称和成衣要求"
            return
        }
        let endpoint = settings.atelierURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let brief = ProductionBrief(
            id: UUID(),
            lookID: look.id,
            title: cleanTitle,
            spec: cleanSpec,
            quantity: max(1, quantity),
            budget: budget.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
            imageFilename: look.history.current.filename,
            status: endpoint.isEmpty ? "已保存在本机" : "正在发送",
            detail: endpoint.isEmpty ? "还没有填写工坊地址，需求先留在这台 Mac 上。" : "",
            createdAt: Date()
        )
        briefs.insert(brief, at: 0)
        persist()
        guard !endpoint.isEmpty else {
            status = "需求已保存在这台 Mac 上"
            return
        }
        send(brief)
    }

    func resendBrief(_ id: UUID) {
        guard let brief = briefs.first(where: { $0.id == id }) else { return }
        send(brief)
    }

    func deleteBrief(_ id: UUID) {
        briefs.removeAll { $0.id == id }
        persist()
    }

    func renderMotion() {
        let lookID = look.id
        let scene = scene
        let outfit = look.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? look.note : look.searchText
        let prompt = PromptText.motion(scene: scene, outfit: outfit)
        guard let image = Store.readMedia(look.history.current.filename) else {
            error = "找不到当前人物图"
            return
        }
        let currentSettings = settings
        run(busy: "正在生成\(scene.title)动图…") {
            let video = try await APIClient.renderVideo(settings: currentSettings, image: image, prompt: prompt)
            let videoName = Store.writeMedia(video, ext: "mp4")
            var gifName: String?
            if let gif = try? await MediaKit.gif(fromVideo: Store.mediaURL(videoName)) {
                gifName = Store.writeMedia(gif, ext: "gif")
            }
            let clip = MotionClip(
                id: UUID(),
                lookID: lookID,
                scene: scene.title,
                prompt: prompt,
                videoFilename: videoName,
                gifFilename: gifName,
                createdAt: Date()
            )
            self.clips.insert(clip, at: 0)
            self.persist()
            self.status = gifName == nil ? "\(scene.title)视频已生成" : "\(scene.title)动图已生成"
        }
    }

    func deleteClip(_ id: UUID) {
        clips.removeAll { $0.id == id }
        persist()
    }

    func exportCurrentImage() {
        guard let data = Store.readMedia(look.history.current.filename) else {
            error = "找不到当前图片"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.nameFieldStringValue = look.name + ".jpg"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                Task { @MainActor in self.status = "已导出图片" }
            } catch {
                Task { @MainActor in self.error = "导出失败" }
            }
        }
    }

    func exportGIF(_ clip: MotionClip) {
        guard let name = clip.gifFilename, let data = Store.readMedia(name) else {
            error = "这条还没有导出成 GIF"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = "\(clip.scene).gif"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                Task { @MainActor in self.status = "已导出动图" }
            } catch {
                Task { @MainActor in self.error = "导出失败" }
            }
        }
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func revealStorage() {
        Store.prepare()
        NSWorkspace.shared.activateFileViewerSelecting([Store.root])
    }

    func applyPreset(_ name: String) {
        var next = settings
        switch name {
        case "openai-image":
            next.imageBase = "https://api.openai.com/v1"
            next.imagePath = "/images/edits"
            next.imageStyle = "openai"
            next.imageModel = "gpt-image-1"
            next.imageAuth = "bearer"
            next.imageSize = "1024x1536"
        case "json-image":
            next.imageStyle = "json"
            if next.imagePath.isEmpty || next.imagePath == "/images/edits" {
                next.imagePath = "/v1/images/edits"
            }
        case "qwen-image":
            next.imageBase = "https://dashscope.aliyuncs.com/api/v1"
            next.imagePath = "/services/aigc/multimodal-generation/generation"
            next.imageStyle = "qwen"
            next.imageModel = "qwen-image-2.0-pro"
            next.imageAuth = "bearer"
            next.imageSize = "1024*1536"
            next.chatBase = "https://dashscope.aliyuncs.com/compatible-mode/v1"
            next.chatModel = "qwen-vl-plus"
        case "wan-video":
            next.videoBase = "https://dashscope.aliyuncs.com/api/v1"
            next.videoStyle = "wan"
            next.videoCreatePath = "/services/aigc/video-generation/video-synthesis"
            next.videoStatusPath = "/tasks/{id}"
            next.videoModel = "wan2.6-i2v-flash"
            next.videoAuth = "bearer"
            next.videoSeconds = 5
        case "generic-video":
            next.videoStyle = "generic"
            next.videoCreatePath = "/v1/video/generations"
            next.videoStatusPath = "/v1/video/generations/{id}"
            next.videoAuth = "bearer"
            next.videoSeconds = 5
        case "kling":
            next.videoStyle = "kling"
            next.videoCreatePath = "/v1/videos/image2video"
            next.videoStatusPath = "/v1/videos/image2video/{id}"
            if next.videoModel.isEmpty { next.videoModel = "kling-v1" }
            next.videoAuth = "bearer"
            next.videoSeconds = 5
        case "openai-video":
            next.videoBase = "https://api.openai.com/v1"
            next.videoStyle = "openai"
            next.videoCreatePath = "/videos"
            next.videoStatusPath = "/videos/{id}"
            next.videoModel = "sora-2"
            next.videoAuth = "bearer"
            next.videoSeconds = 4
        case "serpapi":
            next.searchMode = "serpapi"
        case "web":
            next.searchMode = "web"
        default:
            break
        }
        settings = next
        status = "已填入接口预设，密钥还需要你自己贴上"
    }

    func cancelJob() {
        job?.cancel()
        status = "正在取消…"
    }

    private func stagePerson(_ data: Data) {
        if look.history.steps.count > 1 {
            stagedPerson = data
            confirmReplace = true
        } else {
            applyPerson(data)
        }
    }

    private func applyPerson(_ data: Data) {
        guard let name = storeImage(data) else {
            error = "这张图片打不开"
            return
        }
        updateActive { look in
            let step = DesignStep(id: UUID(), filename: name, prompt: "原图", createdAt: Date(), kind: "原图")
            look.history = DesignHistory(steps: [step], cursor: 0)
        }
        status = "已更换人物"
    }

    private func commitDesign(lookID: UUID, data: Data, prompt: String) {
        guard let name = storeImage(data) else {
            error = "设计结果无法保存"
            return
        }
        update(lookID) { look in
            look.history.push(DesignStep(id: UUID(), filename: name, prompt: prompt, createdAt: Date(), kind: "设计"))
            if look.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                look.searchText = OutfitQuery.make(note: look.note, category: look.category)
            }
        }
    }

    private func send(_ brief: ProductionBrief) {
        let endpoint = settings.atelierURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else {
            error = "还没有填写工坊地址"
            return
        }
        var payload: [String: Any] = [
            "title": brief.title,
            "spec": brief.spec,
            "quantity": brief.quantity,
            "budget": brief.budget,
            "contact": brief.contact
        ]
        if let name = brief.imageFilename, let data = Store.readMedia(name) {
            payload["image_base64"] = data.base64EncodedString()
        }
        let briefID = brief.id
        run(busy: "正在把需求发给工坊…") {
            do {
                try await APIClient.postJSON(urlString: endpoint, payload: payload)
                self.markBrief(briefID, status: "已提交", detail: "工坊地址已收到这份需求。")
                self.status = "已发给工坊"
            } catch {
                self.markBrief(briefID, status: "发送失败", detail: FailureText.describe(error))
                throw error
            }
        }
    }

    private func markBrief(_ id: UUID, status: String, detail: String) {
        guard let index = briefs.firstIndex(where: { $0.id == id }) else { return }
        briefs[index].status = status
        briefs[index].detail = detail
        persist()
    }

    private func storeImage(_ data: Data) -> String? {
        let stored = MediaKit.normalizeJPEG(data) ?? data
        guard !stored.isEmpty else { return nil }
        let ext = stored.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) ? "png" : "jpg"
        let name = Store.writeMedia(stored, ext: ext)
        if let image = NSImage(data: stored) ?? NSImage(data: data) {
            cache[name] = image
        }
        return name
    }

    private func updateActive(_ mutate: (inout LookProject) -> Void) {
        update(activeID, mutate)
    }

    private func update(_ id: UUID, _ mutate: (inout LookProject) -> Void) {
        guard let index = looks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&looks[index])
        persist()
    }

    private func persist() {
        Store.saveLibrary(LibraryFile(
            schema: 1,
            looks: looks,
            activeID: activeID,
            posts: posts,
            briefs: briefs,
            clips: clips
        ))
    }

    private func warmCache() {
        var names: [String] = []
        for look in looks {
            names.append(contentsOf: look.history.steps.map(\.filename))
            names.append(contentsOf: look.references)
        }
        names.append(contentsOf: posts.compactMap(\.imageFilename))
        names.append(contentsOf: briefs.compactMap(\.imageFilename))
        for name in Set(names) {
            guard cache[name] == nil, let data = Store.readMedia(name), let image = NSImage(data: data) else { continue }
            cache[name] = image
        }
    }

    private func run(busy title: String, _ work: @escaping @MainActor () async throws -> Void) {
        guard job == nil else {
            status = "上一项还在进行"
            return
        }
        let token = UUID()
        jobToken = token
        busy = title
        let task = Task { @MainActor in
            await Task.yield()
            defer { self.finish(token) }
            do {
                try Task.checkCancellation()
                try await work()
            } catch is CancellationError {
                self.status = "已取消"
            } catch let error as URLError where error.code == .cancelled {
                self.status = "已取消"
            } catch {
                let text = FailureText.describe(error)
                if text != "已取消" { self.error = text }
            }
        }
        job = task
    }

    private func finish(_ token: UUID) {
        guard jobToken == token else { return }
        job = nil
        jobToken = nil
        busy = nil
    }

    private static func modelData(_ id: String) -> Data {
        if let url = Bundle.main.url(forResource: "model-\(id)", withExtension: "png"),
           let data = try? Data(contentsOf: url), !data.isEmpty {
            return data
        }
        return MediaKit.fallbackModelPNG()
    }

    private static func storeModel(_ id: String) -> String {
        let data = modelData(id)
        let stored = MediaKit.normalizeJPEG(data) ?? data
        return Store.writeMedia(stored.isEmpty ? data : stored, ext: stored.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) ? "png" : "jpg")
    }
}
