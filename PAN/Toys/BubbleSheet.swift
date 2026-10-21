//
//  BubbleSheet.swift
//  盘 PAN
//
//  玩具二：无限泡泡纸。
//  按下或划过就爆一颗，爆完自动换一张新的。
//  每颗泡泡的手感略有差别（大气泡闷、小气泡脆），这是"真"的关键。
//

import SwiftUI
import QuartzCore
import Observation

@Observable
final class BubbleSheet {

    struct Bubble: Identifiable {
        let id = UUID()
        var center: CGPoint = .zero
        var radius: CGFloat = 0
        var popped = false
    }

    private(set) var bubbles: [Bubble] = []

    @ObservationIgnored private var canvasSize: CGSize = .zero
    @ObservationIgnored private var generation = 0

    // MARK: 布局

    func layout(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard size != canvasSize || bubbles.isEmpty else { return }
        canvasSize = size
        regenerate()
    }

    func regenerate() {
        generation += 1
        let width = canvasSize.width
        let height = canvasSize.height
        guard width > 0, height > 0 else { return }

        let columns = 5
        let rows = 8
        let marginX = width * 0.11
        let marginY = height * 0.13
        let usableW = width - marginX * 2
        let usableH = height - marginY * 2
        let stepX = usableW / CGFloat(columns - 1)
        let stepY = usableH / CGFloat(rows - 1)
        let baseRadius = min(stepX, stepY) * 0.45

        var result: [Bubble] = []
        result.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for column in 0..<columns {
                // 一点点抖动，避免太像贴图
                let jitterX = (CGFloat((row * 7 + column * 13) % 5) / 5.0 - 0.5) * stepX * 0.07
                let jitterY = (CGFloat((row * 11 + column * 5) % 7) / 7.0 - 0.5) * stepY * 0.07

                var bubble = Bubble()
                bubble.center = CGPoint(
                    x: marginX + CGFloat(column) * stepX + jitterX,
                    y: marginY + CGFloat(row) * stepY + jitterY
                )
                // 大小有极轻微差异，捏起来才不像机械阵列
                bubble.radius = baseRadius * (0.93 + CGFloat((row + column) % 3) * 0.035)
                result.append(bubble)
            }
        }
        bubbles = result
    }

    // MARK: 爆

    func pop(at point: CGPoint) {
        guard let index = bubbles.firstIndex(where: {
            !$0.popped && $0.center.distance(to: point) < $0.radius * 0.98
        }) else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            bubbles[index].popped = true
        }

        // 大气泡闷一点，小气泡脆一点
        let strength = bubbles[index].radius > 42 ? 0.85 : 0.45
        Haptics.shared.pop(strength: strength)

        if bubbles.allSatisfy({ $0.popped }) {
            scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.generation == current else { return }
            withAnimation(.easeOut(duration: 0.45)) {
                self.regenerate()
            }
        }
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

// MARK: - 视图

struct BubbleSheetView: View {

    @State private var sheet = BubbleSheet()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(sheet.bubbles) { bubble in
                    BubbleView(bubble: bubble)
                        .position(bubble.center)
                        .animation(.easeOut(duration: 0.16), value: bubble.popped)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sheet.pop(at: value.location)
                    }
            )
            .onAppear { sheet.layout(in: geo.size) }
            .onChange(of: geo.size) { _, newSize in
                sheet.layout(in: newSize)
            }
        }
    }
}

struct BubbleView: View {

    let bubble: BubbleSheet.Bubble

    var body: some View {
        ZStack {
            // 凹槽：爆掉之后留下的坑
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.105), Color(white: 0.042)],
                        center: UnitPoint(x: 0.5, y: 0.38),
                        startRadius: 0,
                        endRadius: bubble.radius * 1.05
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.045), lineWidth: 0.8)
                )
                .frame(width: bubble.radius * 1.88, height: bubble.radius * 1.88)

            // 泡泡本体
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.66), Color(white: 0.30), Color(white: 0.12)],
                        center: UnitPoint(x: 0.34, y: 0.26),
                        startRadius: 0,
                        endRadius: bubble.radius * 1.45
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                )
                .overlay(alignment: .topLeading) {
                    // 高光
                    Ellipse()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: bubble.radius * 0.50, height: bubble.radius * 0.32)
                        .blur(radius: bubble.radius * 0.16)
                        .offset(x: bubble.radius * 0.36, y: bubble.radius * 0.32)
                }
                .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                .scaleEffect(bubble.popped ? 0.001 : 1)
                .opacity(bubble.popped ? 0 : 1)
        }
    }
}
