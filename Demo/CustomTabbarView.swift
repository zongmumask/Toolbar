//
//  CustomTabbarView.swift
//  Demo
//
//  Created by Daniel Hu on 2025/11/3.
//

import Cocoa
import QuartzCore

class CustomTabbarView: NSView {
    private var tabs: [TabItem] = []
    private var tabViews: [CustomTabView] = []
    private let plusButton = NSButton()
    
    private var draggedTabIndex: Int?
    private var draggedTabView: CustomTabView?
    private var draggedOriginalIndex: Int?
    private var neighborShiftOffsets: [Int: CGFloat] = [:]
    private var shiftHistory: [Int] = []
    private let reorderAnimationDuration: CFTimeInterval = 0.25
    private let tabSpacing: CGFloat = 6
    private let tabHeight: CGFloat = 28
    private let sideInset: CGFloat = 8
    
    override var mouseDownCanMoveWindow: Bool { false }

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
        
        plusButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        plusButton.imageScaling = .scaleProportionallyDown
        plusButton.isBordered = false
        plusButton.target = self
        plusButton.action = #selector(addNewTab)
        addSubview(plusButton)
    }
    
    override func layout() {
        super.layout()
        layoutTabs(animated: false, ignoreDraggedTabView: true)
    }
    
    private func layoutTabs(animated: Bool = true, ignoreDraggedTabView: Bool = false) {
        let totalWidth = bounds.width
        let plusButtonSize: CGFloat = 24
        let availableWidth = totalWidth - sideInset * 2 - plusButtonSize - tabSpacing
        let tabWidth: CGFloat = tabs.isEmpty ? 0 : (availableWidth - CGFloat(max(tabs.count - 1, 0)) * tabSpacing) / CGFloat(tabs.count)
        let y: CGFloat = (bounds.height - tabHeight) / 2
        
        for (index, tabView) in tabViews.enumerated() {
            // 如果正在拖动该标签，不在这里更新它的位置
            if tabView == draggedTabView && ignoreDraggedTabView { continue }
            let x = sideInset + CGFloat(index) * (tabWidth + tabSpacing)
            let targetFrame = NSRect(x: x, y: y, width: tabWidth, height: tabHeight)
            
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    tabView.animator().frame = targetFrame
                    tabView.layer?.zPosition = tabView == draggedTabView ? 1000 : 0
                } completionHandler: {
                    tabView.layer?.zPosition = 0
                }
            } else {
                tabView.frame = targetFrame
            }
        }
        
        plusButton.frame = NSRect(
            x: totalWidth - sideInset - plusButtonSize,
            y: (bounds.height - plusButtonSize) / 2,
            width: plusButtonSize,
            height: plusButtonSize
        )
    }
    
    private func setupInitialTabs() {
        addTab(title: "Tab 1")
        addTab(title: "Tab 2")
        addTab(title: "Tab 3")
        selectTab(at: 0)
    }
    
    @objc private func addNewTab() {
        let newTitle = "Tab \(tabs.count + 1)"
        addTab(title: newTitle)
        selectTab(at: tabs.count - 1)
        layoutTabs()
    }
    
    private func addTab(title: String) {
        let tabItem = TabItem(title: title)
        tabs.append(tabItem)
        
        let tabView = CustomTabView(tabItem: tabItem)
        tabView.onClose = { [weak self] in self?.closeTab(tabItem: tabItem) }
        tabView.onSelect = { [weak self] in
            if let index = self?.tabs.firstIndex(where: { $0.id == tabItem.id }) {
                self?.selectTab(at: index)
            }
        }
        
        // 拖动手势
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        tabView.addGestureRecognizer(pan)
        
        addSubview(tabView)
        tabViews.append(tabView)
        layoutTabs()
    }
    
    private func closeTab(tabItem: TabItem) {
        guard let index = tabs.firstIndex(where: { $0.id == tabItem.id }) else { return }
        tabs.remove(at: index)
        let tabView = tabViews.remove(at: index)
        tabView.removeFromSuperview()
        
        if tabItem.isSelected && !tabs.isEmpty {
            selectTab(at: min(index, tabs.count - 1))
        }
        layoutTabs()
    }
    
    private func selectTab(at index: Int) {
        for (i, tab) in tabs.enumerated() {
            tab.isSelected = (i == index)
            tabViews[i].updateAppearance(selected: tab.isSelected)
        }
    }

    // MARK: - 拖动排序
    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard let tabView = gesture.view as? CustomTabView else { return }
        switch gesture.state {
        case .began:
            draggedTabView = tabView
            draggedOriginalIndex = tabViews.firstIndex(of: tabView)
            draggedTabIndex = draggedOriginalIndex
            selectTab(at: draggedTabIndex ?? 0)
            tabView.layer?.zPosition = 1000
            
        case .changed:
            let translation = gesture.translation(in: self)
            tabView.frame.origin.x += translation.x
            gesture.setTranslation(.zero, in: self)
            checkForReordering()
            
        case .ended, .cancelled:
            finalizeReorderingIfNeeded()
            draggedTabView = nil
            draggedTabIndex = nil
            draggedOriginalIndex = nil
        default: break
        }
    }
    
    private func checkForReordering() {
        guard let dragged = draggedTabView,
              let draggedIndex = draggedTabIndex else { return }
        
        for (index, other) in tabViews.enumerated() where other != dragged {
            if dragged.frame.midX < other.frame.maxX && index < draggedIndex {
                swapTabs(at: draggedIndex, and: index)
                self.draggedTabIndex = index
                break
            } else if dragged.frame.midX > other.frame.minX && index > draggedIndex {
                swapTabs(at: draggedIndex, and: index)
                self.draggedTabIndex = index
                break
            }
        }
    }
    
    private func swapTabs(at i: Int, and j: Int) {
        guard i != j else { return }
        tabs.swapAt(i, j)
        tabViews.swapAt(i, j)
        layoutTabs(ignoreDraggedTabView: true)
    }
    
    private func finalizeReorderingIfNeeded() {
        guard let dragged = draggedTabView else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dragged.animator().frame.origin.y = (bounds.height - tabHeight) / 2
        }
        layoutTabs()
    }
}
