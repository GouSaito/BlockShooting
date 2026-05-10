//
//  ContentView.swift
//  xcodeTest
//
//  Created by 斎藤剛 on 2026/05/05.
//  

import SwiftUI
import Combine
import AVFoundation

enum Screen {
    case title
    case game
    case gameOver(score: Int)
}

struct ContentView: View {
    @State private var screen: Screen = .title

    var body: some View {
        switch screen {
        case .title:
            TitleView {
                screen = .game
            }
        case .game:
            GameView { score in
                screen = .gameOver(score: score)
            }
        case .gameOver(let score):
            GameOverView(score: score, onRetry: {
                SoundManager.shared.stopAllSE()
                screen = .game
            }, onTitle: {
                SoundManager.shared.stopAllSE()
                screen = .title
            })
        }
    }
}

// MARK: - タイトル画面

struct TitleView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Image("BlockShootingTitle")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 32)
                Button(action: {
                    SoundManager.shared.playStart()
                    onStart()
                }) {
                    Image("start_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                }
            }
        }
    }
}

// MARK: - ゲームオーバー画面

struct GameOverView: View {
    let score: Int
    let onRetry: () -> Void
    let onTitle: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Image("GameOver")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 32)
                    Text("SCORE: \(score)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 4)
                        .offset(y: 90)
                }
                VStack(spacing: 12) {
                    Button(action: onRetry) {
                        Text("もう一度")
                            .font(.title3.bold())
                            .frame(width: 200)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button(action: onTitle) {
                        Text("タイトルへ")
                            .font(.title3.bold())
                            .frame(width: 200)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .onAppear {
            SoundManager.shared.playGameOver()
        }
    }
}

// MARK: - ゲーム画面

struct GameView: View {
    @StateObject private var game = GameState()
    let onGameOver: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 敵
                ForEach(game.enemies) { enemy in
                    Circle()
                        .fill(enemy.enemyColor)
                        .frame(width: 36, height: 36)
                        .position(enemy.position)
                }

                // ボス
                if let bossPos = game.bossPosition {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                        .frame(width: 80, height: 50)
                        .position(bossPos)
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
                    ControlButton(label: "◀", isPressed: $game.movingLeft)
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
                    ControlButton(label: "▶", isPressed: $game.movingRight)
                }
                .padding(.horizontal, 32)
                .position(x: geo.size.width / 2, y: geo.size.height - 30)
            }
            .onAppear {
                game.start(screenSize: geo.size)
            }
            .onDisappear {
                game.stop()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                game.pause()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                game.resume()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                game.stop()
            }
            .onChange(of: game.isGameOver) { _, isOver in
                if isOver {
                    let finalScore = game.score
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onGameOver(finalScore)
                    }
                }
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
    @Binding var isPressed: Bool

    var body: some View {
        Text(label)
            .font(.title)
            .frame(width: 64, height: 64)
            .background(isPressed ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.white)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - ゲームオブジェクト

enum EnemyType {
    case normal
    case purple(direction: CGFloat)
    case golden(direction: CGFloat)
}

struct GameObject: Identifiable {
    let id = UUID()
    var position: CGPoint
    var enemyType: EnemyType = .normal
    var reachedCenter = false
    var velocityX: CGFloat = 0
    var velocityY: CGFloat = -8

    var isPurple: Bool {
        if case .purple = enemyType { return true }
        return false
    }

    var isGolden: Bool {
        if case .golden = enemyType { return true }
        return false
    }

    var isEscaper: Bool { isPurple || isGolden }

    var enemyColor: Color {
        switch enemyType {
        case .normal: return .red
        case .purple: return .purple
        case .golden: return .yellow
        }
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
    @Published var bulletCount = 1
    @Published var movingLeft = false
    @Published var movingRight = false
    @Published var bossPosition: CGPoint? = nil
    @Published var bossHP = 0
    private let bossMaxHP = 20

    private var screenSize: CGSize = .zero
    private var gameTimer: Timer?
    private var shootTimer: Timer?
    private var enemySpawnCounter: Int = 0
    private var bossDirection: CGFloat = 1.5
    private var lastBossScore = 0

    deinit {
        SoundManager.shared.stopBGM()
    }

    func stop() {
        gameTimer?.invalidate()
        shootTimer?.invalidate()
        SoundManager.shared.stopBGM()
    }

    func pause() {
        gameTimer?.invalidate()
        shootTimer?.invalidate()
        SoundManager.shared.stopBGM()
        SoundManager.shared.stopAllSE()
    }

    func resume() {
        guard !isGameOver else { return }
        startTimers()
        SoundManager.shared.startBGM()
    }

    func start(screenSize: CGSize) {
        self.screenSize = screenSize
        playerX = screenSize.width / 2
        startTimers()
        SoundManager.shared.startBGM()
    }

    func restart(screenSize: CGSize) {
        SoundManager.shared.stopAllSE()
        bullets = []
        enemies = []
        score = 0
        isGameOver = false
        bombCount = 3
        bulletCount = 1
        bossPosition = nil
        bossHP = 0
        lastBossScore = 0
        playerX = screenSize.width / 2
        self.screenSize = screenSize
        startTimers()
        SoundManager.shared.startBGM()
    }

    private var enemySpawnInterval: Int {
        max(10, 75 - score * 75 / 1000)
    }

    private var enemySpeed: CGFloat {
        min(8, 0.5 + CGFloat(score) * 0.01)
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

        // 自機の移動
        if movingLeft { playerX = max(30, playerX - 3) }
        if movingRight { playerX = min(screenSize.width - 30, playerX + 3) }

        // 敵の生成
        enemySpawnCounter += 1
        if enemySpawnCounter >= enemySpawnInterval {
            spawnEnemy()
            enemySpawnCounter = 0
        }

        // 弾を移動
        bullets = bullets
            .map { var b = $0; b.position.x += b.velocityX; b.position.y += b.velocityY; return b }
            .filter { $0.position.y > 0 && $0.position.y < screenSize.height && $0.position.x > 0 && $0.position.x < screenSize.width }

        // 敵を移動
        let midY = screenSize.height / 2
        enemies = enemies.map { enemy in
            var e = enemy
            switch e.enemyType {
            case .normal:
                e.position.y += enemySpeed
            case .purple(let dir), .golden(let dir):
                if e.reachedCenter {
                    e.position.x += dir
                } else if e.position.y >= midY {
                    e.reachedCenter = true
                    e.position.x += dir
                } else {
                    e.position.y += enemySpeed
                }
            }
            return e
        }

        // 通常敵が画面下に到達 → ゲームオーバー
        if enemies.contains(where: { !$0.isEscaper && $0.position.y > screenSize.height - 80 }) {
            isGameOver = true
            gameTimer?.invalidate()
            shootTimer?.invalidate()
            SoundManager.shared.stopBGM()
            return
        }

        // 画面外の逃走敵を除去
        enemies.removeAll { $0.isEscaper && ($0.position.x < -30 || $0.position.x > screenSize.width + 30) }

        // ボスのスポーン判定
        let bossThreshold = (lastBossScore / 100 + 1) * 100
        if score >= bossThreshold && bossPosition == nil {
            lastBossScore = score
            bossHP = bossMaxHP
            bossPosition = CGPoint(x: screenSize.width / 2, y: 60)
        }

        // ボスの移動（左右往復しながら降下）
        if var pos = bossPosition {
            pos.x += bossDirection
            pos.y += 0.3
            if pos.x <= 40 || pos.x >= screenSize.width - 40 {
                bossDirection *= -1
            }
            if pos.y > screenSize.height - 80 {
                isGameOver = true
                gameTimer?.invalidate()
                shootTimer?.invalidate()
                SoundManager.shared.stopBGM()
                return
            }
            bossPosition = pos
        }

        // 衝突判定
        var hitEnemyIDs = Set<UUID>()
        var reflectedBullets = [UUID: CGFloat]()
        for bullet in bullets {
            // ボスとの衝突
            if let bPos = bossPosition,
               abs(bullet.position.x - bPos.x) < 40
                && abs(bullet.position.y - bPos.y) < 30 {
                let offsetX = (bullet.position.x - bPos.x) / 40
                reflectedBullets[bullet.id] = offsetX * 6
                bossHP -= 1
                if bossHP <= 0 {
                    bossPosition = nil
                    score += 10
                    SoundManager.shared.playBossDefeat()
                } else {
                    SoundManager.shared.playBossHit()
                }
                continue
            }
            for enemy in enemies {
                if abs(bullet.position.x - enemy.position.x) < 28
                    && abs(bullet.position.y - enemy.position.y) < 24 {
                    hitEnemyIDs.insert(enemy.id)
                    let offsetX = (bullet.position.x - enemy.position.x) / 28
                    reflectedBullets[bullet.id] = offsetX * 6
                    score += 1
                    if enemy.isPurple {
                        bombCount += 1
                        SoundManager.shared.playPowerUp()
                    } else if enemy.isGolden {
                        bulletCount = min(bulletCount + 1, 5)
                        SoundManager.shared.playPowerUp()
                    } else {
                        SoundManager.shared.playHit()
                    }
                }
            }
        }
        enemies = enemies.filter { !hitEnemyIDs.contains($0.id) }
        bullets = bullets.map { bullet in
            if let vx = reflectedBullets[bullet.id] {
                var b = bullet
                b.velocityX = vx
                b.velocityY = 8
                return b
            }
            return bullet
        }
    }

    private func spawnEnemy() {
        guard !isGameOver else { return }
        let x = CGFloat.random(in: 30...(screenSize.width - 30))

        let roll = Int.random(in: 0..<20)
        if roll == 0 {
            let dir: CGFloat = Bool.random() ? 3.0 : -3.0
            var enemy = GameObject(position: CGPoint(x: x, y: 30))
            enemy.enemyType = .purple(direction: dir)
            enemies.append(enemy)
        } else if roll == 1 {
            let dir: CGFloat = Bool.random() ? 3.5 : -3.5
            var enemy = GameObject(position: CGPoint(x: x, y: 30))
            enemy.enemyType = .golden(direction: dir)
            enemies.append(enemy)
        } else {
            enemies.append(GameObject(position: CGPoint(x: x, y: 30)))
        }
    }

    func useBomb() {
        guard !isGameOver, bombCount > 0 else { return }
        bombCount -= 1
        SoundManager.shared.playBomb()
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
        SoundManager.shared.playShoot()
        let playerY = screenSize.height - 70
        let spread: CGFloat = 12
        let totalWidth = spread * CGFloat(bulletCount - 1)
        let startX = playerX - totalWidth / 2
        for i in 0..<bulletCount {
            let x = startX + spread * CGFloat(i)
            bullets.append(GameObject(position: CGPoint(x: x, y: playerY - 24)))
        }
    }
}

// MARK: - サウンド

class SoundManager {
    static let shared = SoundManager()

    private var bgmPlayer: AVAudioPlayer?
    private var sePlayers: [String: AVAudioPlayer] = [:]

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
    }

    private func playSE(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            sePlayers[name] = player
        } catch {}
    }

    func startBGM() {
        guard bgmPlayer == nil || bgmPlayer?.isPlaying == false,
              let url = Bundle.main.url(forResource: "bgm", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.4
            player.play()
            bgmPlayer = player
        } catch {}
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    func stopAllSE() {
        for player in sePlayers.values {
            player.stop()
        }
        sePlayers.removeAll()
    }

    func playShoot() { playSE("shoot") }
    func playHit() { playSE("hit") }
    func playBossHit() { playSE("boss_hit") }
    func playBossDefeat() { playSE("boss_defeat") }
    func playBomb() { playSE("bomb") }
    func playPowerUp() { playSE("powerup") }
    func playGameOver() { playSE("gameover") }
    func playStart() { playSE("start") }
}

#Preview {
    ContentView()
}
