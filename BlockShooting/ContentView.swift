//
//  ContentView.swift
//  xcodeTest
//
//  Created by 斎藤剛 on 2026/05/05.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var game = GameState()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 敵
                ForEach(game.enemies) { enemy in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 40, height: 30)
                        .position(enemy.position)
                }

                // 弾
                ForEach(game.bullets) { bullet in
                    Capsule()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 18)
                        .position(bullet.position)
                }

                // 自機
                Triangle()
                    .fill(Color.cyan)
                    .frame(width: 44, height: 44)
                    .position(x: game.playerX, y: geo.size.height - 70)

                // スコア
                Text("SCORE: \(game.score)")
                    .foregroundColor(.white)
                    .font(.headline)
                    .position(x: 70, y: 24)

                // 操作ボタン
                HStack {
                    ControlButton(label: "◀") { game.moveLeft() }
                    Spacer()
                    ControlButton(label: "🔥") { game.shoot(playerY: geo.size.height - 70) }
                    Spacer()
                    ControlButton(label: "▶") { game.moveRight(maxX: geo.size.width) }
                }
                .padding(.horizontal, 32)
                .position(x: geo.size.width / 2, y: geo.size.height - 30)

                // ゲームオーバー
                if game.isGameOver {
                    VStack(spacing: 16) {
                        Text("GAME OVER")
                            .font(.largeTitle.bold())
                            .foregroundColor(.red)
                        Text("SCORE: \(game.score)")
                            .font(.title2)
                            .foregroundColor(.white)
                        Button("もう一度") {
                            game.restart(screenSize: geo.size)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .onAppear {
                game.start(screenSize: geo.size)
            }
        }
    }
}

// MARK: - 三角形（自機）

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - 操作ボタン

struct ControlButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title)
                .frame(width: 64, height: 64)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }
}

// MARK: - ゲームオブジェクト

struct GameObject: Identifiable {
    let id = UUID()
    var position: CGPoint
}

// MARK: - ゲーム状態

@MainActor
class GameState: ObservableObject {
    @Published var playerX: CGFloat = 200
    @Published var bullets: [GameObject] = []
    @Published var enemies: [GameObject] = []
    @Published var score = 0
    @Published var isGameOver = false

    private var screenSize: CGSize = .zero
    private var gameTimer: Timer?
    private var enemyTimer: Timer?

    func start(screenSize: CGSize) {
        self.screenSize = screenSize
        playerX = screenSize.width / 2
        startTimers()
    }

    func restart(screenSize: CGSize) {
        bullets = []
        enemies = []
        score = 0
        isGameOver = false
        playerX = screenSize.width / 2
        startTimers()
    }

    private func startTimers() {
        gameTimer?.invalidate()
        enemyTimer?.invalidate()

        // RunLoop.main に明示的に追加することで確実に動作させる
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(gameTimer!, forMode: .common)
        
        enemyTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.spawnEnemy()
        }
        RunLoop.main.add(enemyTimer!, forMode: .common)
    }

    private func update() {
        guard !isGameOver else { return }

        // 弾を上に移動
        bullets = bullets
            .map { GameObject(position: CGPoint(x: $0.position.x, y: $0.position.y - 8)) }
            .filter { $0.position.y > 0 }

        // 敵を下に移動
        enemies = enemies
            .map { GameObject(position: CGPoint(x: $0.position.x, y: $0.position.y + 1.5)) }

        // 敵が画面下に到達 → ゲームオーバー
        if enemies.contains(where: { $0.position.y > screenSize.height - 80 }) {
            isGameOver = true
            gameTimer?.invalidate()
            enemyTimer?.invalidate()
            return
        }

        // 衝突判定
        var hitEnemyIDs = Set<UUID>()
        var hitBulletIDs = Set<UUID>()
        for bullet in bullets {
            for enemy in enemies {
                if abs(bullet.position.x - enemy.position.x) < 28
                    && abs(bullet.position.y - enemy.position.y) < 24 {
                    hitEnemyIDs.insert(enemy.id)
                    hitBulletIDs.insert(bullet.id)
                    score += 1
                }
            }
        }
        enemies = enemies.filter { !hitEnemyIDs.contains($0.id) }
        bullets = bullets.filter { !hitBulletIDs.contains($0.id) }
    }

    private func spawnEnemy() {
        guard !isGameOver else { return }
        let x = CGFloat.random(in: 30...(screenSize.width - 30))
        enemies.append(GameObject(position: CGPoint(x: x, y: 30)))
    }

    func moveLeft() {
        playerX = max(30, playerX - 24)
    }

    func moveRight(maxX: CGFloat) {
        playerX = min(maxX - 30, playerX + 24)
    }

    func shoot(playerY: CGFloat) {
        bullets.append(GameObject(position: CGPoint(x: playerX, y: playerY - 24)))
    }
}

#Preview {
    ContentView()
}
