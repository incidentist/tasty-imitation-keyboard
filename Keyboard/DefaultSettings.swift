//
//  DefaultSettings.swift
//  TastyImitationKeyboard
//
//  Created by Alexei Baboulevitch on 11/2/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

let LanguagesSection: Int = 2

class ColorScheme
{
    func labelTextColor() -> UIColor {
        return UIColor.gray
    }

    func backTextColor() -> UIColor {
        return UIColor.black
            //UIColor(red: 0/CGFloat(255), green: 122/CGFloat(255), blue: 255/CGFloat(255), alpha: 1)
    }

    func cellBackgroundColor() -> UIColor {
        return UIColor.white.withAlphaComponent(CGFloat(0.25))
    }

    func cellLabelColor() -> UIColor {
        return UIColor.black
    }

    func cellLongLabelColor() -> UIColor {
        return UIColor.gray
    }

    func cellKbdChangerColor() -> UIColor {
        return UIColor.green
    }


    func tableBackgroundColor() -> UIColor {
        return UIColor.white.withAlphaComponent(1.0)
    }

    func sectionLabelColor() -> UIColor {
        return UIColor.black
    }

    func sectionBackgroundColor() -> UIColor {
        return UIColor.white
    }

    func settingsBackgroundColor() -> UIColor {
        return UIColor.white
    }

    func backButtonBackgroundColor() -> UIColor {
        return UIColor.white
    }

    func effectsBackgroundColor() -> UIColor {
        return UIColor.white.withAlphaComponent(1)
    }

    class func ColorSchemeChooser (_ darkMode : Bool) -> ColorScheme
    {
        return darkMode ? DarkColorScheme() : ColorScheme()
    }
}

class DarkColorScheme: ColorScheme
{
    override func labelTextColor() -> UIColor {
        return UIColor.white
    }

    override func backTextColor() -> UIColor {
        return UIColor.white
//        return UIColor(red: 135/CGFloat(255), green: 206/CGFloat(255), blue: 250/CGFloat(255), alpha: 1)
    }

    override func cellBackgroundColor() -> UIColor {
        return UIColor.darkGray.withAlphaComponent(CGFloat(0.5))
    }

    override func cellLabelColor() -> UIColor {
        return UIColor.white
    }

    override func tableBackgroundColor() -> UIColor {
        return UIColor.gray.withAlphaComponent(1.0)
    }

    override func sectionLabelColor() -> UIColor {
        return UIColor.white
    }

    override func sectionBackgroundColor() -> UIColor {
        return UIColor.darkGray.withAlphaComponent(CGFloat(0.5))
    }

    override func settingsBackgroundColor() -> UIColor {
        return UIColor.darkGray.withAlphaComponent(CGFloat(0.5))
    }

    override func effectsBackgroundColor() -> UIColor {
        return UIColor.darkGray.withAlphaComponent(1)
    }

    override func backButtonBackgroundColor() -> UIColor {
        return settingsBackgroundColor()
    }

    override func cellLongLabelColor() -> UIColor {
        return UIColor.white
    }

    override func cellKbdChangerColor() -> UIColor {
        return UIColor.white
    }


}
