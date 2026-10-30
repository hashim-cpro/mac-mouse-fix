//
// --------------------------------------------------------------------------
// MFLicenseState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import CryptoKit

/// Log prefix for this file
fileprivate func _DDLogInfo (_ m: @autoclosure () -> String) { DDLogInfo ("GetLicenseState: \(m())") }
fileprivate func _DDLogDebug(_ m: @autoclosure () -> String) { DDLogDebug("GetLicenseState: \(m())") }
fileprivate func _DDLogError(_ m: @autoclosure () -> String) { DDLogError("GetLicenseState: \(m())") }

@objc class GetLicenseState : NSObject {

    /// -> This class retrieves instances of the `MFLicenseState` dataclass

    #if IS_MAIN_APP
    static func get_Preliminary(_callingFunc: String = #function) -> MFLicenseState {

        assertRunLoop(licensingRunLoop())

        let result = MFLicenseState(isLicensed: true,
                                    freshness: kMFValueFreshnessFresh,
                                    licenseTypeInfo: MFLicenseTypeInfoGumroadV1())
        
        _DDLogInfo("get_Preliminary(): \(result)\ncaller: \(_callingFunc)")

        return result
    }
    #endif

    @LicensingActor public static func get(_callingFunc: String = #function) async -> MFLicenseState {

        assertRunLoop(licensingRunLoop())

        let result = MFLicenseState(isLicensed: true,
                                    freshness: kMFValueFreshnessFresh,
                                    licenseTypeInfo: MFLicenseTypeInfoGumroadV1())

        _DDLogInfo("\(result) - caller: \(_callingFunc)")

        return result
    }

    /// Server/cache/fallback/overrides interfaces
    
    @LicensingActor public static func licenseStateFromOverrides() async -> MFLicenseState? {

        assertRunLoop(licensingRunLoop())

        return MFLicenseState(isLicensed: true,
                              freshness: kMFValueFreshnessFresh,
                              licenseTypeInfo: MFLicenseTypeInfoGumroadV1())
    }
    
    private static let licenseStateFromFallback: MFLicenseState = MFLicenseState(isLicensed: false,
                                                                                 freshness: kMFValueFreshnessFallback,
                                                                                 licenseTypeInfo: MFLicenseTypeInfoNotLicensed())

    /// Hashing functions for validating the offline license (aka `licenseStateCache`) [Oct 2026]
    ///     Also see:
    ///         - 'Free days are over' bug notes
    ///         - Where these hashing functions are used (to validate the offline license)
    ///     Explanation of offline validation (and how we use the hashes): (Writing this [Oct 2026] - might be duplicate with something older)
    ///         We cache the latest `MFLicenseState` in the config.plist > `License.licenseStateCache` and then use that instead of pinging Gumroad on every launch.
    ///         To prevent piracy from beingt too easy, we hash the licenseState against some environment variables: (In the abstract sense, not to be confused with Unix envvars)
    ///             1. The user's `licenseKey`
    ///             2. The `deviceUID` of the current computer
    ///         If the environment changes or the `MFLicenseState` is tampered with, the hash will change and we don't use the cached `MFLicenseState`. That's what 'offline license validation' is currently [Oct 2026]
    ///     Why use separate hashing functions for each environment variable? [Oct 2026]
    ///         We think that the getters for the environment variables could sporadically fail causing random lockdowns of the app (See 'Free days are over' bug notes) [Oct 2026] - so we only validate against the environment variables that are currently available
    ///             That means err on the side of treating the MFLicenseState as valid, without giving up all validation just because one of the environment variables is not available,
    ///                 preventing robust, shareable "30 second crack" (See in 'Free days are over' bug notes [Oct 2026]) without ever locking paying users out (hopefully)

    private static func hashLicenseState(_ licenseState: Data, againstLicenseKey licenseKey: String) -> Data {
        var hashFunction = SHA256.init() /// SHA256 is totally overkill we just need someee simple hash to prevent tampering and ensure data integrity. It doesn't need to be cryptographically secure at all.
        hashFunction.update(data: licenseState)
        hashFunction.update(data: licenseKey.data(using: .utf8) ?? Data())
        return Data(hashFunction.finalize())
    }
    private static func hashLicenseState(_ licenseState: Data, againstDeviceUID_V2 deviceUID: String) -> Data {
        var hashFunction = SHA256.init()
        hashFunction.update(data: licenseState)
        hashFunction.update(data: deviceUID.data(using: .utf8) ?? Data())
        return Data(hashFunction.finalize())
    }
    private static func legacy_hashLicenseState(_ licenseState: Data, againstLicenseKey licenseKey: String, andDeviceUID_V1 deviceUID: Data?) -> Data {
        /// Formerly `getHashForOfflineCacheValidation`
        /// Old hash which combines licenseKey and deviceUID. See "Why use separate hashing functions for each environment variable" above [Oct 2026]

        var hashFunction = SHA256.init()
        hashFunction.update(data: licenseState)
        hashFunction.update(data: licenseKey.data(using: .utf8) ?? Data())
        hashFunction.update(data: deviceUID ?? Data())
        return Data(hashFunction.finalize())
    }

    private static func deleteLicenseStateFromCache(commitConfig doCommitConfig: Bool) {
        
        /// We create an abstraction for this so we can easily regex for it
        ///
        /// Discussion: When to update the cache?  `[Jan 2025]`
        ///     Currently [Jan 2024] The licenseStateCache is intended as an offline substitute for the data that the server would send us about a license.
        ///         > We need it when 1. the licenseServer isn't accessible, 2. We we wanna do offline validation in order to minimize internet connections and enhance privacy.
        ///     Therefore we wanna update the cache:
        ///         1. When the server responds with a clear YES/NO to the question "is this license valid?"
        ///         2. When "is this license valid?" is determined during *preprocessing* of the data that we *wouid* send to the server. (E.g. if there is no licenseKey, we immediately know that the license isn't valid, and we don't ping the server.)
        ///         3. When offline validation fails - and therefore we know the cache has become invalid.
        ///         -> I think these are the only places where we get __ground truth__ data about the licenseState, and therefore, updating here should be enough to maintain the cache's integrity.
        ///
        ///     What is the practical problem if we don't delete the cache?
        ///         1. If `get()` fails, and we don't update the cache, then subsequent `get_Preliminary()` calls will keep returning that the app isLicensed. This results in the UI loading in a 'licensed' state and then immediately flashing to the 'unlicensed' state. That's janky.
        ///         2. Deleting cache after offline validation fails should make subsequent cache accesses a bit faster.
        ///         - Discussion: Alternatively we could also just validate *all* cache accesses (even the `get_Preliminary()` ones) to achieve consistent behavior.
        ///             - At least that would work as a replacement of the deleteLicenseStateFromCache() call upon offline validation failure
        ///             - Validating all cache accesses might also be better because then we don't gotta modify the config all over the place, which might produce race conditions?
        ///
        ///     - Architecture considerations: [Jan 2024]
        ///         We used to simply update the cache at the end of `get()` instead of 3 different places.
        ///         Should we go back to get()f?
        ///             Contra: New approach is more 'efficient' since we granularily decide what to cache, and therefore don't cache values that were just retrieved from the cache/fallback.
        ///                 Update: But couldn't we just check the licenseFreshness to get the same 'efficiency'/behavior? I guess if we considered a failed offline validation or missing LicenseKey as a 'fresh' value, then we could simply update the cache in case the licenseState `isFresh`. However, currently, the 'freshness' describes the origin of the data (server, cache, fallback). So we'd have to decouple these concepts somehow, I think? Or just override caches unless we just got a cached value – that might also work?
        ///             Contra: Granularity and explicitness helps us think about the different codepaths.
        ///             Pro: Does that 'effiency' matter? – Probably notj.
        ///             Pro: Much simpler code logic – All cache updates happen in get(). Cache just reflects latest value returned from get().
        ///             Pro: No risk to forget some place where we should update the cache to ensure integrity.
        ///             Steelmanning also caching override-MFLicenseStates:
        ///                 Caching override-MFLicenseStates like freeCountry might be sort of useful for extra robustness. E.g. if the app is licensed under a freeCountry license where that free country isn't included in the hardcoded fallback, and then the internet and the licenseConfig cache goes away, then the user can't use the app anymore. Whereas when we cache the override-MFLicenseStates, then that would serve as an extra failsafe making the app usable even if those other two things go away (I think at least - not entirely sure. Haven't thought this through.)
    
        removeFromConfig("License.licenseStateCache")
        removeFromConfig("License.licenseStateCacheHash_AgainstLicenseKey")
        removeFromConfig("License.licenseStateCacheHash_AgainstDeviceUID")

        removeFromConfig("License.licenseStateCacheHash") /// Legacy key, also removed by the migration code [Oct 2026]

        if doCommitConfig { commitConfig() }
    }
    
    private static func storeLicenseStateInCache(_ newValue: MFLicenseState, licenseKey: String, deviceUID_V2: String?) {

            /// Which fields of MFLicenseState to cache?
            ///     We're caching all the fields of the `MFLicenseState`. It's an offline substitute for the data we would receive from a license server.
            ///         It's unnecessary to cache the `MFLicenseState.freshness` value since that indicates the orgin of the data - server, cache, or fallback - and isn't really "part of the data" itself.
            ///         However, removing the value before caching requires extra lines of code, and doesn't have practical benefit, so we don't bother.
            
            #if false  /// Old approach – Archive into an xml string using MFEncode
                /// Archive the object
                ///     The archive is an xml string, (instead of the default: binary data) for bit better debuggability and perhaps being less ominous/intransparent for the users.
                let xmlData = MFEncode(newValue, requireSecureCoding: true, plistFormat: .xml) as Data?
                guard let xmlData = xmlData,
                      let xmlString = NSString(data: xmlData, encoding: NSUTF8StringEncoding)
                else {
                    _DDLogError("MFLicenseState xmlString for caching came out as nil. Don't think this should ever happen.")
                    assert(false)
                    return
                }
            #endif
            
            /// Validate
            if !newValue.isLicensed { assert(false, "Use deleteLicenseStateFromCache() to set the cache to !isLicensed – So we can understand the control flow better.") }
            
            /// Convert MFDataClass object to plist dict
            let dict = newValue.asPlist(withRequireSecureCoding: true)
            
            /// Calculate hashes
            ///     Note: [Jan 2025] Need to use `.xml` instead of `.binary`. to make the data (and with it the hash) deterministic. Not sure why. We might be relying on an implementation detail here.
            let (dictData, error) = MFCatch { try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) }
            guard let dictData else {
                _DDLogError("Caching: plist serialization of licenseState dict archive failed with error: \(error.map { String(describing: $0) } ?? "<nil>"). (Don't think this should ever happen.)")
                assert(false);
                return
            }
            let hash_licenseKey = self.hashLicenseState(dictData, againstLicenseKey: licenseKey)
            let hash_deviceUID  = deviceUID_V2 == nil ? nil : self.hashLicenseState(dictData, againstDeviceUID_V2: deviceUID_V2!)

            /// Store data
            setConfig("License.licenseStateCache",                         dict as NSDictionary)
            setConfig("License.licenseStateCacheHash_AgainstLicenseKey",   hash_licenseKey as NSData)
            setConfig("License.licenseStateCacheHash_AgainstDeviceUID",    hash_deviceUID as NSData?)
            commitConfig()
    }
    
    private static func licenseStateFromCache(licenseKey: String?, enableOfflineValidation: Bool) -> MFLicenseState? {
            assertRunLoop(licensingRunLoop())

            /// Note: If the argument `enableOfflineValidation` is set to `false`, then all the other arguments are ignored - they only exist for the offlineValidation
            
            /// Get cached MFLicenseState archive
            guard let cachedLicenseState = config("License.licenseStateCache") as? NSDictionary
            else {
                _DDLogError("MFLicenseState dict could not be extracted from cache") /// DDLogError - this is normal for unlicensed users so a little bad to persist, but what if it's involved in 'Free days are over' bugs. Not sure how to decide about these things. [Oct 2026]
                return nil
            }

            /// Validate the cached MFLicenseState against the environment, using the hashes stored next to it
            var isValid: Bool = true
            validation: if enableOfflineValidation {

                let deviceUID_V2 = getDeviceUID_V2();

                if licenseKey == nil && deviceUID_V2 == nil
                    { isValid = true; _DDLogError("Not enough info from environment to validate offline license. Treating this as a spurious failure and treating cached licenseState as valid"); break validation; }

                /// Serialize the `cachedLicenseState` so we can pass it to our hashing functions [Oct 2026]
                let (cachedLicenseState_Data_, error) = MFCatch { try PropertyListSerialization.data(fromPropertyList: cachedLicenseState, format: .xml, options: 0) as Data }
                guard let cachedLicenseState_Data = cachedLicenseState_Data_ else
                    { isValid = false; _DDLogError("Offline validation failed: plist serialization of dict archive failed. Error: \(error.map { String(describing: $0) } ?? "<nil>")"); break validation }

                step1: do {

                    isValid = true

                    /// Validate `cachedLicenseState` against `licenseKey` [Oct 2026]
                    if let licenseKey {
                        if  config("License.licenseStateCacheHash_AgainstLicenseKey") as? Data !=
                            self.hashLicenseState(cachedLicenseState_Data, againstLicenseKey: licenseKey)
                        { isValid = false; _DDLogError("Offline validation failed: licenseKey doesn't match the hash"); break step1;  }
                    }

                    /// Validate `cachedLicenseState` against `deviceUID_V2` [Oct 2026]
                    if let deviceUID_V2 {
                        if  config("License.licenseStateCacheHash_AgainstDeviceUID") as? Data !=
                            self.hashLicenseState(cachedLicenseState_Data, againstDeviceUID_V2: deviceUID_V2)
                        { isValid = false; _DDLogError("Offline validation failed: deviceUID doesn't match the hash"); break step1; }
                    }
                }

                /// Fallback -> Validate `cachedLicenseState` against both `licenseKey` and `deviceUID` (Support for legacy `License.licenseStateCacheHash` configKey [Oct 2026]) (See `License.licenseStateCacheHash` in 'Free days are over' bug notes)
                if !isValid, let licenseKey {

                    let deviceUID_V1 = getDeviceUID_V1()

                    if  config("License.licenseStateCacheHash") as? Data !=
                        self.legacy_hashLicenseState(cachedLicenseState_Data, againstLicenseKey: licenseKey, andDeviceUID_V1: deviceUID_V1)
                    { isValid = false; _DDLogError("Offline validation failed: Tried fallback but the legacy hash didn't match either."); }

                    else {
                        isValid = true
                        /// Rewrite the `licenseStateCacheHash` in the new format [Oct 2026]
                        ///     Usually we do these kinds of migrations in `Config.m > _loadAndRepair` [Oct 2026]. I think migrating like this is ok for transient data. (App just has to connect to internet once to recover, if this fails)
                        removeFromConfig("License.licenseStateCacheHash")
                        setConfig("License.licenseStateCacheHash_AgainstLicenseKey", self.hashLicenseState(cachedLicenseState_Data, againstLicenseKey: licenseKey) as NSObject)
                        if let deviceUID_V2 { setConfig("License.licenseStateCacheHash_AgainstDeviceUID",  self.hashLicenseState(cachedLicenseState_Data, againstDeviceUID_V2: deviceUID_V2) as NSObject) }
                        commitConfig()
                    }
                }
            }

            /// Handle offline validation failure
            if isValid {
                /// Log success!
                _DDLogInfo("Offline validation succeeded.\nlicenseKey: \(licenseKey.map { String(describing: $0) } ?? "<nil>"), enableOfflineValidation: \(enableOfflineValidation), cachedLicenseState: \(cachedLicenseState)")
            }
            else {
                /// Delete cache
                ///     (Because we know it's invalid)
                deleteLicenseStateFromCache(commitConfig: true) /// `<-` Also see the discussion in here

                /// Return
                return nil
            }
            
            /// Unarchive
            ///     Note: (Nov 2024) Note that requireSecureCoding is turned on here.
            ///         -> This is somewhat slower and pretty unnecessary here I think since hackers would have to tamper with the (locally stored) cache to perform an 'object substitution' or 'nil insertion' attack. (Which are what secureCoding on MFDataClass protects against) And if they can modify local files, they already have full control over the system.)
            ///         -> I guess another possible benefit of the nil/type checks is if we change MFLicenseState in the future and we forget to handle that explicitly, then we would just return nil here in some cases instead of returning an invalid object that might crash the app because of unexpected type/nullability
            ///             ... But we should just introduce versioning to handle this properly. More on this in MFCoding.m > "On validation of decoded values"
            guard
                let cachedDict = cachedLicenseState as? [String: NSObject], /// ([Feb 2025] We're first casting to NSDictionary and then to [String: NSObject], which is then Swift auto-bridged back to NSDictionary. Does that make sense?)
                let licenseState = MFLicenseState(plist: cachedDict, requireSecureCoding: true)
            else {
                _DDLogError("Initializing MFLicenseState using cached dict failed.")
                return nil
            }
            
            /// Override freshness
            let result = MFLicenseState(isLicensed: licenseState.isLicensed,
                                        freshness: kMFValueFreshnessCached,     /// Note that we use all values from cache except for freshness
                                        licenseTypeInfo: licenseState.licenseTypeInfo)

            /// Return
            return result
    }

    @LicensingActor public static func licenseStateFromServer(key: String, incrementActivationCount: Bool, licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState?, error: NSError?) {
        assertRunLoop(licensingRunLoop())
        let result = MFLicenseState(isLicensed: true,
                                    freshness: kMFValueFreshnessFresh,
                                    licenseTypeInfo: MFLicenseTypeInfoGumroadV1())
        return (result, nil)
    }
}
