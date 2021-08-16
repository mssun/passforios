//
//  UIViewExtension.swift
//  passKit
//
//  Created by Yishi Lin on 2018/4/11.
//  Copyright © 2018 Yishi Lin. All rights reserved.
//

import Foundation

extension UIView {
    // Save anchors: https://stackoverflow.com/questions/46317061/use-safe-area-layout-programmatically
    var safeTopAnchor: NSLayoutYAxisAnchor {
        safeAreaLayoutGuide.topAnchor
    }

    var safeLeftAnchor: NSLayoutXAxisAnchor {
        safeAreaLayoutGuide.leftAnchor
    }

    var safeRightAnchor: NSLayoutXAxisAnchor {
        safeAreaLayoutGuide.rightAnchor
    }

    var safeBottomAnchor: NSLayoutYAxisAnchor {
        safeAreaLayoutGuide.bottomAnchor
    }
}
