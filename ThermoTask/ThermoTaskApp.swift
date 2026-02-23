//
//  ThermoTaskApp.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import CoreText
import SwiftUI

@main
struct ThermoTaskApp: App {
    init() {
        if let url = Bundle.main.url(forResource: "Bungee-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        if let url = Bundle.main.url(forResource: "NotoEmoji-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            InspectorCommands()
        }
    }
}
