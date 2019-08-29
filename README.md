# MobileTSS
An iOS app to check signing status of firmwares from Apple server and save blobs to local. This application is basically a GUI wrapper for command-line tools tsschecker and img4tool.

## Features
* Check signing status for every firmware including betas and OTAs
* Save blobs for every signed firmware
* Check signing status in background
* Show extracted info in SHSH2 file (not available for 32-bit shsh)
* Verify shsh files (both 32-bit and 64-bit are supported)
* Allow to specify custom apnonce and generator (required for A12 devices)
* No Jailbreak required

## Requirements
Minimum: iOS 8.0. Few features require higher iOS version.<br/>
Both 32-bit and 64-bit devices are supported.<br/>

## Tutorial
This project is written in Swift 4.0 so you need to have Xcode 9 or above installed on Mac to compile it. After finish downloading the project zip, open project file and start to compile and should run on simulator. 

## Support
Any contributions are welcome. This project is under MIT license.  

## Credits
* @tihmstar for [tsschecker](https://github.com/tihmstar/tsschecker) and [img4tool](https://github.com/tihmstar/img4tool)
* @xerub and @planetbeing for [xpwn](https://github.com/xerub/xpwn)
