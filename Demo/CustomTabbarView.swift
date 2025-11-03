//
//  CustomTabbarView.swift
//  Demo
//
//  Created by Daniel Hu on 2025/11/3.
//

import Cocoa

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
