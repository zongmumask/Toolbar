//
//  CustomTabView.swift
//  Demo
//
//  Created by Daniel Hu on 2025/11/4.
//

import Cocoa

class CustomTabView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    var onClose: (() -> Void)?
    var onSelect: (() -> Void)?
    
    private let horizontalPadding: CGFloat = 12
    private let spacing: CGFloat = 4
    private let buttonSize: CGFloat = 16

    init(tabItem: TabItem) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        titleLabel.stringValue = tabItem.title
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeTab)
        addSubview(closeButton)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        
        let labelWidth = max(bounds.width - horizontalPadding * 2 - buttonSize - spacing, 20)
        titleLabel.frame = CGRect(
            x: horizontalPadding,
            y: (bounds.height - titleLabel.intrinsicContentSize.height) / 2,
            width: labelWidth,
            height: titleLabel.intrinsicContentSize.height
        )
        
        closeButton.frame = CGRect(
            x: titleLabel.frame.maxX + spacing,
            y: (bounds.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
    }
    
    @objc private func closeTab() {
        onClose?()
    }

    func updateAppearance(selected: Bool) {
        layer?.backgroundColor = selected ? NSColor.selectedControlColor.cgColor : NSColor.controlBackgroundColor.cgColor
    }
}
