//
//  RobotCharacterView.swift
//  Jarvis
//
//  OMNI-style 3D companion rendered from Robot.usdz, playing its baked
//  idle animation ("Take_001"). Rendered via RealityKit's SwiftUI RealityView.
//

import SwiftUI
import RealityKit

struct RobotCharacterView: View {
    var size: CGFloat = 90

    var body: some View {
        RealityView { content in
            guard let robot = try? await Entity(named: "Robot", in: Bundle.main) else {
                print("[JARVIS-DIAG] ❌ Entity(named:\"Robot\") FAILED to load")
                return
            }
            print("[JARVIS-DIAG] ✅ entity loaded, name=\(robot.name) children=\(robot.children.count) scale=\(robot.scale) anims=\(robot.availableAnimations.count)")

            // Normalize to a consistent on-screen size and recenter on origin.
            let bounds = robot.visualBounds(relativeTo: nil)
            print("[JARVIS-DIAG] bounds.extents=\(bounds.extents) center=\(bounds.center)")
            let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
            let target: Float = 0.35
            let factor = target / maxDim
            print("[JARVIS-DIAG] maxDim=\(maxDim) factor=\(factor)")
            robot.scale = SIMD3<Float>(repeating: factor)
            robot.position = -bounds.center * factor
            print("[JARVIS-DIAG] after: scale=\(robot.scale) pos=\(robot.position) newBounds=\(robot.visualBounds(relativeTo: nil).extents)")

            content.add(robot)

            // Key light so the white body reads with some shading.
            let key = DirectionalLight()
            key.light.intensity = 2500
            key.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(key)

            // Camera framing the character head-on.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 30
            camera.position = [0, 0.02, 0.9]
            camera.look(at: [0, 0, 0], from: [0, 0.02, 0.9], relativeTo: nil)
            content.add(camera)

            // Loop the baked idle animation.
            if let idle = robot.availableAnimations.first {
                robot.playAnimation(idle.repeat(), transitionDuration: 0.3, startsPaused: false)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    RobotCharacterView()
        .frame(width: 160, height: 160)
        .padding()
}
