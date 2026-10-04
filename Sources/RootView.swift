import SwiftUI

struct RootView: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Palette.line).frame(width: 1)
                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.paper)
        .preferredColorScheme(.light)
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
                .frame(width: 680, height: 760)
        }
        .sheet(isPresented: $model.showComposer) {
            ComposerSheet(model: model)
                .frame(width: 520, height: 480)
        }
        .alert("没有完成", isPresented: errorShown) {
            Button("去设置") { model.showSettings = true }
            Button("关闭", role: .cancel) {}
        } message: {
            Text(model.error ?? "")
        }
        .alert("更换人物？", isPresented: $model.confirmReplace) {
            Button("更换", role: .destructive) { model.confirmPersonReplace() }
            Button("取消", role: .cancel) { model.cancelPersonReplace() }
        } message: {
            Text("当前造型上的设计步骤会被清掉。")
        }
        .alert("删除这个造型？", isPresented: $model.confirmDeleteLook) {
            Button("删除", role: .destructive) { model.deleteActiveLook() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这个造型的步骤会从列表里去掉。")
        }
        .fileImporter(isPresented: $model.pickPerson, allowedContentTypes: [.image]) { result in
            if case let .success(url) = result { model.importFile(url, asPerson: true) }
        }
        .fileImporter(isPresented: $model.pickReference, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                for url in urls.prefix(4) { model.importFile(url, asPerson: false) }
            }
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(
            get: { model.error != nil },
            set: { if !$0 { model.error = nil } }
        )
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("衣镜")
                .font(Face.display(22))
                .foregroundStyle(Palette.ink)
                .padding(.leading, 78)
            Menu {
                ForEach(model.looks) { look in
                    Button(look.name) { model.selectLook(look.id) }
                }
                Divider()
                Button("新建造型") { model.newLook() }
                Button("删除当前造型") { model.askDeleteLook() }
            } label: {
                HStack(spacing: 4) {
                    Text(model.look.name)
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Palette.ink)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Text(model.status)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            Spacer()
            if let busy = model.busy {
                ProgressView().controlSize(.small)
                Text(busy)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                Button("取消") { model.cancelJob() }
                    .buttonStyle(QuietButton())
            }
            Button(action: model.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(QuietButton())
            .disabled(!model.canUndo || model.busy != nil)
            .help("撤销")
            Button(action: model.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(QuietButton())
            .disabled(!model.canRedo || model.busy != nil)
            .help("重做")
            Button {
                model.showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(QuietButton())
            .help("设置")
            .padding(.trailing, 16)
        }
        .frame(height: 54)
    }

    private var sidebar: some View {
        VStack(spacing: 6) {
            ForEach(StudioPage.allCases) { item in
                Button {
                    model.page = item
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .medium))
                        Text(item.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(model.page == item ? Palette.accent : Palette.muted)
                    .frame(width: 76, height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(model.page == item ? Palette.accent.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 14)
        .frame(width: 96)
        .background(Palette.paperDeep.opacity(0.55))
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .design:
            DesignView(model: model)
        case .shop:
            DiscoverView(model: model)
        case .forum:
            CommunityView(model: model)
        case .atelier:
            AtelierView(model: model)
        case .motion:
            MotionView(model: model)
        }
    }
}

struct ComposerSheet: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("发到社区")
                .font(Face.display(26))
                .foregroundStyle(Palette.ink)
            Text("帖子会留在这台 Mac 上。如果设置里填了论坛地址，会同时提交一份。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            TextField("标题", text: $model.draftTitle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $model.draftBody)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.white.opacity(0.8))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
            HStack {
                if let image = model.picture(model.draftImage) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 56)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                Button("取消") { model.showComposer = false }
                    .buttonStyle(QuietButton())
                Button("发布") { model.publishDraft() }
                    .buttonStyle(PrimaryButton())
            }
        }
        .padding(22)
        .background(Palette.paper)
        .preferredColorScheme(.light)
    }
}
