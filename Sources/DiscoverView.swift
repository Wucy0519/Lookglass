import SwiftUI

struct DiscoverView: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    FitPhoto(image: model.picture(model.look.history.current.filename), empty: "")
                        .frame(width: 78, height: 104)
                        .background(Palette.paperDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("按这套衣服去找")
                            .font(Face.display(26))
                            .foregroundStyle(Palette.ink)
                        Text(model.look.note.isEmpty ? "还没有设计说明。可以先写搜索词，或回到造型页生成衣服。" : model.look.note)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(3)
                        Text(model.look.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.moss)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    TextField("搜索词，例如：米白色 亚麻 西装外套", text: searchBinding)
                        .textFieldStyle(.roundedBorder)
                    Button("复制") { model.copySearch() }
                        .buttonStyle(QuietButton())
                }
                Toggle(isOn: chatBinding) {
                    Text("让 AI 看图提炼搜索词")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ink)
                }
                .toggleStyle(.checkbox)
                HStack(spacing: 8) {
                    Button("全网搜索同款") { model.search() }
                        .buttonStyle(PrimaryButton())
                        .disabled(model.busy != nil)
                    Button("发到社区") { model.startPost() }
                        .buttonStyle(QuietButton())
                    Button("交给工坊") { model.page = .atelier }
                        .buttonStyle(QuietButton())
                }
                SectionLabel(text: "平台入口")
                Text("这些会打开淘宝、京东、亚马逊等平台的搜索页，方便直接购买。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(model.marketLinks) { hit in
                        ProductCard(hit: hit) { model.open(hit.url) }
                    }
                }
                SectionLabel(text: "网页线索")
                if model.webHits.isEmpty {
                    Text("点「全网搜索同款」后，这里会列出网页上的相近结果。没有抓到时，仍然可以用上面的平台入口。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(model.webHits) { hit in
                            ProductCard(hit: hit) { model.open(hit.url) }
                        }
                    }
                }
            }
            .padding(22)
        }
        .onAppear { model.ensureSearchDraft() }
    }

    private var searchBinding: Binding<String> {
        Binding(get: { model.look.searchText }, set: { model.setSearchText($0) })
    }

    private var chatBinding: Binding<Bool> {
        Binding(
            get: { model.settings.useChatForQuery },
            set: { model.settings.useChatForQuery = $0 }
        )
    }
}

struct ProductCard: View {
    var hit: ProductHit
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 10) {
                if let imageURL = hit.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Palette.paperDeep
                        }
                    }
                    .frame(width: 52, height: 68)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(hit.platform)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    Text(hit.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !hit.price.isEmpty {
                        Text(hit.price)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.moss)
                    }
                    Text(hit.shop.isEmpty ? "打开" : hit.shop)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
