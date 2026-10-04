import AVKit
import SwiftUI

struct MotionView: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    FitPhoto(image: model.picture(model.look.history.current.filename), empty: "")
                        .frame(width: 92, height: 122)
                        .background(Palette.paperDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("让这个人把衣服穿起来走动")
                            .font(Face.display(28))
                            .foregroundStyle(Palette.ink)
                        Text("选一个场景，调用图生视频 API。生成后可以在这里播放，并导出 GIF。")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(WearScene.allCases) { scene in
                        Button {
                            model.scene = scene
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(scene.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(model.scene == scene ? Palette.accent : Palette.ink)
                                Text(scene.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.muted)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(model.scene == scene ? Palette.accent.opacity(0.08) : Palette.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(model.scene == scene ? Palette.accent : Palette.line, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("生成\(model.scene.title)动图") { model.renderMotion() }
                    .buttonStyle(PrimaryButton())
                    .disabled(model.busy != nil)
                Text("视频接口在设置里填写。人物和衣服以当前造型为准。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                if !clips.isEmpty {
                    SectionLabel(text: "已经生成")
                    ForEach(clips) { clip in
                        ClipRow(model: model, clip: clip)
                    }
                }
            }
            .padding(22)
        }
    }

    private var clips: [MotionClip] {
        model.clips.filter { $0.lookID == nil || $0.lookID == model.look.id }
    }
}

struct ClipRow: View {
    @ObservedObject var model: StudioModel
    var clip: MotionClip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(clip.scene)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(Clock.short(clip.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                Spacer()
                if clip.gifFilename != nil {
                    Button("导出 GIF") { model.exportGIF(clip) }
                        .buttonStyle(QuietButton())
                }
                Button("删除") { model.deleteClip(clip.id) }
                    .buttonStyle(QuietButton())
            }
            if let name = clip.videoFilename {
                ClipPlayer(url: Store.mediaURL(name))
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }
}

struct ClipPlayer: View {
    var url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
    }
}
