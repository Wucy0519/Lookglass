import CoreGraphics
import Foundation

enum SelfTest {
    static func run() {
        var failed = 0
        func check(_ name: String, _ condition: Bool) {
            if condition {
                print("ok \(name)")
            } else {
                failed += 1
                print("FAIL \(name)")
            }
        }

        var history = DesignHistory(steps: [step("a")], cursor: 0)
        history.push(step("b"))
        history.push(step("c"))
        history.undo()
        check("撤销到上一张", history.current.filename == "b")
        history.undo()
        check("不能撤过原图", history.canUndo == false && history.current.filename == "a")
        history.redo()
        history.push(step("d"))
        check("新设计清掉重做", history.steps.map(\.filename) == ["a", "b", "d"] && history.current.filename == "d")

        let query = OutfitQuery.make(note: "想要一件米白色亚麻西装外套，通勤，宽松", category: "外套")
        check("搜索词含面料和版型", query.contains("米白色") && query.contains("亚麻") && query.contains("西装") && query.contains("宽松"))
        check("搜索词不含口头语", !query.contains("想要"))

        let prompt = PromptText.design(note: "亚麻外套", category: "外套", referenceCount: 1)
        check("设计提示保住人物", prompt.contains("保持人物的脸") && prompt.contains("只借鉴衣服"))
        check("视频秒数就近取值", PromptText.openAISeconds(5) == "4" && PromptText.openAISeconds(7) == "8")
        check("接口地址拼接", APIURL.join("https://api.openai.com/v1/", "/images/edits") == "https://api.openai.com/v1/images/edits")

        let taobao = Market.taobao.searchURL("亚麻西装")
        check("淘宝搜索地址", taobao.host == "s.taobao.com" && (taobao.query?.contains("q=") == true))
        let jd = Market.jd.searchURL("亚麻西装")
        check("京东搜索地址", jd.host == "search.jd.com")

        let imageJSON = Data(#"{"data":[{"b64_json":"aGVsbG8="}]}"#.utf8)
        if case let .bytes(bytes) = try? PayloadParse.image(from: imageJSON) {
            check("解析图片结果", String(data: bytes, encoding: .utf8) == "hello")
        } else {
            check("解析图片结果", false)
        }
        let qwenJSON = Data(#"{"output":{"choices":[{"message":{"content":[{"image":"https://example.com/look.png"}]}}]}}"#.utf8)
        if case let .remote(remote) = try? PayloadParse.image(from: qwenJSON) {
            check("解析千问图片", remote.absoluteString == "https://example.com/look.png")
        } else {
            check("解析千问图片", false)
        }
        let errorJSON = Data(#"{"error":{"message":"无效的密钥"}}"#.utf8)
        do {
            _ = try PayloadParse.image(from: errorJSON)
            check("解析接口错误", false)
        } catch {
            check("解析接口错误", FailureText.describe(error).contains("无效的密钥"))
        }

        let pending = Data(#"{"output":{"task_status":"PENDING","task_id":"abc"}}"#.utf8)
        let pendingJob = try? PayloadParse.videoJob(from: pending)
        check("视频任务进行中", pendingJob?.id == "abc" && pendingJob?.phase == .pending)

        let done = Data(#"{"output":{"task_id":"abc","task_status":"SUCCEEDED","video_url":"https://cdn.example.com/a.mp4"}}"#.utf8)
        let doneJob = try? PayloadParse.videoJob(from: done)
        check("视频任务完成", doneJob?.phase == .done && doneJob?.videoURL?.absoluteString.contains("a.mp4") == true)

        let html = #"<h2><a href="https://item.jd.com/100.html">亚麻西装外套</a></h2><h2><a href="https://www.microsoft.com/help">帮助</a></h2>"#
        let hits = PayloadParse.htmlResults(html)
        check("网页标题解析", hits.count == 1 && hits[0].title == "亚麻西装外套")

        let shopping = Data(#"{"shopping_results":[{"title":"亚麻外套","price":"¥399","link":"https://item.jd.com/1.html","thumbnail":"https://img.example/a.jpg","source":"京东"}]}"#.utf8)
        let products = PayloadParse.products(from: shopping)
        check("购物结果解析", products.count == 1 && products[0].price == "¥399" && products[0].platform == "京东")

        let chat = Data(#"{"choices":[{"message":{"content":"米白色 亚麻 西装外套"}}]}"#.utf8)
        check("对话搜索词", PayloadParse.chatText(from: chat)?.contains("亚麻") == true)

        var form = Multipart()
        form.field("prompt", "外套")
        form.file("image", filename: "person.jpg", mime: "image/jpeg", data: Data([0x01, 0x02]))
        form.file("image", filename: "ref-1.jpg", mime: "image/jpeg", data: Data([0x03]))
        form.finish()
        let body = String(data: form.body, encoding: .utf8) ?? ""
        let closing = body.components(separatedBy: "--\(form.boundary)--").count - 1
        check("表单含两张图", body.contains("person.jpg") && body.contains("ref-1.jpg") && closing == 1)

        let partial = Data(#"{"imageKey":"sk-test"}"#.utf8)
        let decoded = try? JSONDecoder().decode(Settings.self, from: partial)
        check("旧设置缺字段仍可读", decoded?.imageKey == "sk-test" && decoded?.imageModel == "qwen-image-2.0-pro")
        if let decoded {
            let encoded = try? JSONEncoder().encode(decoded)
            let again = encoded.flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
            check("设置可以存回", again?.imageKey == "sk-test")
        } else {
            check("设置可以存回", false)
        }

        let color = CGColorSpaceCreateDeviceRGB()
        if let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: color, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           let frame = context.makeImage(),
           let gif = MediaKit.gifData(frames: [frame, frame], delay: 0.1) {
            check("动图文件头", gif.starts(with: Data("GIF".utf8)))
        } else {
            check("动图文件头", false)
        }

        if failed > 0 {
            print("衣镜自测失败 \(failed)")
            exit(1)
        }
        print("衣镜自测通过")
    }

    private static func step(_ name: String) -> DesignStep {
        DesignStep(id: UUID(), filename: name, prompt: name, createdAt: Date(), kind: "设计")
    }
}
