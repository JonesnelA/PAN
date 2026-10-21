//
//  Ferrofluid.swift
//  盘 PAN
//
//  玩具三：一坨磁流体 / 液态金属。
//  手指靠近时，周围的尖刺会立起来；拖着走会有连续的摩擦震感。
//  它不是"点击有反馈"，而是"你碰它，它变了形"。
//

import SwiftUI
import QuartzCore
import Observation

@Observable
final class FluidModel {

    private(set) var phase: Double = 0
    private(set) var touchPoint: CGPoint?
    private(set) var isTouching = false

    @ObservationIgnored private var lastPoint: CGPoint?
    @ObservationIgnored private var lastTime: CFTimeInterval = 0

    func advance(_ dt: Double) {
        phase += dt
    }

    func begin(_ point: CGPoint) {
        guard !isTouching else { return }
        isTouching = true
        touchPoint = point
        lastPoint = point
        lastTime = CACurrentMediaTime()
        Haptics.shared.grab()
    }

    func move(_ point: CGPoint) {
        guard isTouching else { return }
        touchPoint = point

        let now = CACurrentMediaTime()
        let dt = max(now - lastTime, 1.0 / 240.0)
        lastTime = now

        if let last = lastPoint {
            let speed = Double(last.distance(to: point)) / dt   // pt/s
            Haptics.shared.friction(speed: speed / 1500.0)
        }
        lastPoint = point
    }

    func end() {
        guard isTouching else { return }
        isTouching = false
        touchPoint = nil
        lastPoint = nil
        Haptics.shared.thud()
    }
}

// MARK: - 视图

struct FerrofluidView: View {

    @State private var model = FluidModel()
    @State private var driver = FrameDriver()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let baseRadius = min(size.width, size.height) * 0.255

            ZStack {
                RadialGradient(
                    colors: [Color(white: 0.085), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: baseRadius * 2.6
                )
                .frame(width: baseRadius * 5.2, height: baseRadius * 5.2)
                .blur(radius: 45)

                Canvas { context, canvasSize in
                    drawBlob(
                        &context,
                        size: canvasSize,
                        baseRadius: baseRadius,
                        phase: model.phase,
                        touch: model.touchPoint
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !model.isTouching { model.begin(value.location) }
                        model.move(value.location)
                    }
                    .onEnded { _ in model.end() }
            )
        }
        .onAppear {
            driver.onFrame = { dt in model.advance(dt) }
            driver.start()
        }
        .onDisappear { driver.stop() }
    }

    // MARK: 绘制

    private func drawBlob(_ ctx: inout GraphicsContext,
                          size: CGSize,
                          baseRadius: CGFloat,
                          phase: Double,
                          touch: CGPoint?) {

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let spikeCount = 22.0
        let samples = 280

        let touchDX = touch.map { Double($0.x - center.x) }
        let touchDY = touch.map { Double($0.y - center.y) }
        let touchDistance = (touchDX ?? 0) * (touchDX ?? 0) + (touchDY ?? 0) * (touchDY ?? 0)
        let touchAngle = (touchDX != nil) ? atan2(touchDY ?? 0, touchDX ?? 0) : 0
        let proximityRange = Double(baseRadius) * 1.7

        var points: [CGPoint] = []
        points.reserveCapacity(samples)

        for index in 0..<samples {
            let a = Double(index) / Double(samples) * 2 * .pi

            // 磁尖：cos 的高次幂，形成细长的锥
            let spike = pow(max(0, cos(a * spikeCount)), 12)

            // 缓慢的呼吸起伏，静止时也不死板
            let breathe = 0.014 * sin(a * 3 + phase * 0.75)
                + 0.009 * sin(a * 7 - phase * 1.15)

            var radial = 1.0 + breathe

            if touch != nil {
                // 与手指方向的角距离
                let diff = abs(atan2(sin(a - touchAngle), cos(a - touchAngle)))
                let angular = exp(-pow(diff / 0.80, 2.0))
                let distance = touchDistance.squareRoot()
                let falloff = exp(-pow(distance / proximityRange, 2.0))
                radial += 0.34 * spike * angular * falloff
                radial += 0.05 * angular * falloff
            }

            radial += 0.045 * spike

            let radius = CGFloat(radial) * baseRadius
            points.append(CGPoint(
                x: center.x + CGFloat(cos(a)) * radius,
                y: center.y + CGFloat(sin(a)) * radius
            ))
        }

        guard points.count > 3 else { return }

        // 中点平滑，把折线连成液体
        var path = Path()
        path.move(to: points[0])
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
        }
        path.closeSubpath()

        // 液体本体
        ctx.fill(path, with: .radialGradient(
            Gradient(colors: [
                Color(white: 0.36),
                Color(white: 0.14),
                Color(white: 0.035)
            ]),
            center: CGPoint(x: center.x - baseRadius * 0.32, y: center.y - baseRadius * 0.44),
            startRadius: 0,
            endRadius: baseRadius * 1.75
        ))

        // 边缘反光
        ctx.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 1)

        // 大块柔光高光（裁在形状里）
        ctx.drawLayer { layer in
            layer.clip(to: path)
            layer.addFilter(.blur(radius: baseRadius * 0.10))
            let rect = CGRect(
                x: center.x - baseRadius * 0.66,
                y: center.y - baseRadius * 0.82,
                width: baseRadius * 0.82,
                height: baseRadius * 0.44
            )
            layer.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.20)))

            // 一点锐利的小高光，让表面像真的湿的
            let spot = CGRect(
                x: center.x - baseRadius * 0.48,
                y: center.y - baseRadius * 0.62,
                width: baseRadius * 0.14,
                height: baseRadius * 0.09
            )
            layer.fill(Path(ellipseIn: spot), with: .color(.white.opacity(0.55)))
        }
    }
}
