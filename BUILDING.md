# Building Mac Mouse Fix (Paywall-Free)

This fork has the paywall, trial countdowns, trial notification popups, and lockdown mechanisms completely removed. The app treats all installations as fully licensed forever.

---

## Why Can't It Be Built on Windows?

Mac Mouse Fix is written in **Swift** and **Objective-C / Objective-C++** targeting the Apple **macOS** platform. It relies on:
1. **Apple Proprietary Frameworks**: AppKit, Cocoa, ApplicationServices, IOKit, CoreGraphics, CoreVideo, QuartzCore, ServiceManagement. These frameworks are closed-source and distributed solely with Apple's macOS SDK inside Xcode.
2. **Interface Builder & Asset Tools**: The storyboards (`Main.storyboard`), XIBs (`LicenseSheetController.xib`), and Asset Catalogs (`Assets.xcassets`) require `ibtool` and `actool`, which are Mach-O binaries running only on macOS Darwin.
3. **Target Architecture & Toolchain**: Cross-compiling modern Swift Concurrency and Cocoa AppKit apps from Windows to macOS is not supported by Apple or Swift.org.

Therefore, **building native macOS AppKit apps requires macOS with Xcode (or a macOS CI runner)**.

---

## How to Build the App

We have provided two convenient ways to get your `.app`:

### Option 1: Automated GitHub Actions Build (Recommended - No Mac Required to Build!)

Because this repository is a GitHub fork, you can build the app directly in the cloud using GitHub Actions:

1. Push this branch (`remove_mac_mouse_fix_paywall`) to your GitHub fork:
   ```bash
   git push origin remove_mac_mouse_fix_paywall
   ```
2. In your GitHub repository in your browser:
   - Navigate to the **Actions** tab.
   - Select the **Build Mac Mouse Fix** workflow.
   - Click **Run workflow** (or it will automatically run on push).
3. Once the workflow finishes (typically 2–3 minutes):
   - Click into the completed run.
   - Under **Artifacts**, download `Mac-Mouse-Fix-Paywall-Free.zip`.
4. Unzip the file on your Mac to get `Mac Mouse Fix.app`.

---

### Option 2: Local Build on macOS

If you have a Mac:

#### Method A: Using the Build Script
Open Terminal in the project root and run:
```bash
chmod +x build.sh
./build.sh
```
This script will:
- Check out any submodules.
- Build both the Helper daemon and Main Application with `xcodebuild`.
- Apply local ad-hoc code signing (`codesign --force --deep -s -`).
- Produce `Mac Mouse Fix.zip` right in the project root.

#### Method B: Using Xcode GUI
1. Clone or copy this repository to your Mac:
   ```bash
   git clone --recursive <your-fork-url> -b remove_mac_mouse_fix_paywall
   ```
2. Open `Mouse Fix.xcodeproj` in Xcode.
3. Select the scheme: **Mac Mouse Fix** or **App - Release**.
4. In Project Settings under **Signing & Capabilities**, the project is preconfigured for **Manual** signing with Ad-hoc (`-`) sign to run locally (no paid Apple Developer Program account required).
5. Press `Cmd + B` (or `Product > Build`) to build, or `Product > Archive`.

---

## Installing and Running on macOS

1. Move `Mac Mouse Fix.app` to your `/Applications` folder.
2. If macOS Gatekeeper shows a warning ("Mac Mouse Fix cannot be opened because it is from an unidentified developer"):
   - Right-click (or Control-click) `Mac Mouse Fix.app` and choose **Open**.
   - Or open Terminal and clear the quarantine flag:
     ```bash
     xattr -cr "/Applications/Mac Mouse Fix.app"
     ```
3. When prompted, grant **Accessibility** permissions in macOS **System Settings > Privacy & Security > Accessibility**.
4. Enjoy full, unrestricted Mac Mouse Fix features!
