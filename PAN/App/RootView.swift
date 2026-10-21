//
//  RootView.swift
//  盘 PAN
//
//  三个玩具，一组小点。没有标题、没有设置、没有数字。
//

import SwiftUI
import UIKit

struct RootView: View {

    @State private var index = 0

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            // 极淡的中心光，让黑色不至于死
            RadialGradient(
                colors: [Color.white.opacity(0.035), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Group {
                switch index {
                case 0: DetentDialView()
                case 1: BubbleSheetView()
                default: FerrofluidView()
                }
            }
            .transition(.opacity)

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { item in
                        Circle()
                            .fill(Color.white.opacity(item == index ? 0.80 : 0.20))
                            .frame(width: item == index ? 6 : 4.5,
                                   height: item == index ? 6 : 4.5)
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                            .onTapGesture {
                                index = item
                            }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .animation(.easeInOut(duration: 0.26), value: index)
        .onAppear {
            // 这种东西会一直玩，别让它自动锁屏
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
