//
//  CustomTabView.swift
//  Demo
//
//  Created by Daniel Hu on 2025/11/4.
//

import Cocoa

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
        layer?.masksToBounds = false  // 允许阴影显示
        
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
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
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

class StretchableLabel: NSTextField {
    override var intrinsicContentSize: NSSize {
        // 忽略文本宽度，只保留高度
        let original = super.intrinsicContentSize
        return NSSize(width: NSView.noIntrinsicMetric, height: original.height)
    }
}
