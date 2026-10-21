//
//  FrameDriver.swift
//  盘 PAN
//
//  CADisplayLink 的轻封装。用 SwiftUI 的 TimelineView(.animation) 也能每帧刷新，
//  但它不给你 dt，物理积分会变得很别扭。这里直接拿 CADisplayLink，顺带开 120Hz。
//

import QuartzCore
import Observation

@Observable
final class FrameDriver {

    @ObservationIgnored var onFrame: ((Double) -> Void)?

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var proxy: Proxy?
    @ObservationIgnored private var lastTime: CFTimeInterval = 0

    private final class Proxy: NSObject {
        let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }

    func start() {
        guard link == nil else { return }
        let proxy = Proxy { [weak self] in self?.step() }
        self.proxy = proxy

        let link = CADisplayLink(target: proxy, selector: #selector(Proxy.fire))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }
        link.add(to: .main, forMode: .common)
        self.link = link

        lastTime = CACurrentMediaTime()
    }

    func stop() {
        link?.invalidate()
        link = nil
        proxy = nil
    }

    private func step() {
        let now = CACurrentMediaTime()
        // 从后台切回来时 dt 可能是一大跳，钳住避免物理炸掉
        let dt = min(max(now - lastTime, 0), 1.0 / 30.0)
        lastTime = now
        onFrame?(dt)
    }
}
