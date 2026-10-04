import Foundation

enum APIClient {
    static func editImage(settings: Settings, person: Data, references: [Data], prompt: String) async throws -> Data {
        if settings.imageKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw StudioError.message("还没有填写图像编辑 API 密钥。请打开设置，填入图像接口。")
        }
        let url = try endpoint(settings.imageBase, settings.imagePath, label: "图像接口")
        let personJPEG = MediaKit.normalizeJPEG(person) ?? person
        let refs = references.prefix(4).compactMap { MediaKit.normalizeJPEG($0) ?? $0 }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = settings.imageStyle == "qwen" ? 300 : 180
        applyAuth(&request, key: settings.imageKey, style: settings.imageAuth)
        if settings.imageStyle == "qwen" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var content: [[String: Any]] = []
            for image in [personJPEG] + refs.prefix(2) {
                content.append(["image": "data:image/jpeg;base64,\(image.base64EncodedString())"])
            }
            content.append(["text": prompt])
            let size = settings.imageSize.replacingOccurrences(of: "x", with: "*").replacingOccurrences(of: "X", with: "*")
            let body: [String: Any] = [
                "model": settings.imageModel.isEmpty ? "qwen-image-2.0-pro" : settings.imageModel,
                "input": [
                    "messages": [[
                        "role": "user",
                        "content": content
                    ]]
                ],
                "parameters": [
                    "n": 1,
                    "watermark": false,
                    "prompt_extend": true,
                    "size": size.isEmpty ? "1024*1536" : size
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else if settings.imageStyle == "json" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let images = ([personJPEG] + refs).map { "data:image/jpeg;base64,\($0.base64EncodedString())" }
            let body: [String: Any] = [
                "model": settings.imageModel,
                "prompt": prompt,
                "size": settings.imageSize,
                "images": images
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            var form = Multipart()
            form.field("model", settings.imageModel)
            form.field("prompt", prompt)
            form.field("size", settings.imageSize)
            form.file("image", filename: "person.jpg", mime: "image/jpeg", data: personJPEG)
            for (index, ref) in refs.enumerated() {
                form.file("image", filename: "ref-\(index + 1).jpg", mime: "image/jpeg", data: ref)
            }
            form.finish()
            request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = form.body
        }
        let data = try await send(request, key: settings.imageKey, label: "图像接口")
        let payload = try PayloadParse.image(from: data)
        switch payload {
        case .bytes(let bytes):
            return bytes
        case .remote(let remote):
            return try await download(remote, settings: nil)
        }
    }

    static func renderVideo(settings: Settings, image: Data, prompt: String) async throws -> Data {
        if settings.videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.videoBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw StudioError.message("还没有填写图生视频 API。请打开设置，填入视频接口的基址和密钥。")
        }
        let jpeg = MediaKit.normalizeJPEG(image) ?? image
        switch settings.videoStyle {
        case "wan":
            return try await wan(settings: settings, image: jpeg, prompt: prompt)
        case "kling":
            return try await kling(settings: settings, image: jpeg, prompt: prompt)
        case "openai":
            return try await openAIVideo(settings: settings, image: jpeg, prompt: prompt)
        default:
            return try await genericVideo(settings: settings, image: jpeg, prompt: prompt)
        }
    }

    static func shopping(settings: Settings, query: String) async throws -> [ProductDraft] {
        switch settings.searchMode {
        case "serpapi":
            return try await serp(settings: settings, query: query)
        case "custom":
            return try await customSearch(settings: settings, query: query)
        default:
            return try await webSearch(query: query)
        }
    }

    static func describeOutfit(settings: Settings, image: Data, note: String, category: String) async throws -> String {
        let base = settings.chatBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? settings.imageBase : settings.chatBase
        let key = settings.chatKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? settings.imageKey : settings.chatKey
        if key.isEmpty {
            throw StudioError.message("看图写搜索词需要对话模型的密钥。可以填写对话接口，或先填写图像接口密钥。")
        }
        let url = try endpoint(base, "/chat/completions", label: "对话接口")
        let jpeg = MediaKit.normalizeJPEG(image, maxEdge: 1024) ?? image
        let content: [[String: Any]] = [
            ["type": "text", "text": "品类：\(category)\n用户说明：\(note)\n请只输出一行中文购物搜索词，包含颜色、材质、品类和版型。不要解释。"],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]]
        ]
        let body: [String: Any] = [
            "model": settings.chatModel.isEmpty ? "gpt-4o-mini" : settings.chatModel,
            "messages": [
                ["role": "system", "content": "你是服装买手。只输出一行可以拿去电商搜索的中文关键词。"],
                ["role": "user", "content": content]
            ],
            "max_tokens": 80
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request, key: key, style: settings.imageAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request, key: key, label: "对话接口")
        guard let text = PayloadParse.chatText(from: data) else {
            throw StudioError.message(PayloadParse.apiMessage(from: data) ?? "对话接口没有返回搜索词")
        }
        return text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func postJSON(urlString: String, payload: [String: Any]) async throws {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https" || url.scheme == "http" else {
            throw StudioError.message("地址无效")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 40
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await send(request, key: "", label: "接收地址")
    }

    private static func genericVideo(settings: Settings, image: Data, prompt: String) async throws -> Data {
        let url = try endpoint(settings.videoBase, settings.videoCreatePath, label: "视频接口")
        let body: [String: Any] = [
            "model": settings.videoModel,
            "prompt": prompt,
            "image": "data:image/jpeg;base64,\(image.base64EncodedString())",
            "duration": settings.videoSeconds,
            "aspect_ratio": "9:16"
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request, key: settings.videoKey, style: settings.videoAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let created = try await send(request, key: settings.videoKey, label: "视频接口")
        if PayloadParse.isVideo(created) { return created }
        return try await finishVideo(settings: settings, created: created, contentPath: nil)
    }

    private static func kling(settings: Settings, image: Data, prompt: String) async throws -> Data {
        let url = try endpoint(settings.videoBase, settings.videoCreatePath, label: "视频接口")
        let body: [String: Any] = [
            "model_name": settings.videoModel.isEmpty ? "kling-v1" : settings.videoModel,
            "image": image.base64EncodedString(),
            "prompt": prompt,
            "duration": String(max(5, settings.videoSeconds)),
            "mode": "std"
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request, key: settings.videoKey, style: settings.videoAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let created = try await send(request, key: settings.videoKey, label: "视频接口")
        return try await finishVideo(settings: settings, created: created, contentPath: nil)
    }

    private static func wan(settings: Settings, image: Data, prompt: String) async throws -> Data {
        let url = try endpoint(settings.videoBase, settings.videoCreatePath, label: "视频接口")
        let seconds = min(15, max(2, settings.videoSeconds))
        let body: [String: Any] = [
            "model": settings.videoModel.isEmpty ? "wan2.6-i2v-flash" : settings.videoModel,
            "input": [
                "prompt": prompt,
                "img_url": "data:image/jpeg;base64,\(image.base64EncodedString())"
            ],
            "parameters": [
                "resolution": "720P",
                "duration": seconds,
                "prompt_extend": true,
                "audio": false,
                "watermark": false
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        applyAuth(&request, key: settings.videoKey, style: settings.videoAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let created = try await send(request, key: settings.videoKey, label: "视频接口")
        return try await finishVideo(settings: settings, created: created, contentPath: nil, pause: 15_000_000_000, attempts: 28)
    }

    private static func openAIVideo(settings: Settings, image: Data, prompt: String) async throws -> Data {
        let url = try endpoint(settings.videoBase, settings.videoCreatePath, label: "视频接口")
        var form = Multipart()
        form.field("model", settings.videoModel.isEmpty ? "sora-2" : settings.videoModel)
        form.field("prompt", prompt)
        form.field("seconds", PromptText.openAISeconds(settings.videoSeconds))
        form.field("size", "720x1280")
        form.file("input_reference", filename: "look.jpg", mime: "image/jpeg", data: image)
        form.finish()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        applyAuth(&request, key: settings.videoKey, style: settings.videoAuth)
        request.httpBody = form.body
        let created = try await send(request, key: settings.videoKey, label: "视频接口")
        if PayloadParse.isVideo(created) { return created }
        return try await finishVideo(settings: settings, created: created, contentPath: "/videos/{id}/content")
    }

    private static func finishVideo(settings: Settings, created: Data, contentPath: String?, pause: UInt64 = 4_000_000_000, attempts: Int = 80) async throws -> Data {
        let job = try PayloadParse.videoJob(from: created)
        if job.phase == .failed {
            throw StudioError.message(job.message ?? "视频生成失败")
        }
        if job.phase == .done, let videoURL = job.videoURL {
            return try await download(videoURL, settings: settings)
        }
        guard let id = job.id else {
            throw StudioError.message(job.message ?? "视频接口没有返回任务编号")
        }
        let statusPath = settings.videoStatusPath.replacingOccurrences(of: "{id}", with: id)
        let statusURL = try endpoint(settings.videoBase, statusPath, label: "视频状态接口")
        for _ in 0..<attempts {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: pause)
            var request = URLRequest(url: statusURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 40
            applyAuth(&request, key: settings.videoKey, style: settings.videoAuth)
            let data = try await send(request, key: settings.videoKey, label: "视频状态接口")
            if PayloadParse.isVideo(data) { return data }
            let polled = try PayloadParse.videoJob(from: data)
            if polled.phase == .failed {
                throw StudioError.message(polled.message ?? "视频生成失败")
            }
            if polled.phase == .done {
                if let videoURL = polled.videoURL {
                    return try await download(videoURL, settings: settings)
                }
                if let contentPath {
                    let path = contentPath.replacingOccurrences(of: "{id}", with: id)
                    let contentURL = try endpoint(settings.videoBase, path, label: "视频下载接口")
                    return try await download(contentURL, settings: settings)
                }
                throw StudioError.message("视频已完成，但没有下载地址")
            }
        }
        throw StudioError.message("视频等待超时")
    }

    private static func serp(settings: Settings, query: String) async throws -> [ProductDraft] {
        if settings.searchKey.isEmpty {
            throw StudioError.message("SerpAPI 需要填写搜索密钥")
        }
        var components = URLComponents(string: "https://serpapi.com/search.json")
        components?.queryItems = [
            URLQueryItem(name: "engine", value: "google_shopping"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "hl", value: "zh-cn"),
            URLQueryItem(name: "gl", value: "cn"),
            URLQueryItem(name: "api_key", value: settings.searchKey)
        ]
        guard let url = components?.url else { throw StudioError.message("搜索地址无效") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let data = try await send(request, key: settings.searchKey, label: "SerpAPI")
        return PayloadParse.products(from: data)
    }

    private static func customSearch(settings: Settings, query: String) async throws -> [ProductDraft] {
        let url = try endpoint(settings.searchBase, "", label: "搜索接口")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request, key: settings.searchKey, style: settings.searchAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "platforms": ["taobao", "jd", "amazon"]])
        let data = try await send(request, key: settings.searchKey, label: "搜索接口")
        return PayloadParse.products(from: data)
    }

    private static func webSearch(query: String) async throws -> [ProductDraft] {
        let bing = try await htmlSearch(url: APIURL.page("https://www.bing.com/search", [
            URLQueryItem(name: "q", value: query + " 衣服 购买"),
            URLQueryItem(name: "setlang", value: "zh-Hans"),
            URLQueryItem(name: "count", value: "15")
        ]))
        if bing.count >= 3 { return bing }
        let baidu = try await htmlSearch(url: APIURL.page("https://www.baidu.com/s", [
            URLQueryItem(name: "wd", value: query + " 购买")
        ]))
        var merged = bing
        for item in baidu where !merged.contains(where: { $0.url == item.url }) {
            merged.append(item)
        }
        return merged
    }

    private static func htmlSearch(url: URL) async throws -> [ProductDraft] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        guard let html = decodePage(data) else { return [] }
        return PayloadParse.htmlResults(html).compactMap { item in
            guard let link = URL(string: item.url) else { return nil }
            return ProductDraft(
                title: item.title,
                price: "",
                url: item.url,
                image: "",
                platform: Market.name(for: link.host ?? ""),
                shop: link.host ?? ""
            )
        }
    }

    private static func endpoint(_ base: String, _ path: String, label: String) throws -> URL {
        let joined = path.isEmpty ? base.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression) : APIURL.join(base, path)
        guard let url = URL(string: joined), url.scheme == "https" || url.scheme == "http" else {
            throw StudioError.message("\(label)地址无效")
        }
        return url
    }

    private static func applyAuth(_ request: inout URLRequest, key: String, style: String) {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        switch style {
        case "x-api-key":
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        case "raw":
            request.setValue(key, forHTTPHeaderField: "Authorization")
        default:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func send(_ request: URLRequest, key: String, label: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.message("\(label)没有响应")
        }
        guard (200...299).contains(http.statusCode) else {
            let host = request.url?.host ?? ""
            let snippet = redact(data, key: key)
            let message = PayloadParse.apiMessage(from: data) ?? snippet
            throw StudioError.message("\(label)返回 \(http.statusCode)（\(host)）。\(message)")
        }
        return data
    }

    private static func download(_ url: URL, settings: Settings?) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 180
        if let settings, url.host == URL(string: settings.videoBase)?.host {
            applyAuth(&request, key: settings.videoKey, style: settings.videoAuth)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StudioError.message("下载结果失败")
        }
        if data.isEmpty { throw StudioError.message("下载结果是空的") }
        return data
    }

    private static func decodePage(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8), text.contains("<") {
            return text
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        return String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8)
    }

    private static func redact(_ data: Data, key: String) -> String {
        var text = String(data: data, encoding: .utf8) ?? ""
        if !key.isEmpty { text = text.replacingOccurrences(of: key, with: "…") }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(text.prefix(240))
    }
}

struct Multipart {
    let boundary = "Yijing\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func field(_ name: String, _ value: String) {
        body.append(utf8("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"))
    }

    mutating func file(_ name: String, filename: String, mime: String, data: Data) {
        body.append(utf8("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(mime)\r\n\r\n"))
        body.append(data)
        body.append(utf8("\r\n"))
    }

    mutating func finish() {
        body.append(utf8("--\(boundary)--\r\n"))
    }

    private func utf8(_ text: String) -> Data { Data(text.utf8) }
}
