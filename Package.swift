//
//  Package.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "Nifty",
    dependencies: [
        .Package(url: "https://github.com/anpol/DispatchKit.git", majorVersion: 2, minor: 1),
    ]
)