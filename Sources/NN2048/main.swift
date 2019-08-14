import Foundation
import Kitura

let router = Router()
router.all("/", middleware: StaticFileServer())

router.get("/analyze") { request, response, next in
    let boardReceived = request.queryParameters["board"]!.components(separatedBy: ",").map({ Int($0)! })
    let shapedBoard = (0..<4).map({ row in (0..<4).map({ col in boardReceived[4 * col + row] }) })
    let game = Game2048(board: shapedBoard)
    response.send(monteCarloSearch(state: game).string)
    next()
}

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
