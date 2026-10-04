import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("设置")
                        .font(Face.display(28))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button("完成") { dismiss() }
                        .buttonStyle(PrimaryButton())
                }
                Text("图像编辑和动图都走你自己的 API。密钥保存在这台 Mac 的「\(Store.settingsURL.path)」。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .textSelection(.enabled)
                presetRow
                group("图像编辑") {
                    stylePicker
                    labeled("基址", text: $model.settings.imageBase, prompt: "https://dashscope.aliyuncs.com/api/v1")
                    labeled("路径", text: $model.settings.imagePath, prompt: "/services/aigc/multimodal-generation/generation")
                    labeled("模型", text: $model.settings.imageModel, prompt: "qwen-image-2.0-pro")
                    labeled("尺寸", text: $model.settings.imageSize, prompt: "1024*1536")
                    authPicker($model.settings.imageAuth)
                    secure("密钥", text: $model.settings.imageKey)
                }
                group("图生视频") {
                    Picker("方式", selection: $model.settings.videoStyle) {
                        Text("万相").tag("wan")
                        Text("通用 JSON").tag("generic")
                        Text("可灵").tag("kling")
                        Text("OpenAI").tag("openai")
                    }
                    .pickerStyle(.segmented)
                    labeled("基址", text: $model.settings.videoBase, prompt: "https://dashscope.aliyuncs.com/api/v1")
                    labeled("创建路径", text: $model.settings.videoCreatePath, prompt: "/services/aigc/video-generation/video-synthesis")
                    labeled("状态路径", text: $model.settings.videoStatusPath, prompt: "/tasks/{id}")
                    labeled("模型", text: $model.settings.videoModel, prompt: "wan2.6-i2v-flash")
                    Stepper(value: $model.settings.videoSeconds, in: 2...15) {
                        Text("时长 \(model.settings.videoSeconds) 秒")
                            .font(.system(size: 13))
                    }
                    authPicker($model.settings.videoAuth)
                    secure("密钥", text: $model.settings.videoKey)
                }
                group("全网搜索") {
                    Picker("方式", selection: $model.settings.searchMode) {
                        Text("网页").tag("web")
                        Text("SerpAPI").tag("serpapi")
                        Text("自定义").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    labeled("自定义地址", text: $model.settings.searchBase, prompt: "https://example.com/search")
                    authPicker($model.settings.searchAuth)
                    secure("搜索密钥", text: $model.settings.searchKey)
                    Text("网页方式会抓取必应和百度的公开搜索结果，并始终提供淘宝、天猫、京东、拼多多、唯品会、亚马逊和 FARFETCH 的搜索入口。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                group("看图写搜索词") {
                    Toggle("搜索前先让对话模型看当前衣服", isOn: $model.settings.useChatForQuery)
                        .toggleStyle(.checkbox)
                    labeled("对话基址", text: $model.settings.chatBase, prompt: "https://dashscope.aliyuncs.com/compatible-mode/v1")
                    labeled("对话模型", text: $model.settings.chatModel, prompt: "qwen-vl-plus")
                    secure("对话密钥", text: $model.settings.chatKey)
                    Text("密钥留空时，会使用图像接口的密钥。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                }
                group("社区和工坊") {
                    labeled("你的名字", text: $model.settings.authorName, prompt: "我")
                    labeled("论坛地址", text: $model.settings.forumURL, prompt: "https://example.com/posts")
                    labeled("工坊地址", text: $model.settings.atelierURL, prompt: "https://example.com/briefs")
                    Text("地址留空时，帖子和量产需求只存在本机。填写后按 JSON 提交，图片用 image_base64。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup("接口约定") {
                    Text(contract)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                HStack {
                    Button("在访达中显示数据") { model.revealStorage() }
                        .buttonStyle(QuietButton())
                    Spacer()
                }
            }
            .padding(22)
        }
        .background(Palette.paper)
        .preferredColorScheme(.light)
    }

    private var stylePicker: some View {
        Picker("方式", selection: $model.settings.imageStyle) {
            Text("OpenAI 表单").tag("openai")
            Text("JSON").tag("json")
            Text("千问").tag("qwen")
        }
        .pickerStyle(.segmented)
    }

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "填入预设")
            WrapPresets(model: model)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Face.display(20))
                .foregroundStyle(Palette.ink)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    private func labeled(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func secure(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            SecureField("粘贴密钥", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func authPicker(_ selection: Binding<String>) -> some View {
        Picker("鉴权", selection: selection) {
            Text("Bearer").tag("bearer")
            Text("x-api-key").tag("x-api-key")
            Text("原样 Authorization").tag("raw")
        }
        .pickerStyle(.segmented)
    }

    private var contract: String {
        """
        图像 · OpenAI
        POST {基址}{路径}  multipart
        字段 model、prompt、size、image（可重复，第一张是人物）
        返回 data[0].b64_json 或 data[0].url

        图像 · JSON
        POST JSON：model、prompt、size、images（data URL，第一张是人物）
        返回同上，或 image / b64_json

        图像 · 千问
        POST {基址}/services/aigc/multimodal-generation/generation
        Authorization: Bearer 百炼 API Key
        model 例如 qwen-image-2.0-pro
        input.messages[0].content：先放 1 到 3 张 {"image":"data:image/jpeg;base64,..."}，最后一条 {"text":"编辑说明"}
        第一张是人物，后面最多两张参考图
        parameters.size 用星号，例如 1024*1536
        返回 output.choices[0].message.content[0].image，是一张 24 小时内有效的图片地址

        视频 · 万相
        POST {基址}/services/aigc/video-generation/video-synthesis
        请求头 X-DashScope-Async: enable
        model 例如 wan2.6-i2v-flash
        input.prompt、input.img_url（data URL）
        parameters.resolution、duration、prompt_extend、audio、watermark
        返回 output.task_id
        GET {基址}/tasks/{task_id}
        task_status 为 SUCCEEDED 时读取 output.video_url

        视频 · 通用
        POST JSON：model、prompt、image（data URL）、duration、aspect_ratio
        返回 id 或 task_id。再 GET 状态路径，把 {id} 换成任务号
        完成时读 video_url 或 url

        视频 · 可灵
        POST /v1/videos/image2video
        model_name、image（纯 base64）、prompt、duration、mode=std
        返回 data.task_id
        GET 同一路径/{id}，完成时 data.task_result.videos[0].url

        视频 · OpenAI
        POST multipart /videos：model、prompt、seconds、size、input_reference
        GET /videos/{id}，完成后 GET /videos/{id}/content

        搜索 · 自定义
        POST {地址}  {"query":"..."}
        返回 items：[{title, price, url, image, platform, shop}]

        论坛与工坊
        POST JSON：title、body 或 spec、quantity、budget、contact、image_base64
        """
    }
}

struct WrapPresets: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
            preset("OpenAI 图像", "openai-image")
            preset("JSON 图像", "json-image")
            preset("千问图像", "qwen-image")
            preset("万相视频", "wan-video")
            preset("通用视频", "generic-video")
            preset("可灵", "kling")
            preset("OpenAI 视频", "openai-video")
            preset("网页搜索", "web")
            preset("SerpAPI", "serpapi")
        }
    }

    private func preset(_ title: String, _ id: String) -> some View {
        Button(title) { model.applyPreset(id) }
            .buttonStyle(QuietButton())
    }
}
