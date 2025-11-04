//
//  MainWindowController.swift
//  Demo
//
//  Created by Daniel Hu on 2025/11/3.
//

import Cocoa

extension NSToolbarItem.Identifier {
    static let sidebarItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("SidebarItem")
    static let sidebarTrackingSeparator: NSToolbarItem.Identifier = NSToolbarItem.Identifier("SidebarTrackingSeparator")
    static let tabbarItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("TabbarItem")
    static let plusItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("PlusItem")
}

class MainWindowController: NSWindowController {

    var splitViewController: MainSplitViewController? {
        contentViewController as? MainSplitViewController
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        setupToolbar()
    }

    func setupToolbar() {
        let toolbar = NSToolbar(identifier: UUID().uuidString)
        toolbar.showsBaselineSeparator = false
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        self.window?.titleVisibility = .hidden
        self.window?.toolbarStyle = .unified
        self.window?.titlebarSeparatorStyle = .automatic
        self.window?.toolbar = toolbar
    }
    
    @objc func objcToggleFirstPanel() {
        guard let firstSplitView = splitViewController?.splitViewItems.first else { return }
        firstSplitView.animator().isCollapsed.toggle()
    }
}

extension MainWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .sidebarItem,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            .tabbarItem,
            .plusItem
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var items: [NSToolbarItem.Identifier] = [
            .sidebarItem,
            .flexibleSpace
        ]
        items += [
            .sidebarTrackingSeparator,
            .tabbarItem
        ]
        items += [
            .space,
            .plusItem
        ]
        return items
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .sidebarItem:
            let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.sidebarItem)
            toolbarItem.paletteLabel = " Navigator Sidebar"
            toolbarItem.toolTip = "Hide or show the Navigator"
            toolbarItem.isBordered = true
            toolbarItem.target = self
            toolbarItem.action = #selector(self.objcToggleFirstPanel)
            toolbarItem.image = NSImage(
                systemSymbolName: "sidebar.leading",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(.init(scale: .large))
            return toolbarItem
        case .sidebarTrackingSeparator:
            guard let splitViewController else { return nil }

            return NSTrackingSeparatorToolbarItem(
                identifier: .sidebarTrackingSeparator,
                splitView: splitViewController.splitView,
                dividerIndex: 0
            )
        case .tabbarItem:
            let toolbarItem = NSToolbarItem(itemIdentifier: .tabbarItem)
            let tabbarView = CustomTabbarView()
            tabbarView.wantsLayer = true
            toolbarItem.view = tabbarView
            
            NSLayoutConstraint.activate([
                tabbarView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
                tabbarView.heightAnchor.constraint(equalToConstant: 36)
            ])
            
            return toolbarItem
        case .plusItem:
            let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.plusItem)
            toolbarItem.paletteLabel = " Navigator Sidebar"
            toolbarItem.toolTip = "Hide or show the Navigator"
            toolbarItem.isBordered = true
            toolbarItem.target = self
            toolbarItem.action = #selector(self.objcToggleFirstPanel)
            toolbarItem.image = NSImage(
                systemSymbolName: "sidebar.leading",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(.init(scale: .large))
            return toolbarItem
        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }
}

// MARK: - Tab Data Model
class TabItem {
    let id = UUID()
    var title: String
    var isSelected: Bool = false
    
    init(title: String) {
        self.title = title
    }
}

