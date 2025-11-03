//
//  ViewController.swift
//  Demo
//
//  Created by Daniel Hu on 2025/11/3.
//

import Cocoa

class MainSplitViewController: NSSplitViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebar = SidebarViewController()
        let splitItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        addSplitViewItem(splitItem)
        
        let content = ContentViewController()
        let contentItem = NSSplitViewItem(viewController: content)
        addSplitViewItem(contentItem)
    }

}

