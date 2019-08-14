import Foundation

extension String {
    func paddedZeros(length: Int) -> String {
        if count == length {
            return self
        }
        return ([Character](repeating: "0", count: length - count) + Array(self)).map({ String($0) }).joined()
    }
}

extension Int {
    func paddedString() -> String {
        var str = Array(String(self == 0 ? 0 : (1 << self))).map({ String($0) })
        str = [String](repeating: " ", count: 4 - str.count) + str
        return str.joined()
    }
}

typealias Board = UInt64
typealias Row = UInt16

let ROW1: UInt64 = 0xFFFF000000000000
let ROW2: UInt64 = 0xFFFF00000000
let ROW3: UInt64 = 0xFFFF0000
let ROW4: UInt64 = 0xFFFF

struct Utils2048 {
    var rowLeftTable: [Row: Row]
    var rowRightTable: [Row: Row]
    var scoreTable: [Row: Double]
    var randomTileTable: [Row: [Row]]

    static var shared = Utils2048()
    
    init() {
        rowLeftTable = [:]
        rowRightTable = [:]
        scoreTable = [:]
        randomTileTable = [:]
        initializeTables()
    }
    
    mutating func initializeTables() {
        print("Initializing tables...")
        for row in 0..<UInt16.max {
            var line = [(row & 0xF000) >> 12,
                        (row & 0xF00) >> 8,
                        (row & 0xF0) >> 4,
                        (row & 0xF) >> 0]
            
            var newLines: [[UInt16]] = []
            for i in 0..<4 {
                if line[i] == 0 {
                    for _ in 1...9 {
                        newLines.append(line)
                        newLines[newLines.count - 1][i] = 1
                    }
                    newLines.append(line)
                    newLines[newLines.count - 1][i] = 2
                }
            }
            randomTileTable[row] = newLines.map({ Utils2048.row(line: $0) })
            
            let scoreValues = line.map { v -> UInt in
                let v = UInt(v)
                return v == 0 ? 0 : ((1 << v) * (v - 1))
            }
            scoreTable[row] = Double(scoreValues.reduce(0, +))
            
            var newLine: [UInt16] = [0, 0, 0, 0]
            var j = 0
            var previous: UInt16? = nil
            for i in 0..<4 {
                if line[i] != 0 {
                    if previous == nil {
                        previous = line[i]
                    } else {
                        if previous == line[i] {
                            newLine[j] = line[i] + 1
                            j += 1
                            previous = nil
                        } else {
                            newLine[j] = previous!
                            j += 1
                            previous = line[i]
                        }
                    }
                }
            }
            if previous != nil {
                newLine[j] = previous!
            }
            line = newLine
            
            var row = row
            var result = (line[0] << 12) | (line[1] << 8) | (line[2] << 4) | (line[3] << 0)
            
            rowLeftTable[row] = result
            Utils2048.reverse(row: &result)
            Utils2048.reverse(row: &row)
            rowRightTable[row] = result
        }
    }
    
    static func reverse(row: inout Row) {
        row = (row >> 12) | ((row >> 4) & 0x00F0) | ((row << 4) & 0x0F00) | (row << 12)
    }
    
    static func line(row: Row) -> [Row] {
        let line = [(row & 0xF000) >> 12,
                    (row & 0xF00) >> 8,
                    (row & 0xF0) >> 4,
                    (row & 0xF) >> 0]
        return line
    }
    
    static func row(line: [UInt16]) -> Row {
        return (line[0] << 12) | (line[1] << 8) | (line[2] << 4) | (line[3] << 0)
    }
    
    static func rows(board: Board) -> [Row] {
        let rows = [
            Row(board >> 48),
            Row((board >> 32) & 0xFFFF),
            Row((board >> 16) & 0xFFFF),
            Row((board >>  0) & 0xFFFF)
        ]
        return rows
    }
    
    static func lines(board: Board) -> [[Row]] {
        let lines = rows(board: board).map({ line(row: $0) })
        return lines
    }
    
    static func board(rows: [Row]) -> Board {
        let rows = rows.map({ UInt64($0) })
        return (rows[0] << 48) | (rows[1] << 32) | (rows[2] << 16) | (rows[3] << 0)
    }
    
    static func transpose(board x: inout Board) {
        let a1 = x & 0xF0F00F0FF0F00F0F
        let a2 = x & 0x0000F0F00000F0F0
        let a3 = x & 0x0F0F00000F0F0000
        let a = a1 | (a2 << 12) | (a3 >> 12)
        let b1 = a & 0xFF00FF0000FF00FF
        let b2 = a & 0x00FF00FF00000000
        let b3 = a & 0x00000000FF00FF00
        x = b1 | (b2 >> 24) | (b3 << 24)
    }
    
    static func emptyTiles(board x: Board) -> Int {
        guard x != 0 else {
            return 16
        }
        var x = x
        x |= (x >> 2) & 0x3333333333333333
        x |= (x >> 1)
        x = ~x & 0x1111111111111111
        x += x >> 32
        x += x >> 16
        x += x >>  8
        x += x >>  4
        return Int(x & 0xf)
    }
    
    static func insertRandomTile(board: Board) -> Board {
        var boardRows = rows(board: board)
        let randomRowChange = boardRows.enumerated()
                                       .map({ ($0.offset, Utils2048.shared.randomTileTable[$0.element]!) })
                                       .filter({ !$0.1.isEmpty }).randomElement()!
        boardRows[randomRowChange.0] = randomRowChange.1.randomElement()!
        return Utils2048.board(rows: boardRows)
    }
    
    static func printBoard(board: Board) {
        let board = lines(board: board)
        for r in 0..<4 {
            for c in 0..<4 {
                let powerVal = board[r][c]
                print(powerVal == 0 ? 0 : (1 << powerVal), terminator: "|")
            }
            print("")
        }
        print("")
    }
}

struct Game2048 {
    var board: Board
    
    var score: Double {
        let baseScore = Utils2048.rows(board: board).map({ Utils2048.shared.scoreTable[$0]! }).reduce(0, +)
        return baseScore
    }
    
    var validDirections: [Direction] {
        var dirs: [Direction] = []
        if moved(direction: .up).board != board { dirs.append(.up) }
        if moved(direction: .down).board != board { dirs.append(.down) }
        if moved(direction: .left).board != board { dirs.append(.left) }
        if moved(direction: .right).board != board { dirs.append(.right) }
        return dirs
    }

    var gameWon: Bool {
        return score >= (2048 * 10)
    }
    
    var gameOver: Bool {
        return gameWon || (Utils2048.emptyTiles(board: board) == 0 && validDirections.count == 0)
    }
    
    enum Direction {
        case up, down, left, right

        var string: String {
            switch self {
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            }
        }
    }
    
    private mutating func moveHorizontal(lookup: [Row: Row]) {
        let row1 = Board(lookup[Row((board & ROW1) >> 48)]!)
        let row2 = Board(lookup[Row((board & ROW2) >> 32)]!)
        let row3 = Board(lookup[Row((board & ROW3) >> 16)]!)
        let row4 = Board(lookup[Row((board & ROW4) >>  0)]!)
        board = (row1 << 48) | (row2 << 32) | (row3 << 16) | (row4 << 0)
    }
    
    private mutating func moveVertical(lookup: [Row: Row]) {
        Utils2048.transpose(board: &board)
        moveHorizontal(lookup: lookup)
        Utils2048.transpose(board: &board)
    }
    
    mutating func moveLeft() {
        moveHorizontal(lookup: Utils2048.shared.rowLeftTable)
    }
    
    mutating func moveRight() {
        moveHorizontal(lookup: Utils2048.shared.rowRightTable)
    }
    
    mutating func moveUp() {
        moveVertical(lookup: Utils2048.shared.rowLeftTable)
    }
    
    mutating func moveDown() {
        moveVertical(lookup: Utils2048.shared.rowRightTable)
    }
    
    mutating func move(direction: Direction) {
        switch direction {
        case .up:
            moveUp()
        case .down:
            moveDown()
        case .left:
            moveLeft()
        case .right:
            moveRight()
        }
    }
    
    func moved(direction: Direction) -> Game2048 {
        var new = copy()
        new.move(direction: direction)
        return new
    }
    
    mutating func play(direction: Direction) {
        move(direction: direction)
        board = Utils2048.insertRandomTile(board: board)
    }
    
    func print() {
        let board = Utils2048.lines(board: self.board).map({ $0.map({ Int($0) }) })
        var temp = ""
        temp += [String](repeating: "-", count: "|    |    |    |    |".count).joined()
        temp += "\n"
        temp += "|\(board[0][0].paddedString())|\(board[0][1].paddedString())|\(board[0][2].paddedString())|\(board[0][3].paddedString())|"
        temp += "\n"
        temp += [String](repeating: "-", count: "|    |    |    |    |".count).joined()
        temp += "\n"
        temp += "|\(board[1][0].paddedString())|\(board[1][1].paddedString())|\(board[1][2].paddedString())|\(board[1][3].paddedString())|"
        temp += "\n"
        temp += [String](repeating: "-", count: "|    |    |    |    |".count).joined()
        temp += "\n"
        temp += "|\(board[2][0].paddedString())|\(board[2][1].paddedString())|\(board[2][2].paddedString())|\(board[2][3].paddedString())|"
        temp += "\n"
        temp += [String](repeating: "-", count: "|    |    |    |    |".count).joined()
        temp += "\n"
        temp += "|\(board[3][0].paddedString())|\(board[3][1].paddedString())|\(board[3][2].paddedString())|\(board[3][3].paddedString())|"
        temp += "\n"
        temp += [String](repeating: "-", count: "|    |    |    |    |".count).joined()
        temp += "\n"
        Swift.print(temp)
    }
    
    func copy() -> Game2048 {
        return Game2048(board: board)
    }
    
    func possibleNextSteps() -> [Game2048] {
        var nextSteps: [Game2048] = []
        var push = 0
        for _ in 1...16 {
            if (board >> push) & 0xf == 0 {
                nextSteps.append(Game2048(board: board | Board([1, 1, 1, 1, 1, 1, 1, 1, 1, 2].randomElement()! << push)))
            }
            push += 4
        }
        return nextSteps
    }
}

extension Game2048 {
    init() {
        board = Utils2048.insertRandomTile(board: Utils2048.insertRandomTile(board: 0))
    }

    init(board: [[Int]]) {
        let str = board.flatMap({ $0 }).map({ $0 == 0 ? "0000" : String(Int(log(Float($0)) / log(2)), radix: 2).paddedZeros(length: 4) }).joined()
        self.board = Board(str, radix: 2)!
    }
}

func monteCarloSearch(state: Game2048) -> Game2048.Direction {
    func performRollout(state: Game2048, direction: Game2048.Direction) -> Double {
        var newState = state.copy()
        newState.play(direction: direction)
/*        if newState.gameWon {
            return .infinity
        }*/
        while !newState.gameOver {
            newState.play(direction: newState.validDirections.randomElement()!)
        }
        return newState.score
    }

    let directions = state.validDirections

    if directions.count == 1 {
        return directions[0]
    }

    let maxTime = 0.03
    var scoreUp = 0.0
    var scoreDown = 0.0
    var scoreLeft = 0.0
    var scoreRight = 0.0

    DispatchQueue.concurrentPerform(iterations: directions.count) { dirIndex in
        let direction = directions[dirIndex]
        var scores: [Double] = []
        var rollouts = 0
        let timeBarrier = DispatchTime.now() + maxTime
        repeat {
            rollouts += 1
            let score = performRollout(state: state, direction: direction)
            scores.append(score)
        } while DispatchTime.now() <= timeBarrier
        let avgScore = scores.reduce(0, +) / Double(rollouts)
        switch direction {
        case .up:
            scoreUp = avgScore
        case .down:
            scoreDown = avgScore
        case .left:
            scoreLeft = avgScore
        case .right:
            scoreRight = avgScore
        }
    }

    let scoreSums: [Game2048.Direction: Double] = [
        .up: scoreUp,
        .down: scoreDown,
        .left: scoreLeft,
        .right: scoreRight
    ]
    return scoreSums.max(by: { a, b in a.value < b.value })!.key
}
