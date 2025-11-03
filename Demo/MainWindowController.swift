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

// MARK: - Custom Tab View
class CustomTabView: NSView {
    var tabItem: TabItem
    var onClose: (() -> Void)?
    var onSelect: (() -> Void)?
    
    private let titleLabel = StretchableLabel(labelWithString: "")
    private let closeButton = NSButton()
    
    init(tabItem: TabItem) {
        self.tabItem = tabItem
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        
        // 设置标签页样式
        updateAppearance()
        
        // 标题标签
        titleLabel.stringValue = tabItem.title
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置内容压缩阻力和内容拥抱优先级，让titleLabel充分利用可用空间
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        addSubview(titleLabel)
        
        // 关闭按钮
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.isBordered = false
        closeButton.bezelStyle = .circular
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)
        
        // 约束
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        // 点击手势
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(tabClicked))
        addGestureRecognizer(clickGesture)
    }
    
    func updateAppearance() {
        if tabItem.isSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 1
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 0.5
        }
        layer?.cornerRadius = 6
    }
    
    @objc private func tabClicked() {
        onSelect?()
    }
    
    @objc private func closeButtonClicked() {
        onClose?()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        closeButton.isHidden = false
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !tabItem.isSelected {
            closeButton.isHidden = true
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // 重写intrinsicContentSize，让NSStackView的fillEqually分布生效
    override var intrinsicContentSize: NSSize {
        // 对于宽度，返回noIntrinsicMetric让NSStackView决定
        // 对于高度，返回固定值
        return NSSize(width: NSView.noIntrinsicMetric, height: 32)
    }
}

class StretchableLabel: NSTextField {
    override var intrinsicContentSize: NSSize {
        // 忽略文本宽度，只保留高度
        let original = super.intrinsicContentSize
        return NSSize(width: NSView.noIntrinsicMetric, height: original.height)
    }
}
