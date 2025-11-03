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
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
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
        
    // MARK: - 拖动排序功能
    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard let tabView = gesture.view as? CustomTabView else { return }
        
        switch gesture.state {
        case .began:
            draggedTabView = tabView
            if let index = tabViews.firstIndex(of: tabView) {
                draggedTabIndex = index
            }
            
            // 添加视觉反馈
            tabView.layer?.shadowOpacity = 0.3
            tabView.layer?.shadowOffset = NSSize(width: 0, height: 2)
            tabView.layer?.shadowRadius = 4
            
        case .changed:
            let translation = gesture.translation(in: tabStackView)
            
            // 使用transform而不是直接修改frame，避免与NSStackView冲突
            tabView.layer?.transform = CATransform3DMakeTranslation(translation.x, 0, 0)
            
            // 检查是否需要重新排序
            checkForReordering(draggedTabView: tabView, translation: translation)
            
        case .ended, .cancelled:
            // 移除视觉效果
            tabView.layer?.shadowOpacity = 0
            tabView.layer?.transform = CATransform3DIdentity
            
            // 清理状态
            draggedTabView = nil
            draggedTabIndex = nil
            
        default:
            break
        }
    }
    
    private func checkForReordering(draggedTabView: CustomTabView, translation: NSPoint) {
        guard let draggedIndex = draggedTabIndex else { return }
        
        // 计算拖动后的中心位置
        let draggedCenter = draggedTabView.frame.midX + translation.x
        
        for (index, tabView) in tabViews.enumerated() {
            if index == draggedIndex { continue }
            
            let tabCenter = tabView.frame.midX
            let tabWidth = tabView.frame.width
            
            // 使用更精确的重叠检测
            if draggedIndex < index && draggedCenter > tabCenter - tabWidth/4 {
                // 向右拖动，当拖动的tab中心超过目标tab的1/4位置时交换
                swapTabs(from: draggedIndex, to: index)
                draggedTabIndex = index
                break
            } else if draggedIndex > index && draggedCenter < tabCenter + tabWidth/4 {
                // 向左拖动，当拖动的tab中心小于目标tab的3/4位置时交换
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
