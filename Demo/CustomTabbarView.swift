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
    private let tabStackView = NSStackView()
    private let plusButton = NSButton()
    
    private var draggedTabIndex: Int?
    private var draggedTabView: CustomTabView?
    private var draggedOriginalIndex: Int?
    private var neighborShiftOffsets: [Int: CGFloat] = [:]  // 记录相邻项的位移偏移量
    private var shiftHistory: [Int] = []  // 记录已发生位移的相邻项索引顺序，用于回退
    private let reorderAnimationDuration: CFTimeInterval = 0.4

    private func animateTransform(_ view: NSView, to target: CATransform3D, duration: CFTimeInterval) {
        guard let layer = view.layer else { return }
        let fromTransform = layer.presentation()?.transform ?? layer.transform
        // 先设置模型层到目标值，随后添加补间动画
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = target
        CATransaction.commit()
        let anim = CABasicAnimation(keyPath: "transform")
        anim.fromValue = NSValue(caTransform3D: fromTransform)
        anim.toValue = NSValue(caTransform3D: target)
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.removeAnimation(forKey: "reorderTransform")
        layer.add(anim, forKey: "reorderTransform")
    }
    
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
                draggedOriginalIndex = index
            }
            
            // 添加视觉反馈
            tabView.layer?.shadowOpacity = 0.3
            tabView.layer?.shadowOffset = NSSize(width: 0, height: 2)
            tabView.layer?.shadowRadius = 4
            tabView.layer?.zPosition = 1000
            // 清理相邻位移状态
            neighborShiftOffsets.removeAll()
            shiftHistory.removeAll()
            
        case .changed:
            let translation = gesture.translation(in: tabStackView)
            
            // 使用transform而不是直接修改frame，避免与NSStackView冲突
            tabView.layer?.transform = CATransform3DMakeTranslation(translation.x, 0, 0)
            
            // 检查是否需要重新排序
            checkForReordering(draggedTabView: tabView, translation: translation)
            
        case .ended, .cancelled:
            // 移除视觉效果
            tabView.layer?.shadowOpacity = 0
            
            // 将拖拽项插入到最终索引，并清理相邻项动画
            finalizeReorderingIfNeeded()
            
            // 清理状态
            draggedTabView = nil
            draggedTabIndex = nil
            draggedOriginalIndex = nil
            neighborShiftOffsets.removeAll()
            shiftHistory.removeAll()
            
        default:
            break
        }
    }
    
    private func checkForReordering(draggedTabView: CustomTabView, translation: NSPoint) {
        guard var currentInsertIndex = draggedTabIndex else { return }
        
        // 以拖拽项左右边缘跨越相邻中心为触发条件
        let draggedRight = draggedTabView.frame.maxX + translation.x
        let draggedLeft = draggedTabView.frame.minX + translation.x
        
        // 向右检查：拖拽项的右侧超过右侧相邻项中心时触发
        if currentInsertIndex + 1 <= tabViews.count - 1 {
            let rightIndex = currentInsertIndex + 1
            let rightView = tabViews[rightIndex]
            let rightCenter = rightView.frame.midX
            let rightWidth = rightView.frame.width
            
            if neighborShiftOffsets[rightIndex] == nil && draggedRight > rightCenter {
                animateTransform(rightView, to: CATransform3DMakeTranslation(-rightWidth, 0, 0), duration: reorderAnimationDuration)
                neighborShiftOffsets[rightIndex] = -rightWidth
                shiftHistory.append(rightIndex)
                currentInsertIndex += 1
                draggedTabIndex = currentInsertIndex
            }
        }
        
        // 向左检查：拖拽项的左侧超过左侧相邻项中心时触发
        if currentInsertIndex - 1 >= 0 {
            let leftIndex = currentInsertIndex - 1
            let leftView = tabViews[leftIndex]
            let leftCenter = leftView.frame.midX
            let leftWidth = leftView.frame.width
            
            if neighborShiftOffsets[leftIndex] == nil && draggedLeft < leftCenter {
                animateTransform(leftView, to: CATransform3DMakeTranslation(leftWidth, 0, 0), duration: reorderAnimationDuration)
                neighborShiftOffsets[leftIndex] = leftWidth
                shiftHistory.append(leftIndex)
                currentInsertIndex -= 1
                draggedTabIndex = currentInsertIndex
            }
        }
        
        // 回退处理：当拖拽边缘回到未超过相邻中心时，撤销最近一次相邻项动画
        if let lastShifted = shiftHistory.last {
            let lastView = tabViews[lastShifted]
            let lastCenter = lastView.frame.midX
            let offset = neighborShiftOffsets[lastShifted] ?? 0
            if offset < 0 {
                // 最近一次是向右经过（右侧相邻左移）：如果拖拽视图的右边缘回到该相邻项中心左侧，则撤销
                if draggedRight < lastCenter {
                    animateTransform(lastView, to: CATransform3DIdentity, duration: reorderAnimationDuration)
                    neighborShiftOffsets.removeValue(forKey: lastShifted)
                    shiftHistory.removeLast()
                    draggedTabIndex = max((draggedTabIndex ?? 0) - 1, 0)
                }
            } else if offset > 0 {
                // 最近一次是向左经过（左侧相邻右移）：如果拖拽视图的左边缘回到该相邻项中心右侧，则撤销
                if draggedLeft > lastCenter {
                    animateTransform(lastView, to: CATransform3DIdentity, duration: reorderAnimationDuration)
                    neighborShiftOffsets.removeValue(forKey: lastShifted)
                    shiftHistory.removeLast()
                    draggedTabIndex = min((draggedTabIndex ?? 0) + 1, tabViews.count - 1)
                }
            }
        }
    }

    private func finalizeReorderingIfNeeded() {
        guard let originalIndex = draggedOriginalIndex, let finalIndex = draggedTabIndex, let draggedView = draggedTabView else { return }
        
        // 相邻项不做动画复位，直接清空位移（拖拽过程中已重排）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (idx, _) in neighborShiftOffsets {
            if idx >= 0 && idx < tabViews.count {
                tabViews[idx].layer?.transform = CATransform3DIdentity
            }
        }
        CATransaction.commit()
        
        // 更新数据模型顺序：把拖拽项从原位置移除并插入到finalIndex
        let draggedItem = tabs[originalIndex]
        tabs.remove(at: originalIndex)
        tabViews.remove(at: originalIndex)
        
        // 直接按最终索引插入（finalIndex 表示拖拽后的目标位置）
        tabs.insert(draggedItem, at: finalIndex)
        tabViews.insert(draggedView, at: finalIndex)
        
        // 使用NSStackView的重新排序功能进行最终回插入
        tabStackView.removeArrangedSubview(draggedView)
        tabStackView.insertArrangedSubview(draggedView, at: finalIndex)

        // 仅对拖拽项做回位动画（从当前平移到最终位置）
        animateTransform(draggedView, to: CATransform3DIdentity, duration: reorderAnimationDuration)
    }
}
