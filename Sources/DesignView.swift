import SwiftUI
import UniformTypeIdentifiers

struct DesignView: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        VStack(spacing: 0) {
            if !model.settings.seenGuide {
                guide
            }
            HStack(spacing: 0) {
                personRail
                Rectangle().fill(Palette.line).frame(width: 1)
                preview
                Rectangle().fill(Palette.line).frame(width: 1)
                inspector
            }
        }
    }

    private var guide: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("先选人，再改衣服，然后去找能买的。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("上传自己的照片，或用默认模特。参考图用来说明版型、颜色和面料。生成之后可以撤销、重做。寻购、社区、工坊和动图都从当前这套造型出发。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("知道了") { model.dismissGuide() }
                .buttonStyle(QuietButton())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Palette.accent.opacity(0.06))
    }

    private var personRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(text: "造型名称")
                TextField("造型名称", text: nameBinding)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.85)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
                SectionLabel(text: "人物")
                personDrop
                Text("原图。生成设计后，中间的大图会换成新衣服。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Button("我的照片") { model.pickPerson = true }
                        .buttonStyle(QuietButton())
                }
                HStack(spacing: 6) {
                    modelButton("女模", "woman")
                    modelButton("男模", "man")
                    modelButton("中性", "neutral")
                }
                Text("不上传照片时，用这三位默认模特。上传后，设计会尽量保住脸和姿势。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
                SectionLabel(text: "参考图")
                referenceDrop
                if model.look.references.isEmpty {
                    Text("可以放平铺的衣服、秀场图或街拍。千问最多 2 张，其他接口最多 4 张。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(model.look.references, id: \.self) { name in
                            ZStack(alignment: .topTrailing) {
                                FitPhoto(image: model.picture(name), empty: "")
                                    .frame(width: 72, height: 92)
                                    .background(Palette.paperDeep)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button {
                                    model.removeReference(name)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Circle().fill(Palette.ink.opacity(0.72)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
                Button("添加参考图") { model.pickReference = true }
                    .buttonStyle(QuietButton())
            }
            .padding(16)
        }
        .frame(width: 248)
    }

    private var personDrop: some View {
        DropZone(hint: "把照片拖到这里") {
            FitPhoto(image: model.picture(model.look.history.steps.first?.filename), empty: "还没有人物")
                .padding(8)
        } onDrop: { providers in
            model.takeProviders(providers, asPerson: true)
        }
        .frame(height: 168)
    }

    private var referenceDrop: some View {
        DropZone(hint: "松手即可加入") {
            Text(model.look.references.isEmpty ? "把衣服图拖到这里" : "继续拖入参考图")
                .font(.system(size: 12))
                .foregroundStyle(Palette.faint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } onDrop: { providers in
            model.takeProviders(providers, asPerson: false)
        }
        .frame(height: 64)
    }

    private var preview: some View {
        VStack(spacing: 0) {
            ZStack {
                Palette.paperDeep
                FitPhoto(image: model.picture(model.look.history.current.filename), empty: "没有图片")
                    .padding(28)
                    .shadow(color: .black.opacity(0.12), radius: 22, y: 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                let history = model.look.history
                Text("\(history.current.kind)  \(history.cursor + 1)/\(history.steps.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(history.current.prompt)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(model.look.history.steps.enumerated()), id: \.element.id) { index, step in
                        Button {
                            model.jump(index)
                        } label: {
                            FitPhoto(image: model.picture(step.filename), empty: "")
                                .frame(width: 54, height: 72)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(index == model.look.history.cursor ? Palette.accent : Palette.line, lineWidth: index == model.look.history.cursor ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(step.kind)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "品类")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(Wardrobe.categories, id: \.self) { item in
                        Chip(title: item, selected: model.look.category == item) {
                            model.setCategory(item)
                        }
                    }
                }
                SectionLabel(text: "设计说明")
                ZStack(alignment: .topLeading) {
                    if model.look.note.isEmpty {
                        Text("例如：米白色亚麻西装外套，宽松，替换现在的上衣")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.faint)
                            .padding(.top, 8)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: noteBinding)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                }
                .padding(8)
                .background(Color.white.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                Button {
                    model.design()
                } label: {
                    Text(model.busy == nil ? "生成设计" : "正在设计…")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButton())
                .disabled(model.busy != nil)
                .keyboardShortcut(.return, modifiers: .command)
                Text("调用设置里的图像编辑 API。人物是第一张图，参考图跟在后面。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
                Button("导出当前图片") { model.exportCurrentImage() }
                    .buttonStyle(QuietButton())
            }
            .padding(16)
        }
        .frame(width: 308)
    }

    private func modelButton(_ title: String, _ id: String) -> some View {
        Button(title) { model.useDefaultModel(id) }
            .buttonStyle(QuietButton())
    }

    private var nameBinding: Binding<String> {
        Binding(get: { model.look.name }, set: { model.setName($0) })
    }

    private var noteBinding: Binding<String> {
        Binding(get: { model.look.note }, set: { model.setNote($0) })
    }
}

struct DropZone<Content: View>: View {
    var hint: String
    @ViewBuilder var content: () -> Content
    var onDrop: ([NSItemProvider]) -> Void
    @State private var targeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.45))
            content()
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(targeted ? Palette.accent : Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            if targeted {
                Text(hint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.accent)
            }
        }
        .onDrop(of: [UTType.image], isTargeted: $targeted) { providers in
            onDrop(providers)
            return true
        }
    }
}
