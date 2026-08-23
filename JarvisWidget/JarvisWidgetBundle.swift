//
//  JarvisWidgetBundle.swift
//  JarvisWidget
//
//  Created by Muhamad Ega Nugraha on 01/04/26.
//

import WidgetKit
import SwiftUI

@main
struct JarvisWidgetBundle: WidgetBundle {
    var body: some Widget {
        JarvisWidget()
        JarvisWidgetControl()
        JarvisWidgetLiveActivity()
    }
}
