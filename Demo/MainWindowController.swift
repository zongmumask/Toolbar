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
            .tabbarItem
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
            tabbarView.layer?.backgroundColor = NSColor.red.cgColor
            toolbarItem.view = tabbarView
            toolbarItem.minSize = NSSize(width: 200, height: 36)
            toolbarItem.maxSize = NSSize(width: .greatestFiniteMagnitude, height: 36.0)
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
    
    private let titleLabel = NSTextField(labelWithString: "")
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
}

// MARK: - Custom Tabbar View
class CustomTabbarView: NSView {
    private var tabs: [TabItem] = []
    private var tabViews: [CustomTabView] = []
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let plusButton = NSButton()
    
    private var draggedTabIndex: Int?
    private var draggedTabView: CustomTabView?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupInitialTabs()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupInitialTabs()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 滚动视图设置
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        // 内容视图
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        // Plus按钮
        plusButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        plusButton.imageScaling = .scaleProportionallyDown
        plusButton.isBordered = false
        plusButton.bezelStyle = .circular
        plusButton.target = self
        plusButton.action = #selector(addNewTab)
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(plusButton)
        
        // 约束
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: plusButton.leadingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            plusButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            plusButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 24),
            plusButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupInitialTabs() {
        addTab(title: "Tab 1")
        addTab(title: "Tab 2")
        addTab(title: "Tab 3")
        if !tabs.isEmpty {
            selectTab(at: 0)
        }
    }
    
    @objc private func addNewTab() {
        let newTabTitle = "Tab \(tabs.count + 1)"
        addTab(title: newTabTitle)
        selectTab(at: tabs.count - 1)
    }
    
    private func addTab(title: String) {
        let tabItem = TabItem(title: title)
        tabs.append(tabItem)
        
        let tabView = CustomTabView(tabItem: tabItem)
        tabView.onClose = { [weak self] in
            self?.closeTab(tabItem: tabItem)
        }
        tabView.onSelect = { [weak self] in
            if let index = self?.tabs.firstIndex(where: { $0.id == tabItem.id }) {
                self?.selectTab(at: index)
            }
        }
        
        // 添加拖动手势
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        tabView.addGestureRecognizer(panGesture)
        
        tabViews.append(tabView)
        contentView.addSubview(tabView)
        
        layoutTabs()
    }
    
    private func closeTab(tabItem: TabItem) {
        guard tabs.count > 1 else { return } // 至少保留一个标签页
        
        if let index = tabs.firstIndex(where: { $0.id == tabItem.id }) {
            let wasSelected = tabItem.isSelected
            
            tabs.remove(at: index)
            let tabView = tabViews.remove(at: index)
            tabView.removeFromSuperview()
            
            if wasSelected && !tabs.isEmpty {
                let newIndex = min(index, tabs.count - 1)
                selectTab(at: newIndex)
            }
            
            layoutTabs()
        }
    }
    
    private func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        
        // 取消所有选中状态
        tabs.forEach { $0.isSelected = false }
        tabViews.forEach { $0.updateAppearance() }
        
        // 选中指定标签页
        tabs[index].isSelected = true
        tabViews[index].updateAppearance()
    }
    
    private func layoutTabs() {
        let tabWidth: CGFloat = 150
        let tabHeight: CGFloat = 28
        let spacing: CGFloat = 4
        
        for (index, tabView) in tabViews.enumerated() {
            tabView.translatesAutoresizingMaskIntoConstraints = false
            tabView.removeFromSuperview()
            contentView.addSubview(tabView)
            
            NSLayoutConstraint.activate([
                tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: CGFloat(index) * (tabWidth + spacing)),
                tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                tabView.widthAnchor.constraint(equalToConstant: tabWidth),
                tabView.heightAnchor.constraint(equalToConstant: tabHeight)
            ])
        }
        
        // 更新内容视图大小
        let totalWidth = CGFloat(tabViews.count) * (tabWidth + spacing)
        contentView.frame = NSRect(x: 0, y: 0, width: max(totalWidth, scrollView.frame.width), height: scrollView.frame.height)
    }
    
    // MARK: - 拖动排序功能
    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard let tabView = gesture.view as? CustomTabView else { return }
        
        switch gesture.state {
        case .began:
            draggedTabView = tabView
            if let index = tabViews.firstIndex(of: tabView) {
                draggedTabIndex = index
            }
            
        case .changed:
            let translation = gesture.translation(in: contentView)
            tabView.frame.origin.x += translation.x
            gesture.setTranslation(.zero, in: contentView)
            
            // 检查是否需要重新排序
            checkForReordering(draggedTabView: tabView)
            
        case .ended, .cancelled:
            // 重新布局所有标签页
            layoutTabs()
            draggedTabView = nil
            draggedTabIndex = nil
            
        default:
            break
        }
    }
    
    private func checkForReordering(draggedTabView: CustomTabView) {
        guard let draggedIndex = draggedTabIndex else { return }
        
        let draggedCenter = draggedTabView.frame.midX
        
        for (index, tabView) in tabViews.enumerated() {
            if index == draggedIndex { continue }
            
            let tabCenter = tabView.frame.midX
            
            if draggedIndex < index && draggedCenter > tabCenter {
                // 向右拖动
                swapTabs(from: draggedIndex, to: index)
                draggedTabIndex = index
                break
            } else if draggedIndex > index && draggedCenter < tabCenter {
                // 向左拖动
                swapTabs(from: draggedIndex, to: index)
                draggedTabIndex = index
                break
            }
        }
    }
    
    private func swapTabs(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex && fromIndex >= 0 && toIndex >= 0 && fromIndex < tabs.count && toIndex < tabs.count else { return }
        
        // 交换数据
        tabs.swapAt(fromIndex, toIndex)
        tabViews.swapAt(fromIndex, toIndex)
        
        // 重新布局（除了正在拖动的标签页）
        for (index, tabView) in tabViews.enumerated() {
            if tabView != draggedTabView {
                let tabWidth: CGFloat = 150
                let spacing: CGFloat = 4
                tabView.frame.origin.x = CGFloat(index) * (tabWidth + spacing)
            }
        }
    }
}
