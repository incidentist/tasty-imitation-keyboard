//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Alexei Baboulevitch on 6/9/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit
import AudioToolbox

enum TTDeviceType{
	case TTDeviceTypeIPhone4
	case TTDeviceTypeIPhone5
	case TTDeviceTypeIPhone6
	case TTDeviceTypeIPhone6p
	
}

let metrics: [String:Double] = [
    "topBanner": 30
]
func metric(name: String) -> CGFloat { return CGFloat(metrics[name]!) }

// TODO: move this somewhere else and localize
let kAutoCapitalization = "kAutoCapitalization"
let kPeriodShortcut = "kPeriodShortcut"
let kKeyboardClicks = "kKeyboardClicks"
let kSmallLowercase = "kSmallLowercase"
let kActiveLanguageCode = "kActiveLanguageCode"

let vEnglishLanguageCode = "EN"
let vQwertyKeyboardFileName = "QWERTY"

class KeyboardViewController: UIInputViewController {

    let backspaceDelay: NSTimeInterval = 0.5
    let backspaceRepeat: NSTimeInterval = 0.07

    var keyboard: Keyboard!
    var forwardingView: ForwardingView!
    var layout: KeyboardLayout?
    var heightConstraint: NSLayoutConstraint?

    weak var delegate: AlphaKeyboardDelegate?

    var bannerView: SuggestionView?

    var currentMode: Int {
        didSet {
            if oldValue != currentMode {
                setMode(currentMode)
            }
			
			forwardingView.currentMode = currentMode
			forwardingView.keyboard_type = keyboard_type
        }
    }
	
    var backspaceActive: Bool {
        get {
            return (backspaceDelayTimer != nil) || (backspaceRepeatTimer != nil)
        }
    }
    var backspaceDelayTimer: NSTimer?
    var backspaceRepeatTimer: NSTimer?
    
    enum AutoPeriodState {
        case NoSpace
        case FirstSpace
    }
    
    var autoPeriodState: AutoPeriodState = .NoSpace
    var lastCharCountInBeforeContext: Int = 0
    
    var shiftState: ShiftState {
        didSet {
            self.updateKeyCaps(shiftState != .Disabled)
        }
    }
    
    // state tracking during shift tap
    var shiftWasMultitapped: Bool = false
    var shiftStartingState: ShiftState?
    
    var keyboardHeight: CGFloat {
        get {
            return self.heightConstraint?.constant ?? 0
        }

        set {
            self.setHeight(newValue)
        }
    }
	
	var viewLongPopUp:CYRKeyboardButtonView = CYRKeyboardButtonView()
	var button = CYRKeyboardButton()
	
	var keyboard_type: UIKeyboardType!
	var preKeyboardType = UIKeyboardType.Default

    // HACKHACK
    // Since UIApplication.sharedApplication().statusBarOrientation has been deprecated.
    // For now assume interfaceOrientation and device orientation are the same thing.
    // Couldn't get UIDevice.currentDevice().orientation to work even if I wrapped with begin/endGeneratingDeviceOrientationNotifications
    class func getInterfaceOrientation() -> UIInterfaceOrientation
    {
        let screenSize : CGSize = UIScreen.mainScreen().bounds.size
        return screenSize.width < screenSize.height ? UIInterfaceOrientation.Portrait : UIInterfaceOrientation.LandscapeLeft
    }

    private func InitializeLayout()
    {
        self.forwardingView = ForwardingView(frame: CGRectZero, viewController: self)
        self.view.addSubview(self.forwardingView)

        self.bannerView = self.createBanner()
        for button in self.bannerView!.buttons {
            button.addTarget(self, action: #selector(KeyboardViewController.didTapSuggestionButton(_:)), forControlEvents: [.TouchUpInside, .TouchUpOutside, .TouchDragOutside])
            button.addTarget(self, action: #selector(KeyboardViewController.didTTouchDownSuggestionButton(_:)), forControlEvents: [.TouchDown, .TouchDragInside, .TouchDragEnter])
            button.addTarget(self, action: #selector(KeyboardViewController.didTTouchExitDownSuggestionButton(_:)), forControlEvents: [.TouchDragExit, .TouchCancel])
        }

        self.view.insertSubview(self.bannerView!, aboveSubview: self.forwardingView)

        initializePopUp()

    }

    init(delegate: AlphaKeyboardDelegate) {
        self.delegate = delegate
        NSUserDefaults.standardUserDefaults().registerDefaults([
            kAutoCapitalization: true,
            kPeriodShortcut: true,
            kKeyboardClicks: false,
            kSmallLowercase: false,
            kActiveLanguageCode: vEnglishLanguageCode
            ])

        self.shiftState = .Disabled
        self.currentMode = 0

        //sleep(30)
        
        self.currentInterfaceOrientation = KeyboardViewController.getInterfaceOrientation()

        super.init(nibName: nil, bundle: nil)

		InitializeLayout()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(KeyboardViewController.defaultsChanged(_:)), name: NSUserDefaultsDidChangeNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(KeyboardViewController.hideExpandView(_:)), name: "hideExpandViewNotification", object: nil)
    }

    override func viewWillDisappear(animated: Bool) {
        WordStore.CurrentWordStore().persistWords()
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    override func dismissKeyboard() {
        WordStore.CurrentWordStore().persistWords()
    }

    deinit {
        backspaceDelayTimer?.invalidate()
        backspaceRepeatTimer?.invalidate()
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func defaultsChanged(notification: NSNotification) {
        self.updateKeyCaps(self.shiftState.uppercase())
    }
    
    // without this here kludge, the height constraint for the keyboard does not work for some reason
    var kludge: UIView?
    func setupKludge() {
        if self.kludge == nil {
            let kludge = UIView()
            self.view.addSubview(kludge)
            kludge.translatesAutoresizingMaskIntoConstraints = false
            kludge.hidden = true
            
            let a = NSLayoutConstraint(item: kludge, attribute: NSLayoutAttribute.Left, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Left, multiplier: 1, constant: 0)
            let b = NSLayoutConstraint(item: kludge, attribute: NSLayoutAttribute.Right, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Left, multiplier: 1, constant: 0)
            let c = NSLayoutConstraint(item: kludge, attribute: NSLayoutAttribute.Top, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
            let d = NSLayoutConstraint(item: kludge, attribute: NSLayoutAttribute.Bottom, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
            self.view.addConstraints([a, b, c, d])
            
            self.kludge = kludge
        }
    }

    private func layoutHelper()
    {

        let proxy = textDocumentProxy
        self.keyboard = defaultKeyboard(proxy.keyboardType!)

        preKeyboardType = proxy.keyboardType!

        self.layout = self.dynamicType.layoutClass.init(model: self.keyboard, superview: self.forwardingView, layoutConstants: self.dynamicType.layoutConstants, darkMode: self.darkMode(), solidColorMode: self.solidColorMode())

        self.layout?.initialize()
        self.setMode(0)

        self.setupKludge()

        self.updateKeyCaps(self.shiftState.uppercase())
        self.setCapsIfNeeded()

        self.updateAppearances(self.darkMode())
        self.addInputTraitsObservers()

        self.constraintsAdded = true

    }

    /*
    BUG NOTE

    For some strange reason, a layout pass of the entire keyboard is triggered 
    whenever a popup shows up, if one of the following is done:

    a) The forwarding view uses an autoresizing mask.
    b) The forwarding view has constraints set anywhere other than init.

    On the other hand, setting (non-autoresizing) constraints or just setting the
    frame in layoutSubviews works perfectly fine.

    I don't really know what to make of this. Am I doing Autolayout wrong, is it
    a bug, or is it expected behavior? Perhaps this has to do with the fact that
    the view's frame is only ever explicitly modified when set directly in layoutSubviews,
    and not implicitly modified by various Autolayout constraints
    (even though it should really not be changing).
    */
    
    var constraintsAdded: Bool = false
    func setupLayout() {
        if !constraintsAdded {
            
            layoutHelper()

        }
    }
    
    // only available after frame becomes non-zero
    func darkMode() -> Bool {
        let darkMode = { () -> Bool in
                return self.textDocumentProxy.keyboardAppearance == UIKeyboardAppearance.Dark
        }()

        return darkMode
    }
    
    func solidColorMode() -> Bool {
        return UIAccessibilityIsReduceTransparencyEnabled()
    }
    
    var lastLayoutBounds: CGRect?
	override func viewDidLayoutSubviews() {
		if view.bounds == CGRectZero {
			return
		}
		
		self.setupLayout()
        
		let orientationSavvyBounds = CGRectMake(0, 0, self.view.bounds.width, self.heightForOrientation(self.currentInterfaceOrientation, withTopBanner: false))
		
		if (lastLayoutBounds != nil && lastLayoutBounds == orientationSavvyBounds) {
			// do nothing
		}
		else {
            let uppercase = self.shiftState.uppercase()
			let characterUppercase = (NSUserDefaults.standardUserDefaults().boolForKey(kSmallLowercase) ? uppercase : true)
			
			self.forwardingView.frame = orientationSavvyBounds
			self.layout?.layoutKeys(self.currentMode, uppercase: uppercase, characterUppercase: characterUppercase, shiftState: self.shiftState)
			self.lastLayoutBounds = orientationSavvyBounds
			self.setupKeys()
		}
		
		self.bannerView?.frame = CGRectMake(0, 0, self.view.bounds.width, metric("topBanner"))
		
		self.bannerView?.hidden = textDocumentProxy.keyboardType == UIKeyboardType.NumberPad || textDocumentProxy.keyboardType == UIKeyboardType.DecimalPad

		self.forwardingView.frame.origin = CGPointMake(0, self.view.bounds.height - self.forwardingView.bounds.height)
		
	}
	
    override func loadView() {
        super.loadView()
		
        self.bannerView = self.createBanner()
        self.view.insertSubview(self.bannerView!, belowSubview: self.forwardingView)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.bannerView?.hidden = false
        self.keyboardHeight = self.heightForOrientation(self.currentInterfaceOrientation, withTopBanner: true)
    }
	
    var currentInterfaceOrientation : UIInterfaceOrientation
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        self.forwardingView.resetTrackedViews()
        self.shiftStartingState = nil
        self.shiftWasMultitapped = false

        self.layout?.rasterizeKeys(true)

        self.keyboardHeight = self.heightForOrientation(toInterfaceOrientation, withTopBanner: true)
        self.currentInterfaceOrientation = toInterfaceOrientation
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        self.layout?.rasterizeKeys(false)
    }
	

    // If the char we got was one of the selections from pressing the keyboard select button then don't insert it into the text document.
    // Instead take the appropriate action.
    // For now, huge hack to decide that that's what we should do.
    // Returns true if action was taken, else false indicating the caller can treat the text as typed and take action like inserting into the buffer.
    //
    // TODO: The globe button stays highlighted even though we're done.
    func HandleKeyboardSelection(selection : String) -> Bool
    {
        if selection == SpecialUnicodeSymbols.NextKeyboardSymbol {

            self.advanceTapped()
            return true

        } else if selection == SpecialUnicodeSymbols.GearSymbol {

            self.toggleSettings()
            return true

        } else if selection.characters.count == 2 {
            // switch language AND keyboard layout
            ChangeKeyboardLanguage(selection)
            return true
        }

        return false
    }

    func ChangeKeyboardLanguage(languageCode: String)
    {
        NSUserDefaults.standardUserDefaults().setValue(languageCode, forKey: kActiveLanguageCode)

        self.RebootKeyboard()
    }

    private func RebootKeyboard()
    {
        WordStore.CurrentWordStore().ResetContext()

        self.forwardingView.resetTrackedViews()
        self.shiftStartingState = nil
        self.shiftWasMultitapped = false

        self.layout?.rasterizeKeys(true)
        self.forwardingView.removeSubviews()

        self.keyboardHeight = self.heightForOrientation(self.currentInterfaceOrientation, withTopBanner: true)

        self.constraintsAdded = false
        self.setupLayout()
    }

    private func tearDownSubViews() {
        self.forwardingView?.removeFromSuperview()
        self.forwardingView = nil
        
        self.bannerView?.removeFromSuperview()
        self.bannerView = nil

        self.kludge?.removeFromSuperview()
        self.kludge = nil

        self.button.removeFromSuperview()
        self.viewLongPopUp.removeFromSuperview()

        self.constraintsAdded = false
    }

	func hideExpandView(notification: NSNotification)
	{
		
        if notification.userInfo != nil {

            if let title = notification.userInfo!["text"] as? String {

                if !HandleKeyboardSelection(title) {

                    InsertText(CasedString(title, shiftState: self.shiftState))
                }

                self.setCapsIfNeeded()
            }
		}
		
        if !self.forwardingView.isLongPressEnable {

            self.view.bringSubviewToFront(self.bannerView!)
		}

		viewLongPopUp.hidden = true

	}

    // TODO? Add special casing for default height and width for iPad? Previous code resulted in landscape view on iPad2 that was bigger than entire screen
	func heightForOrientation(orientation: UIInterfaceOrientation, withTopBanner: Bool) -> CGFloat {
        
		let actualScreenWidth = (UIScreen.mainScreen().nativeBounds.size.width /
			UIScreen.mainScreen().nativeScale)
		
		let canonicalPortraitHeight = CGFloat(orientation.isPortrait && actualScreenWidth >= 400 ? 226 : 216)
		let canonicalLandscapeHeight = CGFloat(162)
		
		let topBannerHeight = (withTopBanner && textDocumentProxy.keyboardType != UIKeyboardType.NumberPad && textDocumentProxy.keyboardType != UIKeyboardType.DecimalPad)
            ? metric("topBanner") : 0

        return CGFloat(orientation.isPortrait ? canonicalPortraitHeight + topBannerHeight : canonicalLandscapeHeight + topBannerHeight)

	}

    func setupKeys() {
        if self.layout == nil {
            return
        }
		
        for page in keyboard.pages {
            for rowKeys in page.rows { // TODO: quick hack
                for key in rowKeys {
                    if let keyView = self.layout?.viewForKey(key) {
                        keyView.removeTarget(nil, action: nil, forControlEvents: UIControlEvents.AllEvents)
						
                        switch key.type {

                        case Key.KeyType.KeyboardChange:
                            keyView.addTarget(self, action: #selector(KeyboardViewController.keyCharLongPressed(_:)), forControlEvents: .TouchDownRepeat)

                        case Key.KeyType.Backspace:
                            let cancelEvents: UIControlEvents = [UIControlEvents.TouchUpInside, UIControlEvents.TouchUpInside, UIControlEvents.TouchDragExit, UIControlEvents.TouchUpOutside, UIControlEvents.TouchCancel, UIControlEvents.TouchDragOutside]
                            
                            keyView.addTarget(self, action: #selector(KeyboardViewController.backspaceDown(_:)), forControlEvents: .TouchDown)
                            keyView.addTarget(self, action: #selector(KeyboardViewController.backspaceUp(_:)), forControlEvents: cancelEvents)

                        case Key.KeyType.Shift:
                            keyView.addTarget(self, action: #selector(KeyboardViewController.shiftDown(_:)), forControlEvents: .TouchDown)
                            keyView.addTarget(self, action: #selector(KeyboardViewController.shiftUp(_:)), forControlEvents: .TouchUpInside)
                            keyView.addTarget(self, action: #selector(KeyboardViewController.shiftDoubleTapped(_:)), forControlEvents: .TouchDownRepeat)

                        case Key.KeyType.ModeChange:
                            keyView.addTarget(self, action: #selector(KeyboardViewController.modeChangeTapped(_:)), forControlEvents: .TouchDown)

                        default:
                            break
                        }
                        
                        if key.isCharacter {
                            if UIDevice.currentDevice().userInterfaceIdiom != UIUserInterfaceIdiom.Pad {
                                keyView.addTarget(self, action: #selector(KeyboardViewController.showPopup(_:)), forControlEvents: [.TouchDown, .TouchDragInside, .TouchDragEnter])



                                keyView.addTarget(keyView, action: #selector(KeyboardKey.hidePopup), forControlEvents: [.TouchDragExit, .TouchCancel])
                                keyView.addTarget(self, action: #selector(KeyboardViewController.hidePopupDelay(_:)), forControlEvents: [.TouchUpInside, .TouchUpOutside, .TouchDragOutside])
                            }
							
							keyView.addTarget(self, action: #selector(KeyboardViewController.keyCharLongPressed(_:)), forControlEvents: .TouchDownRepeat)
                        }
                        
                        if key.hasOutput {
                            keyView.addTarget(self, action: #selector(KeyboardViewController.keyPressedHelper(_:)), forControlEvents: .TouchUpInside)
                        }
                        
                        if key.type != Key.KeyType.Shift && key.type != Key.KeyType.ModeChange {
                            
                            keyView.addTarget(self, action: #selector(KeyboardViewController.highlightKey(_:)), forControlEvents: [.TouchDown, .TouchDragInside, .TouchDragEnter])
                            keyView.addTarget(self, action: #selector(KeyboardViewController.unHighlightKey(_:)), forControlEvents: [.TouchUpInside, .TouchUpOutside, .TouchDragOutside,  .TouchDragExit, .TouchCancel])
                        }
                        
                        keyView.addTarget(self, action: #selector(KeyboardViewController.playKeySound), forControlEvents: .TouchDown)
                    }
                }
            }
        }
    }
    
    /////////////////
    // POPUP DELAY //
    /////////////////
    
    var keyWithDelayedPopup: KeyboardKey?
    var popupDelayTimer: NSTimer?

    func showPopup(sender: KeyboardKey) {
        if sender == self.keyWithDelayedPopup {
            self.popupDelayTimer?.invalidate()
        }

		let proxy = textDocumentProxy
        if proxy.keyboardType != UIKeyboardType.NumberPad && proxy.keyboardType != UIKeyboardType.DecimalPad {

            // Push the top row of suggestion buttons back so we can draw the popup over the top
            self.view.sendSubviewToBack(self.bannerView!)

            sender.showPopup()
		}
    }
	
    func hidePopupDelay(sender: KeyboardKey) {
        self.popupDelayTimer?.invalidate()
        
        if sender != self.keyWithDelayedPopup {
            self.keyWithDelayedPopup?.hidePopup()
            self.keyWithDelayedPopup = sender
        }
        
        if sender.popup != nil {
            self.popupDelayTimer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: #selector(KeyboardViewController.hidePopupCallback), userInfo: nil, repeats: false)
        }
    }
    
    func hidePopupCallback() {
        self.keyWithDelayedPopup?.hidePopup()
        self.keyWithDelayedPopup = nil
        self.popupDelayTimer = nil

        // Restore the top row of suggestion buttons.
        // We had to push them to the back so the key popup could draw in that space.
        self.view.bringSubviewToFront(self.bannerView!)

    }

    /////////////////////
    // POPUP DELAY END //
    /////////////////////
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
    }

    // TODO: this is currently not working as intended; only called when selection changed -- iOS bug

	override func textDidChange(textInput: UITextInput?) {
		self.contextChanged()
		
		let proxy = textDocumentProxy 
		
		keyboard_type = textDocumentProxy.keyboardType!
		
		dispatch_async(dispatch_get_main_queue(), {
			if proxy.keyboardType! != self.preKeyboardType
			{
                self.RebootKeyboard()
			}
			
		})
	}
	
    func contextChanged() {
        self.setCapsIfNeeded()
        self.autoPeriodState = .NoSpace
        WordStore.CurrentWordStore().ResetContext()
    }
	
    func setHeight(height: CGFloat) {
        if self.heightConstraint == nil {
            self.heightConstraint = NSLayoutConstraint(
                item:self.view,
                attribute:NSLayoutAttribute.Height,
                relatedBy:NSLayoutRelation.Equal,
                toItem:nil,
                attribute:NSLayoutAttribute.NotAnAttribute,
                multiplier:0,
                constant:height)
            self.heightConstraint!.priority = 999
            
            self.view.addConstraint(self.heightConstraint!) // TODO: what if view already has constraint added?
        }
        else {
            self.heightConstraint?.constant = height
        }
    }
    
    func updateAppearances(appearanceIsDark: Bool) {
        self.layout?.solidColorMode = self.solidColorMode()
        self.layout?.darkMode = appearanceIsDark
        self.layout?.updateKeyAppearance()
        
        self.bannerView?.darkMode = appearanceIsDark
    }
    
    func highlightKey(sender: KeyboardKey) {
        sender.highlighted = true
    }
    
    func unHighlightKey(sender: KeyboardKey) {
        sender.highlighted = false
    }
    
    func keyPressedHelper(sender: KeyboardKey) {
        if let model = self.layout?.keyForView(sender) {
            self.keyPressed(model)

            // auto exit from special char subkeyboard
            if model.type == Key.KeyType.Space || model.type == Key.KeyType.Return
                || model.lowercaseOutput == "'"
                || model.type == Key.KeyType.Character {

                    self.currentMode = 0
            }

            // auto period on double space
            self.handleAutoPeriod(model)

            // TODO: reset context
        }
        
        self.setCapsIfNeeded()

    }
	
    func handleAutoPeriod(key: Key) {
        if !NSUserDefaults.standardUserDefaults().boolForKey(kPeriodShortcut) {
            return
        }
		
        if self.autoPeriodState == .FirstSpace {
            if key.type != Key.KeyType.Space {
                self.autoPeriodState = .NoSpace
                return
            }
			
            let charactersAreInCorrectState = { () -> Bool in
                let previousContext = self.textDocumentProxy.documentContextBeforeInput
				
                if previousContext == nil || previousContext!.characters.count < 3 {
                    return false
                }
				
                var index = previousContext!.endIndex
				
                index = index.predecessor()
                if previousContext![index] != " " {
                    return false
                }
                
                index = index.predecessor()
                if previousContext![index] != " " {
                    return false
                }
                
                index = index.predecessor()
                let char = previousContext![index]
                if characterIsWhitespace(char) || characterIsPunctuation(char) || char == "," {
                    return false
                }
                
                return true
            }()
            
            if charactersAreInCorrectState {
                self.textDocumentProxy.deleteBackward()
                self.textDocumentProxy.deleteBackward()
                InsertText(".")
                InsertText(" ")
            }
            
            self.autoPeriodState = .NoSpace
        }
        else {
            if key.type == Key.KeyType.Space {
                self.autoPeriodState = .FirstSpace
            }
        }
    }
    
    func cancelBackspaceTimers() {
        self.backspaceDelayTimer?.invalidate()
        self.backspaceRepeatTimer?.invalidate()
        self.backspaceDelayTimer = nil
        self.backspaceRepeatTimer = nil
    }
    
    func backspaceDown(sender: KeyboardKey) {
        self.cancelBackspaceTimers()
        
        self.textDocumentProxy.deleteBackward()
        WordStore.CurrentWordStore().DeleteBackward()

        self.setCapsIfNeeded()
        
        // trigger for subsequent deletes
        self.backspaceDelayTimer = NSTimer.scheduledTimerWithTimeInterval(backspaceDelay - backspaceRepeat, target: self, selector: #selector(KeyboardViewController.backspaceDelayCallback), userInfo: nil, repeats: false)
    }
    
    func backspaceUp(sender: KeyboardKey) {
        self.cancelBackspaceTimers()
    }
    
    func backspaceDelayCallback() {
        self.backspaceDelayTimer = nil
        self.backspaceRepeatTimer = NSTimer.scheduledTimerWithTimeInterval(backspaceRepeat, target: self, selector: #selector(KeyboardViewController.backspaceRepeatCallback), userInfo: nil, repeats: true)
    }
    
    func backspaceRepeatCallback() {
        self.playKeySound()
        
        self.textDocumentProxy.deleteBackward()
        
        self.setCapsIfNeeded()
    }
    
    func shiftDown(sender: KeyboardKey) {
        self.shiftStartingState = self.shiftState
        
        if let shiftStartingState = self.shiftStartingState {
            if shiftStartingState.uppercase() {
                // handled by shiftUp
                return
            }
            else {
                self.shiftState = (self.shiftState == .Disabled) ? .Enabled : .Disabled
                (sender.shape as? ShiftShape)?.withLock = false
            }
        }
    }
    
    func shiftUp(sender: KeyboardKey) {
        if self.shiftWasMultitapped {
            // do nothing
        }
        else {
            if let shiftStartingState = self.shiftStartingState {
                if !shiftStartingState.uppercase() {
                    // handled by shiftDown
                }
                else {
                    self.shiftState = (self.shiftState == .Disabled) ? .Enabled : .Disabled
                    (sender.shape as? ShiftShape)?.withLock = false
                }
            }
        }

        self.shiftStartingState = nil
        self.shiftWasMultitapped = false
    }
    
    func shiftDoubleTapped(sender: KeyboardKey) {
        self.shiftWasMultitapped = true
        self.shiftState = (self.shiftState == .Locked) ? .Disabled : .Locked
    }
    
    func updateKeyCaps(uppercase: Bool) {
        let characterUppercase = (NSUserDefaults.standardUserDefaults().boolForKey(kSmallLowercase) ? uppercase : true)
        self.layout?.updateKeyCaps(false, uppercase: uppercase, characterUppercase: characterUppercase, shiftState: self.shiftState)
    }
    
    func modeChangeTapped(sender: KeyboardKey) {
        if let toMode = self.layout?.viewToModel[sender]?.toMode {
            self.currentMode = toMode
        }
    }
    
    func setMode(mode: Int) {
        self.forwardingView.resetTrackedViews()
        self.shiftStartingState = nil
        self.shiftWasMultitapped = false
        
        let uppercase = self.shiftState.uppercase()
        let characterUppercase = (NSUserDefaults.standardUserDefaults().boolForKey(kSmallLowercase) ? uppercase : true)
        self.layout?.layoutKeys(mode, uppercase: uppercase, characterUppercase: characterUppercase, shiftState: self.shiftState)
        
        self.setupKeys()
    }
    
    func advanceTapped() {
        WordStore.CurrentWordStore().persistWords()

        self.forwardingView.resetTrackedViews()
        self.shiftStartingState = nil
        self.shiftWasMultitapped = false
        
        self.advanceToNextInputMode()
    }

    // Nice tutorial on navigation controllers and view controllers:
    // http://makeapppie.com/2014/09/15/swift-swift-programmatic-navigation-view-controllers-in-swift/
    var nav: CustomNavigationController? = nil

    @IBAction func toggleSettings() {
        self.nav = CustomNavigationController(parent: self)
        self.presentViewController(nav!, animated: false, completion: nil)

        let vc = LanguageSettingsViewController(languageDefinitions: LanguageDefinitions.Singleton(), navController: nav)
        self.nav?.pushViewController(vc, animated: true)
    }
    
    func setCapsIfNeeded() -> Bool {
        if self.shouldAutoCapitalize() {
            self.shiftState = (self.shiftState == .Locked) ? .Locked : .Enabled
            
            return true
        }
        else {
            self.shiftState = (self.shiftState == .Locked) ? .Locked : .Disabled
            
            return false
        }
    }
    
    func shouldAutoCapitalize() -> Bool {
        if !NSUserDefaults.standardUserDefaults().boolForKey(kAutoCapitalization) {
            return false
        }
        
        let documentProxy = self.textDocumentProxy
        if let autocapitalization = documentProxy.autocapitalizationType {

            switch autocapitalization {
            case .None:
                return false

            case .Words:
                if let beforeContext = documentProxy.documentContextBeforeInput {
                    let previousCharacter = beforeContext[beforeContext.endIndex.predecessor()]
                    return characterIsWhitespace(previousCharacter)
                }

                return true

            case .Sentences:
                if let beforeContext = documentProxy.documentContextBeforeInput {
                    let offset = min(3, beforeContext.characters.count)
                    var index = beforeContext.endIndex
                    
                    for i in 0 ..< offset {
                        index = index.predecessor()
                        let char = beforeContext[index]
                        
                        if characterIsPunctuation(char) {
                            return i > 0 //punctuation with at least one space after it
                        }
                        else {
                            if !characterIsWhitespace(char) {
                                return false //hit a foreign character before getting to 3 spaces
                            }
                            else if characterIsNewline(char) {
                                return true //hit start of line
                            }
                        }
                    }
                }

                return true

            case .AllCharacters:
                return true
            }
        }
        else {
            return false
        }
        
    }
    
    // This only works if full access is enabled.
    // Current over-arching goal is to implement a kbd that does not require full access so we can't play sound.
    // But leave this as a stub in case Apple relaxes what you can do as a kbd later.
    func playKeySound() {
    }
    
    //////////////////////////////////////
    // MOST COMMONLY EXTENDABLE METHODS //
    //////////////////////////////////////
    
    class var layoutClass: KeyboardLayout.Type { get { return KeyboardLayout.self }}
    class var layoutConstants: LayoutConstants.Type { get { return LayoutConstants.self }}

    func InsertText(insertChar: String)
    {
        self.delegate!.didInsertString(insertChar)

        WordStore.CurrentWordStore().recordChar(insertChar)

        self.bannerView?.LabelSuggestionButtons(WordStore.CurrentWordStore().getSuggestions(3))
    }
    
    func keyPressed(key: Key) {
        InsertText(key.outputForCase(self.shiftState.uppercase()))
    }
    
    // a banner that sits in the empty space on top of the keyboard
    func createBanner() -> SuggestionView {
        // note that dark mode is not yet valid here, so we just put false for clarity
        return SuggestionView(darkMode: false, solidColorMode: self.solidColorMode())
    }
    
	// MARK: Added methods for extra features
	func initializePopUp()
	{
        button.initializePopup(self.forwardingView)
		self.view.insertSubview(self.button, aboveSubview: self.forwardingView)

        viewLongPopUp.hidden = true
	}

	func didTTouchExitDownSuggestionButton(sender: AnyObject?)
	{
        if let button = sender as? UIButton {
            button.backgroundColor = UIColor(red:0.68, green:0.71, blue:0.74, alpha:1)
            button.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        }
	}
	
	func didTTouchDownSuggestionButton(sender: AnyObject?)
	{
        if let button = sender as? UIButton {

            if let btn_title = button.titleForState(UIControlState.Normal) where !stringIsWhitespace(btn_title)  {
                self.bannerView?.showPressedAppearance(button)
            }
        }
    }
	
	func didTapSuggestionButton(sender: AnyObject?)
	{
        
		self.currentMode = 0
		
		self.autoPeriodState = .FirstSpace

        onSuggestionTap(sender)

        self.bannerView?.updateAppearance()
		
		self.setCapsIfNeeded()
		
	}
	
    func onSuggestionTap(sender: AnyObject?)
    {
        if let button = sender as? UIButton {

            let title = TrimWhiteSpace(button.titleForState(.Normal))

            if title == ""
            {
                return
            }

            // Tapping on the suggestion replaces the word we've been inserting into the text buffer
            for _ in 0 ..< WordStore.CurrentWordStore().CurrentWord.characters.count {
                self.textDocumentProxy.deleteBackward()
            }

            let insertionWord =
                self.shiftState == .Enabled ? title.capitalizedString
                    : self.shiftState == .Locked ? title.uppercaseString
                    : title

            InsertText(insertionWord + " ")

            // Update the last used datetime for this word
            // REVIEW insert the case-corrected insertionWord? Or just the value shown on the suggestion key?
            WordStore.CurrentWordStore().recordWord(title)
        }
    }

    func getLongPresses(sender: KeyboardKey) -> [String]?
    {
        return self.layout?.viewToModel[sender]?.getLongPressesForShiftState(self.shiftState)
    }

    func longPressEnabledKey(sender : KeyboardKey?) -> Bool
    {
        if sender == nil {
            return false
        }

        let longPresses = self.getLongPresses(sender!)
        return longPresses != nil && longPresses!.count > 0 && longPresses![0] != ""
    }

    func keyCharLongPressed(sender: KeyboardKey)
    {
        if sender.tag == LongPressActivated
        {
            sender.hidePopup()

            if let arrOptions = self.getLongPresses(sender) where arrOptions.count > 0 && arrOptions[0] != "" {

                var offsetY : CGFloat = 9

                if self.currentInterfaceOrientation == UIInterfaceOrientation.LandscapeLeft || self.currentInterfaceOrientation == UIInterfaceOrientation.LandscapeRight {
                    offsetY = 3
                }
                else {
                    switch  KeyboardViewController.getDeviceType() {
                    case TTDeviceType.TTDeviceTypeIPhone4, TTDeviceType.TTDeviceTypeIPhone5:
                        offsetY = 9

                    case TTDeviceType.TTDeviceTypeIPhone6:
                        offsetY = 13

                    case TTDeviceType.TTDeviceTypeIPhone6p:
                        offsetY = 16
                    }
                }

                self.button.removeFromSuperview()

                self.button.frame = CGRectMake(sender.frame.origin.x, sender.frame.origin.y + sender.frame.size.height - offsetY, sender.frame.size.width, sender.frame.size.height)

                self.view.insertSubview(self.button, aboveSubview: self.forwardingView)

                let isTopRow:Bool = self.layout?.keyForView(sender)?.isTopRow ?? false
                self.viewLongPopUp = self.button.showLongPopUpOptions(isTopRow)
                self.button.input = sender.text
                self.button.hidden = true
                self.button.inputOptions = arrOptions
                self.viewLongPopUp.hidden = false

                for anyView in self.view.subviews
                {
                    if anyView is CYRKeyboardButtonView
                    {
                        anyView.removeFromSuperview()
                    }
                }

                self.viewLongPopUp.userInteractionEnabled = false;

                button.setupInputOptionsConfigurationWithView(forwardingView)
                self.view.insertSubview(self.viewLongPopUp, aboveSubview: self.forwardingView)
                self.forwardingView.isLongPressEnable = true
                self.view.bringSubviewToFront(self.viewLongPopUp)
                
                sender.tag = 0
                
            }
        }
    }
	
	class func getDeviceType()->TTDeviceType
	{
        var height = UIScreen.mainScreen().bounds.size.height
		
		if UIScreen.mainScreen().bounds.size.height < UIScreen.mainScreen().bounds.size.width
		{
			height = UIScreen.mainScreen().bounds.size.width
		}

        var deviceType = TTDeviceType.TTDeviceTypeIPhone5

		switch (height) {
		case 480:
			deviceType = TTDeviceType.TTDeviceTypeIPhone4
			break
			
		case 568:
			deviceType = TTDeviceType.TTDeviceTypeIPhone5
			break
            
		case 667:
			deviceType = TTDeviceType.TTDeviceTypeIPhone6
			break
            
		case 736:
			deviceType = TTDeviceType.TTDeviceTypeIPhone6p
			break
			
		default:
			break
		}
		
		return deviceType
		
	}
    
}
