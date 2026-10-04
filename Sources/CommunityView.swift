import SwiftUI

struct CommunityView: View {
    @ObservedObject var model: StudioModel
    @State private var reply = ""

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("社区")
                        .font(Face.display(26))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button("用当前造型发帖") { model.startPost() }
                        .buttonStyle(PrimaryButton())
                }
                .padding(16)
                if model.posts.isEmpty {
                    Text("还没有帖子。把当前造型发出来，留作自己的寻衣记录，或同步到你填的论坛。")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 16)
                    Spacer()
                } else {
                    List(selection: selection) {
                        ForEach(model.posts) { post in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text(Clock.short(post.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.faint)
                            }
                            .padding(.vertical, 4)
                            .tag(post.id)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(width: 300)
            Rectangle().fill(Palette.line).frame(width: 1)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if model.selectedPostID == nil { model.selectedPostID = model.posts.first?.id }
        }
    }

    private var selection: Binding<UUID?> {
        Binding(get: { model.selectedPostID }, set: { model.selectedPostID = $0 })
    }

    @ViewBuilder
    private var detail: some View {
        if let post = model.posts.first(where: { $0.id == model.selectedPostID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.title)
                                .font(Face.display(28))
                                .foregroundStyle(Palette.ink)
                            Text("\(post.author) · \(Clock.short(post.createdAt))")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.faint)
                        }
                        Spacer()
                        Button("删除") { model.deletePost(post.id) }
                            .buttonStyle(QuietButton())
                    }
                    if let image = model.picture(post.imageFilename) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Text(post.body)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                    Divider()
                    Text("回复")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    ForEach(post.replies) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.author) · \(Clock.short(item.createdAt))")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.faint)
                            Text(item.body)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.6)))
                    }
                    HStack {
                        TextField("写一条回复", text: $reply)
                            .textFieldStyle(.roundedBorder)
                        Button("回复") {
                            model.reply(to: post.id, text: reply)
                            reply = ""
                        }
                        .buttonStyle(PrimaryButton())
                    }
                }
                .padding(22)
            }
        } else {
            Text("选一则帖子，或把当前造型发出去。")
                .font(.system(size: 13))
                .foregroundStyle(Palette.faint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
