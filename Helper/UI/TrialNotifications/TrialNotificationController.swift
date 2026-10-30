//
// --------------------------------------------------------------------------
// TrialNotificationController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Also see ToastNotifications in the mainApp. They work similarly.

import Cocoa

class TrialNotificationController: NSWindowController {

    
    /// Singleton
    @objc static let shared = TrialNotificationController(window: nil)
    
    /// Outlets & actions
    
    @IBOutlet private var body: NSTextView!
    @IBOutlet private weak var bodyScrollView: NSScrollView!

    @IBOutlet private weak var applePayBadge: NSImageView!
    @IBOutlet private weak var payButton: PayButton!

    @IBOutlet private weak var trialSection: TrialSection!

    @IBAction private func closeButtonClick(_ sender: Any) {

        /// Close notification
        self.close()
        
        /// Wait for close animation to finish
        assertRunLoop(CFRunLoopGetMain())
        Timer.mf_scheduledTimer(withTimeInterval: 0.5, mode: .common) { timer in
            /// Disable helper
            HelperServices.disableHelperFromHelper()
        }
    }
    
    /// Vars
    private var trackingArea: NSTrackingArea? = nil
    private var darkModeObservation: NSKeyValueObservation? = nil
    private var trialSectionManager: TrialSectionManager! = nil
    private var spaceSwitchObservation: Any? = nil

    /// Init
    private override init(window: NSWindow?) {

        if window == nil {
            super.init(window: nil)
            let nib = NSNib(nibNamed: "TrialNotificationController", bundle: nil)
            
            var topLevelObjects: NSArray?
            nib?.instantiate(withOwner: self, topLevelObjects: &topLevelObjects)
            self.window = topLevelObjects![0] as? NSWindow
            if self.window == nil {
                self.window = topLevelObjects![1] as! NSWindow
            }
            
            self.window?.collectionBehavior = .canJoinAllSpaces
            
        } else {
            super.init(window: window)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Lifecycle
    /*private*/ override func windowDidLoad() {
        super.windowDidLoad()

        /// Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        /// Make views compact on Tahoe
        if #available(macOS 26.0, *) {
            self.window?.contentView?.prefersCompactControlSizeMetrics = true;
        }
    }
    
    /*private*/ deinit {
        if let obs = self.spaceSwitchObservation {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }
    
    /// Interface
    
    private var firstAppearance = true

    @objc func open(licenseConfig: MFLicenseConfig, licenseState: MFLicenseState, trialState: MFTrialState, triggeredByUser: Bool) {
        assertRunLoop(CFRunLoopGetMain())
        // Trial notifications disabled - app is permanently licensed
        return
    }
    
    /*private*/ override func close() {
        assertRunLoop(CFRunLoopGetMain())

        /// Unwrap window and screen
        guard
            let window = self.window,
            let screen = NSScreen.main
        else { return }
        
        /// Get start and end frames
        let start = window.frame
        let end = NSRect(x: screen.visibleFrame.maxX, y: start.origin.y, width: start.width, height: start.height)
        
        /// Animate
        setFrameWithCoolAnimation(start, end, window, onComplete: {
            mfrun(CFRunLoopGetMain()) {
                super.close()
            }
        })
    }
    
    /// Swap trialSection -> activate license on hover

    /*private*/ override func mouseEntered(with event: NSEvent) {

        mfrun(CFRunLoopGetMain()) {
            self.trialSectionManager.showAlternate(animate: true, hAnchor: .leading)
        }
    }

    /*private*/ override func mouseExited(with event: NSEvent) {

        mfrun(CFRunLoopGetMain()) {
            self.trialSectionManager.showInitial(animate: true, hAnchor: .leading)
        }
    }
    
    /// Helper stuff
    private var animator: DynamicSystemAnimator? = nil
    private func setFrameWithCoolAnimation(_ animStartFrame: NSRect, _ newFrame: NSRect, _ window: NSWindow, onComplete: (() -> ())? = nil) {

        /// Animate window in
        ///     Note: We're doing the same thing in ResizingTabWindow. -> Think about abstracting this away
        
        let animation = CASpringAnimation(speed: 3.5, damping: 1.0)
        animator = DynamicSystemAnimator(fromAnimation: animation, stopTolerance: 0.1, phaseShift: kVBLPhase_DefaultForAppKitUpdates, runLoop: CFRunLoopGetMain(), name: "TrialNotification")
        animator!.start(distance: 1.0, callback: { value in
            var f = SharedUtilitySwift.interpolateRects(value, animStartFrame, newFrame)
            f = NSIntegralRectWithOptions(f, .alignAllEdgesNearest)
            window.setValue(f, forKey: "frame")
        }, onComplete: {
            onComplete?()
        })
    }
}
