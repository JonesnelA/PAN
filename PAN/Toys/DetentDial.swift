//
//  DetentDial.swift
//  盘 PAN
//
//  玩具一：棘轮表盘。
//  手指拨动 → 每越过一个齿位就"咔"一下，松手后靠惯性继续转，越转越慢，
//  最后自动吸附进最近的一个齿位里。这是最像"盘"的一件。
//

import SwiftUI
import QuartzCore
import Observation

// MARK: - 物理模型

@Observable
final class DialModel {

    let detentCount = 72

    private(set) var angle: Double = 0        // 弧度
    private(set) var velocity: Double = 0     // 弧度/秒
    private(set) var isDragging = false

    @ObservationIgnored private var lastTouchAngle: Double?
    @ObservationIgnored private var lastTouchTime: CFTimeInterval = 0
    @ObservationIgnored private var lastDetentIndex: Int = 0

    var step: Double { 2 * Double.pi / Double(detentCount) }

    // MARK: 输入

    func beginTouch() {
        guard !isDragging else { return }
        isDragging = true
        velocity = 0
        lastTouchAngle = nil
        lastTouchTime = CACurrentMediaTime()
        lastDetentIndex = detentIndex
        Haptics.shared.grab()
    }

    func track(_ location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        let distance = (dx * dx + dy * dy).squareRoot()

        // 中心轴附近是死区：极坐标在这里会剧烈跳变，容易把盘"甩飞"
        guard distance > Double(min(size.width, size.height)) * 0.10 else {
            lastTouchAngle = nil
            return
        }

        let current = atan2(dy, dx)
        guard let last = lastTouchAngle else {
            lastTouchAngle = current
            return
        }

        var delta = current - last
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        angle += delta
        lastTouchAngle = current

        let now = CACurrentMediaTime()
        let dt = max(now - lastTouchTime, 1.0 / 240.0)
        lastTouchTime = now
        velocity = velocity * 0.62 + (delta / dt) * 0.38

        emitDetents()
    }

    func endTouch() {
        guard isDragging else { return }
        isDragging = false
        lastTouchAngle = nil
        velocity = max(min(velocity, 30), -30)
        if abs(velocity) < 0.4 { velocity = 0 }
    }

    // MARK: 每帧

    func advance(_ dt: Double) {
        guard !isDragging else { return }

        if abs(velocity) < 1.0 {
            // 低速：吸附到最近的齿心，做出"入位"的手感
            let target = (angle / step).rounded() * step
            let diff = target - angle
            angle += diff * min(1, dt * 13)
            velocity *= pow(0.90, dt * 60)
            if abs(diff) < 0.0025 && abs(velocity) < 0.02 {
                angle = target
                velocity = 0
            }
            emitDetents()
            return
        }

        angle += velocity * dt
        velocity *= pow(0.978, dt * 60)
        emitDetents()
    }

    // MARK: 齿位

    private var detentIndex: Int {
        Int((angle / step).rounded(.down))
    }

    private func emitDetents() {
        let index = detentIndex
        guard index != lastDetentIndex else { return }
        lastDetentIndex = index

        // 转得越快，"咔"得越轻 —— 快到一定程度会糊成一片摩擦感，这正好
        let speed = min(abs(velocity) / 14.0, 1.0)
        Haptics.shared.tick(strength: 1.0 - speed * 0.62)
    }
}

// MARK: - 视图

struct DetentDialView: View {

    @State private var model = DialModel()
    @State private var driver = FrameDriver()

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.84

            ZStack {
                // 背后的柔光，让金属浮起来
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.075), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.78
                        )
                    )
                    .frame(width: side * 1.7, height: side * 1.7)
                    .blur(radius: 55)

                DialCanvas(angle: model.angle, detents: model.detentCount)
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.85), radius: 34, x: 0, y: 20)

                // 按下时中心浮起一圈极淡的高光
                Circle()
                    .stroke(Color.white.opacity(model.isDragging ? 0.16 : 0), lineWidth: 1)
                    .frame(width: side * 0.44, height: side * 0.44)
                    .blur(radius: 0.6)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geo.size))
            .animation(.easeOut(duration: 0.18), value: model.isDragging)
        }
        .onAppear {
            driver.onFrame = { dt in model.advance(dt) }
            driver.start()
        }
        .onDisappear { driver.stop() }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !model.isDragging { model.beginTouch() }
                model.track(value.location, in: size)
            }
            .onEnded { _ in model.endTouch() }
    }
}

// MARK: - 表盘绘制

struct DialCanvas: View {

    let angle: Double
    let detents: Int

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            drawBezel(&context, center: center, r: radius)
            drawKnurl(&context, center: center, r: radius)
            drawFace(&context, center: center, r: radius)
            drawGraduations(&context, center: center, r: radius)
            drawBrassRing(&context, center: center, r: radius)
            drawHub(&context, center: center, r: radius)
            drawIndex(&context, center: center, r: radius)
        }
    }

    // 外圈金属斜面
    private func drawBezel(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let path = Path(ellipseIn: rect)

        let gradient = Gradient(stops: [
            .init(color: Color(white: 0.34), location: 0.00),
            .init(color: Color(white: 0.76), location: 0.09),
            .init(color: Color(white: 0.20), location: 0.20),
            .init(color: Color(white: 0.58), location: 0.34),
            .init(color: Color(white: 0.16), location: 0.47),
            .init(color: Color(white: 0.70), location: 0.60),
            .init(color: Color(white: 0.22), location: 0.73),
            .init(color: Color(white: 0.52), location: 0.86),
            .init(color: Color(white: 0.34), location: 1.00)
        ])

        ctx.fill(path, with: .conicGradient(gradient, center: center))
        ctx.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 0.8)
    }

    // 滚花：72 道细齿，随盘一起转
    private func drawKnurl(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let inner = r * 0.858
        let outer = r * 0.972

        for i in 0..<detents {
            let a = Double(i) / Double(detents) * 2 * .pi + angle
            let cosine = CGFloat(cos(a))
            let sine = CGFloat(sin(a))

            var path = Path()
            path.move(to: CGPoint(x: center.x + cosine * inner, y: center.y + sine * inner))
            path.addLine(to: CGPoint(x: center.x + cosine * outer, y: center.y + sine * outer))

            // 光从左上来，齿侧的反射随角度变化
            let light = max(0, cos(a + 2.36))
            ctx.stroke(
                path,
                with: .color(.white.opacity(0.045 + 0.24 * light)),
                lineWidth: 1.1
            )
        }
    }

    // 盘面
    private func drawFace(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let innerR = r * 0.845
        let rect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
        let path = Path(ellipseIn: rect)

        ctx.fill(path, with: .radialGradient(
            Gradient(colors: [
                Color(white: 0.19),
                Color(white: 0.085),
                Color(white: 0.028)
            ]),
            center: CGPoint(x: center.x - innerR * 0.34, y: center.y - innerR * 0.40),
            startRadius: innerR * 0.04,
            endRadius: innerR * 1.42
        ))

        // 内沿投影，压出一圈厚度
        ctx.drawLayer { layer in
            layer.clip(to: path)
            layer.addFilter(.blur(radius: innerR * 0.055))
            layer.stroke(path, with: .color(.black.opacity(0.85)), lineWidth: innerR * 0.13)
        }

        ctx.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 0.8)
    }

    // 刻度：60 格，每 5 格一条长线
    private func drawGraduations(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let count = 60

        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * .pi + angle
            let major = i % 5 == 0
            let near = r * (major ? 0.744 : 0.770)
            let far = r * 0.800
            let cosine = CGFloat(cos(a))
            let sine = CGFloat(sin(a))

            var path = Path()
            path.move(to: CGPoint(x: center.x + cosine * near, y: center.y + sine * near))
            path.addLine(to: CGPoint(x: center.x + cosine * far, y: center.y + sine * far))

            ctx.stroke(
                path,
                with: .color(.white.opacity(major ? 0.52 : 0.15)),
                lineWidth: major ? 1.4 : 0.8
            )
        }
    }

    // 一道极细的黄铜内环
    private func drawBrassRing(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let ringR = r * 0.822
        let rect = CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2)
        ctx.stroke(Path(ellipseIn: rect), with: .color(Palette.brass.opacity(0.20)), lineWidth: 0.9)
    }

    // 中心轴
    private func drawHub(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let hubR = r * 0.185
        let rect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)

        let gradient = Gradient(stops: [
            .init(color: Color(white: 0.66), location: 0.00),
            .init(color: Color(white: 0.26), location: 0.25),
            .init(color: Color(white: 0.52), location: 0.48),
            .init(color: Color(white: 0.18), location: 0.72),
            .init(color: Color(white: 0.44), location: 1.00)
        ])
        ctx.fill(Path(ellipseIn: rect), with: .conicGradient(gradient, center: center))

        let innerR = hubR * 0.80
        let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
        ctx.fill(Path(ellipseIn: innerRect), with: .radialGradient(
            Gradient(colors: [Color(white: 0.16), Color(white: 0.04)]),
            center: CGPoint(x: center.x - innerR * 0.3, y: center.y - innerR * 0.35),
            startRadius: 0,
            endRadius: innerR * 1.4
        ))

        // 一字螺丝槽
        var slot = Path()
        slot.move(to: CGPoint(x: center.x - hubR * 0.58, y: center.y))
        slot.addLine(to: CGPoint(x: center.x + hubR * 0.58, y: center.y))
        ctx.stroke(slot, with: .color(.black.opacity(0.62)), lineWidth: hubR * 0.17)
        ctx.stroke(slot, with: .color(.white.opacity(0.09)), lineWidth: hubR * 0.05)
    }

    // 固定的一枚黄铜指针，用来感知盘在转
    private func drawIndex(_ ctx: inout GraphicsContext, center: CGPoint, r: CGFloat) {
        let y = center.y - r * 0.725
        let rect = CGRect(x: center.x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Palette.brass.opacity(0.9)))
    }
}
