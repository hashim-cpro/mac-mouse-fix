//
// --------------------------------------------------------------------------
// TrialState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@objc class GetTrialState : NSObject {
    
    /// -> This class retrieves instances of the `MFTrialState` dataclass

    @objc static func get(_ licenseConfig: MFLicenseConfig) -> MFTrialState {
        assertRunLoop(licensingRunLoop())

        let trialDays = 30
        let daysOfUse = 0
        let daysOfUseUI = 1
        let trialIsActive = true
        
        let result = MFTrialState(
            daysOfUse: daysOfUse,
            daysOfUseUI: daysOfUseUI,
            trialDays: trialDays,
            trialIsActive: trialIsActive
        )
        
        return result
    }

}
