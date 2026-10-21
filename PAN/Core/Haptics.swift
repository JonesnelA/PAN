//
//  Haptics.swift
//  盘 PAN
//
//  这个 App 里唯一的"声音"是震动。
//  整个工程不 import AVFoundation、不创建 AVAudioSession、不调用 AudioServices ——
//  所以静音键拨下去，手感一点不受影响；戴着耳机也不会出任何声。
//
//  性能要点：不要在每一帧新建 CHHapticPattern。CHHapticEngine 在 120Hz 下
//  频繁 makePlayer 会明显掉帧，所以这里预先建好几个固定强度的 player 反复复用。
//

import CoreHaptics
import UIKit
import QuartzCore

final class Haptics {

    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var players: [String: [CHHapticPatternPlayer]] = [:]
    private var cursors: [String: Int] = [:]
    private var lastPlayTime: CFTimeInterval = 0

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    // 没有 Taptic Engine 的设备（iPad / 老机型）走这里
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        light.prepare()
        soft.prepare()
        rigid.prepare()

        guard supportsHaptics, let engine = try? CHHapticEngine() else { return }
        self.engine = engine

        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = false

        engine.resetHandler = { [weak self] in
            try? self?.engine?.start()
            self?.rebuildPlayers()
        }
        engine.stoppedHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                try? self?.engine?.start()
            }
        }

        try? engine.start()
        rebuildPlayers()
    }

    // MARK: - 对外

    /// 齿位"咔"一下。strength 0…1
    func tick(strength: Double) {
        let name: String
        if strength > 0.72 { name = "tickHard" }
        else if strength > 0.42 { name = "tick" }
        else { name = "tickSoft" }
        play(name, minInterval: 0.010)
    }

    /// 泡泡破裂 / 捏一下
    func pop(strength: Double) {
        play(strength > 0.6 ? "pop" : "popSoft", minInterval: 0.012)
    }

    /// 手指落下
    func grab() {
        play("grab", minInterval: 0.05)
    }

    /// 松手 / 到底
    func thud() {
        play("thud", minInterval: 0.08)
    }

    /// 拖动的连续摩擦感：按速度给不同间隔的细碎震动
    func friction(speed: Double) {
        let clamped = min(max(speed, 0), 1)
        let interval = 0.055 - 0.040 * clamped   // 越快越密
        play(clamped > 0.5 ? "tickSoft" : "tick", minInterval: interval)
    }

    // MARK: - 播放

    private func play(_ name: String, minInterval: CFTimeInterval) {
        let now = CACurrentMediaTime()
        guard now - lastPlayTime >= minInterval else { return }
        lastPlayTime = now

        if engine?.isRunning != true {
            try? engine?.start()
        }

        if let player = nextPlayer(for: name),
           (try? player.start(atTime: CHHapticTimeImmediate)) != nil {
            return
        }
        fallback(name)
    }

    /// 每个音色准备三个 player 轮换使用。
    /// 高频"咔"如果用同一个 player，start() 会因为上一次还没播完而失败。
    private func nextPlayer(for name: String) -> CHHapticPatternPlayer? {
        guard let pool = players[name], !pool.isEmpty else { return nil }
        let index = (cursors[name] ?? 0) % pool.count
        cursors[name] = index + 1
        return pool[index]
    }

    private func fallback(_ name: String) {
        switch name {
        case "pop":     soft.impactOccurred(intensity: 0.95)
        case "popSoft": soft.impactOccurred(intensity: 0.6)
        case "thud":    rigid.impactOccurred(intensity: 1.0)
        case "grab":    light.impactOccurred(intensity: 0.5)
        case "tickHard": rigid.impactOccurred(intensity: 0.85)
        default:        light.impactOccurred(intensity: 0.55)
        }
    }

    private func rebuildPlayers() {
        guard let engine else { return }
        players.removeAll()
        cursors.removeAll()

        // name, intensity, sharpness
        let specs: [(String, Float, Float)] = [
            ("tickSoft", 0.34, 0.92),
            ("tick",     0.52, 0.95),
            ("tickHard", 0.78, 0.90),
            ("popSoft",  0.62, 0.58),
            ("pop",      0.92, 0.52),
            ("grab",     0.42, 0.24),
            ("thud",     0.88, 0.08)
        ]

        for (name, intensity, sharpness) in specs {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { continue }

            var pool: [CHHapticPatternPlayer] = []
            for _ in 0..<3 {
                if let player = try? engine.makePlayer(with: pattern) {
                    pool.append(player)
                }
            }
            players[name] = pool
            cursors[name] = 0
        }
    }
}
