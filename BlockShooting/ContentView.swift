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
                        .fill(enemy.isPurple ? Color.purple : Color.red)
                        .frame(width: 40, height: 30)
                        .position(enemy.position)
                }

                // ボス
                if let bossPos = game.bossPosition {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                        .frame(width: 80, height: 50)
                        .position(bossPos)
                    // HPバー
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 80, height: 8)
                        .position(x: bossPos.x, y: bossPos.y + 35)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                        .frame(width: 80 * CGFloat(game.bossHP) / CGFloat(20), height: 8)
                        .position(x: bossPos.x - (80 - 80 * CGFloat(game.bossHP) / CGFloat(20)) / 2, y: bossPos.y + 35)
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

                // 操作ボタン・ボム
                HStack {
                    ControlButton(label: "◀") { game.moveLeft() }
                    Spacer()
                    Button {
                        game.useBomb()
                    } label: {
                        Text("💣 ×\(game.bombCount)")
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(game.bombCount > 0 ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(game.bombCount <= 0)
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

    @State private var pressing = false
    @State private var moveTimer: Timer?

    var body: some View {
        Text(label)
            .font(.title)
            .frame(width: 64, height: 64)
            .background(pressing ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.white)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        action()
                        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                            action()
                        }
                        RunLoop.main.add(moveTimer!, forMode: .common)
                    }
                    .onEnded { _ in
                        pressing = false
                        moveTimer?.invalidate()
                        moveTimer = nil
                    }
            )
    }
}

// MARK: - ゲームオブジェクト

enum EnemyType {
    case normal
    case purple(direction: CGFloat)
}

struct GameObject: Identifiable {
    let id = UUID()
    var position: CGPoint
    var enemyType: EnemyType = .normal
    var reachedCenter = false

    var isPurple: Bool {
        if case .purple = enemyType { return true }
        return false
    }
}

// MARK: - ゲーム状態

@MainActor
class GameState: ObservableObject {
    @Published var playerX: CGFloat = 200
    @Published var bullets: [GameObject] = []
    @Published var enemies: [GameObject] = []
    @Published var score = 0
    @Published var isGameOver = false
    @Published var bombCount = 3
    @Published var bossPosition: CGPoint? = nil
    @Published var bossHP = 0
    private let bossMaxHP = 20

    private var screenSize: CGSize = .zero
    private var gameTimer: Timer?
    private var shootTimer: Timer?
    private var enemySpawnCounter: Int = 0
    private var bossDirection: CGFloat = 1.5
    private var lastBossScore = 0

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
        bombCount = 3
        bossPosition = nil
        bossHP = 0
        lastBossScore = 0
        playerX = screenSize.width / 2
        self.screenSize = screenSize
        startTimers()
    }

    private var enemySpawnInterval: Int {
        max(25, 75 - score * 2)
    }

    private func startTimers() {
        gameTimer?.invalidate()
        shootTimer?.invalidate()
        enemySpawnCounter = 0

        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(gameTimer!, forMode: .common)

        shootTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            self?.autoShoot()
        }
        RunLoop.main.add(shootTimer!, forMode: .common)
    }

    private func update() {
        guard !isGameOver else { return }

        // 敵の生成
        enemySpawnCounter += 1
        if enemySpawnCounter >= enemySpawnInterval {
            spawnEnemy()
            enemySpawnCounter = 0
        }

        // 弾を上に移動
        bullets = bullets
            .map { GameObject(position: CGPoint(x: $0.position.x, y: $0.position.y - 8)) }
            .filter { $0.position.y > 0 }

        // 敵を移動
        let midY = screenSize.height / 2
        enemies = enemies.map { enemy in
            var e = enemy
            switch e.enemyType {
            case .normal:
                e.position.y += 1.5
            case .purple(let dir):
                if e.reachedCenter {
                    e.position.x += dir
                } else if e.position.y >= midY {
                    e.reachedCenter = true
                    e.position.x += dir
                } else {
                    e.position.y += 1.5
                }
            }
            return e
        }

        // 通常敵が画面下に到達 → ゲームオーバー
        if enemies.contains(where: { !$0.isPurple && $0.position.y > screenSize.height - 80 }) {
            isGameOver = true
            gameTimer?.invalidate()
            shootTimer?.invalidate()
            return
        }

        // 画面外の紫敵を除去
        enemies.removeAll { $0.isPurple && ($0.position.x < -30 || $0.position.x > screenSize.width + 30) }

        // ボスのスポーン判定
        let bossThreshold = (lastBossScore / 100 + 1) * 100
        if score >= bossThreshold && bossPosition == nil {
            lastBossScore = score
            bossHP = bossMaxHP
            bossPosition = CGPoint(x: screenSize.width / 2, y: 60)
        }

        // ボスの移動（左右に往復）
        if var pos = bossPosition {
            pos.x += bossDirection
            if pos.x <= 40 || pos.x >= screenSize.width - 40 {
                bossDirection *= -1
            }
            bossPosition = pos
        }

        // 衝突判定
        var hitEnemyIDs = Set<UUID>()
        var hitBulletIDs = Set<UUID>()
        for bullet in bullets {
            // ボスとの衝突
            if let bPos = bossPosition,
               abs(bullet.position.x - bPos.x) < 40
                && abs(bullet.position.y - bPos.y) < 30 {
                hitBulletIDs.insert(bullet.id)
                bossHP -= 1
                if bossHP <= 0 {
                    bossPosition = nil
                    score += 10
                }
                continue
            }
            for enemy in enemies {
                if abs(bullet.position.x - enemy.position.x) < 28
                    && abs(bullet.position.y - enemy.position.y) < 24 {
                    hitEnemyIDs.insert(enemy.id)
                    hitBulletIDs.insert(bullet.id)
                    score += 1
                    if enemy.isPurple {
                        bombCount += 1
                    }
                }
            }
        }
        enemies = enemies.filter { !hitEnemyIDs.contains($0.id) }
        bullets = bullets.filter { !hitBulletIDs.contains($0.id) }
    }

    private func spawnEnemy() {
        guard !isGameOver else { return }
        let x = CGFloat.random(in: 30...(screenSize.width - 30))

        if Int.random(in: 0..<10) == 0 {
            let dir: CGFloat = Bool.random() ? 3.0 : -3.0
            var enemy = GameObject(position: CGPoint(x: x, y: 30))
            enemy.enemyType = .purple(direction: dir)
            enemies.append(enemy)
        } else {
            enemies.append(GameObject(position: CGPoint(x: x, y: 30)))
        }
    }

    func moveLeft() {
        playerX = max(30, playerX - 6)
    }

    func moveRight(maxX: CGFloat) {
        playerX = min(maxX - 30, playerX + 6)
    }

    func useBomb() {
        guard !isGameOver, bombCount > 0 else { return }
        bombCount -= 1
        score += enemies.count
        enemies.removeAll()
        if bossPosition != nil {
            bossHP -= 5
            if bossHP <= 0 {
                bossPosition = nil
                score += 10
            }
        }
    }

    private func autoShoot() {
        guard !isGameOver else { return }
        let playerY = screenSize.height - 70
        bullets.append(GameObject(position: CGPoint(x: playerX, y: playerY - 24)))
    }
}

#Preview {
    ContentView()
}
