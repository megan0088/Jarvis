//
//  PetWidgetsBundle.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//
//  This file is meant for the Widget Extension target only.
//  Ensure the build setting OTHER_SWIFT_FLAGS contains -DWIDGET_EXTENSION
//  for the Widget target, and remove this file from the main app target.
//

#if WIDGET_EXTENSION
import SwiftUI
import WidgetKit

@main
struct PetWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PetWidget()
        PetActivityWidget()
    }
}
#endif
