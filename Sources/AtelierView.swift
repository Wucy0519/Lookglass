import SwiftUI

struct AtelierView: View {
    @ObservedObject var model: StudioModel
    @State private var title = ""
    @State private var spec = ""
    @State private var quantity = 1
    @State private var budget = ""
    @State private var contact = ""

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("交给工坊")
                        .font(Face.display(28))
                        .foregroundStyle(Palette.ink)
                    Text("把当前衣服整理成一份量产需求。没有工坊地址时先存在本机；填了地址会按 JSON 提交。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 12) {
                        FitPhoto(image: model.picture(model.look.history.current.filename), empty: "")
                            .frame(width: 72, height: 96)
                            .background(Palette.paperDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("用当前造型填写") { fillFromLook() }
                            .buttonStyle(QuietButton())
                    }
                    field("款式名称", text: $title)
                    SectionLabel(text: "成衣要求")
                    TextEditor(text: $spec)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.white.opacity(0.78))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                    Stepper(value: $quantity, in: 1...9999) {
                        Text("数量 \(quantity)")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                    }
                    field("预算", text: $budget)
                    field("联系方式", text: $contact)
                    Text("联系方式只保存在本机。发送工坊时会一并提交。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                    Button("保存需求") {
                        model.submitBrief(title: title, spec: spec, quantity: quantity, budget: budget, contact: contact)
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(model.busy != nil)
                }
                .padding(22)
            }
            .frame(width: 420)
            Rectangle().fill(Palette.line).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("已记录的需求")
                        .font(Face.display(22))
                        .foregroundStyle(Palette.ink)
                    if model.briefs.isEmpty {
                        Text("还没有提交。左边写好版型、数量和预算后保存。")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.faint)
                    }
                    ForEach(model.briefs) { brief in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(brief.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text(brief.status)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(brief.status == "发送失败" ? Palette.accent : Palette.moss)
                            }
                            Text("\(brief.quantity) 件 · \(brief.budget.isEmpty ? "预算未写" : brief.budget) · \(Clock.short(brief.createdAt))")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                            Text(brief.spec)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(4)
                            if !brief.detail.isEmpty {
                                Text(brief.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.faint)
                            }
                            HStack {
                                if brief.status != "已提交" {
                                    Button("再次发送") { model.resendBrief(brief.id) }
                                        .buttonStyle(QuietButton())
                                }
                                Button("删除") { model.deleteBrief(brief.id) }
                                    .buttonStyle(QuietButton())
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                    }
                }
                .padding(22)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: title)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func fillFromLook() {
        let look = model.look
        if title.isEmpty { title = look.name }
        let query = look.searchText.isEmpty ? OutfitQuery.make(note: look.note, category: look.category) : look.searchText
        spec = """
        品类：\(look.category)
        设计说明：\(look.note.isEmpty ? "见附图" : look.note)
        搜索词：\(query)
        希望按附图打样，并评估量产。
        """
    }
}
