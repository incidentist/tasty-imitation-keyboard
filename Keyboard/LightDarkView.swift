//
//  LightDarkView.swift
// Base class that knows about dark mode vs. light mode

import UIKit

class LightDarkView: UIView {
    
    var darkMode: Bool {
        didSet {
            if oldValue != darkMode {
                updateAppearance()
            }
        }
    }
    
    var solidColorMode: Bool

    required init(darkMode: Bool, solidColorMode: Bool) {
        self.darkMode = darkMode
        self.solidColorMode = solidColorMode

        super.init(frame: CGRect.zero)

        self.isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.darkMode = false
        self.solidColorMode = false
        
        super.init(coder: aDecoder)

        self.isHidden = true
    }


    func updateAppearance() {
    }

}

