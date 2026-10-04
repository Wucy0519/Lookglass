import AppKit
import SwiftUI

@main
enum YijingMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            SelfTest.run()
            return
        }
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.regular)
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = StudioModel()
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        let host = NSHostingController(rootView: RootView(model: model))
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.title = "衣镜"
        window.setContentSize(NSSize(width: 1220, height: 800))
        window.minSize = NSSize(width: 1040, height: 700)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.tabbingMode = .disallowed
        window.backgroundColor = NSColor(srgbRed: 0.965, green: 0.949, blue: 0.925, alpha: 1)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        buildMenu()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于衣镜", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let settings = appMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(NSMenuItem.separator())
        let newer = appMenu.addItem(withTitle: "新建造型", action: #selector(newLook), keyEquivalent: "n")
        newer.target = self
        let export = appMenu.addItem(withTitle: "导出当前图片…", action: #selector(exportImage), keyEquivalent: "e")
        export.target = self
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出衣镜", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "编辑")
        editItem.submenu = edit
        let undo = edit.addItem(withTitle: "撤销", action: #selector(undoDesign), keyEquivalent: "z")
        undo.target = self
        let redo = edit.addItem(withTitle: "重做", action: #selector(redoDesign), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        redo.target = self

        let about = appMenu.item(withTitle: "关于衣镜")
        about?.target = self
        NSApp.mainMenu = main
    }

    @objc private func showSettings() { model.showSettings = true }
    @objc private func newLook() { model.newLook() }
    @objc private func exportImage() { model.exportCurrentImage() }
    @objc private func undoDesign() { model.undo() }
    @objc private func redoDesign() { model.redo() }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "衣镜"
        alert.informativeText = "用参考图设计衣服，再去淘宝、京东、亚马逊这些平台找同款。图像编辑和动图使用你在设置里填写的 API。"
        alert.runModal()
    }
}
