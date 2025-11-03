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
    private let tabStackView = NSStackView()
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
        
        // 配置StackView
        tabStackView.orientation = .horizontal
        tabStackView.distribution = .fillEqually
        tabStackView.spacing = 4
        tabStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tabStackView)
        
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
            tabStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            tabStackView.trailingAnchor.constraint(equalTo: plusButton.leadingAnchor, constant: -8),
            tabStackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            tabStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            plusButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            plusButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 24),
            plusButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    // NSStackView自动处理布局，移除这些方法
    // override func viewDidEndLiveResize() 和 resizeSubviews 不再需要
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        // NSStackView会自动处理布局，不需要手动调用layoutTabs
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
        tabStackView.addArrangedSubview(tabView)  // 使用StackView API，自动布局
    }
    
    private func closeTab(tabItem: TabItem) {
        guard let index = tabs.firstIndex(where: { $0.id == tabItem.id }) else { return }
        
        tabs.remove(at: index)
        let tabView = tabViews.remove(at: index)
        tabStackView.removeArrangedSubview(tabView)  // 使用StackView API
        tabView.removeFromSuperview()
        
        // 如果关闭的是选中的tab，选择相邻的tab
        if tabItem.isSelected && !tabs.isEmpty {
            let newIndex = min(index, tabs.count - 1)
            selectTab(at: newIndex)
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
    
    // NSStackView自动处理布局，不再需要layoutTabs方法
    
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
            let translation = gesture.translation(in: tabStackView)
            tabView.frame.origin.x += translation.x
            gesture.setTranslation(.zero, in: tabStackView)
            
            // 检查是否需要重新排序
            checkForReordering(draggedTabView: tabView)
            
        case .ended, .cancelled:
            // NSStackView会自动处理布局
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
        
        // 使用NSStackView的重新排序功能
        let tabView = tabViews[toIndex]
        tabStackView.removeArrangedSubview(tabView)
        tabStackView.insertArrangedSubview(tabView, at: toIndex)
    }
}
