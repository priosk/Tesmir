import Foundation
import Network
import Combine

class StreamingServer: ObservableObject {
    @Published var connectedClients: Int = 0
    @Published var isRunning: Bool = false

    private var listener: NWListener?
    private var webSocketSessions: [UUID: WebSocketSession] = [:]
    private var mjpegSessions: [UUID: MJPEGSession] = [:]
    private let sessionQueue = DispatchQueue(label: "com.tesmir.server.sessions")
    private var latestFrame: Data?

    func start(port: UInt16 = 8080) throws {
        stop()
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw ServerError.invalidPort }
        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in self?.handleNewConnection(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready: self?.isRunning = true
                case .failed, .cancelled: self?.isRunning = false
                default: break
                }
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel(); listener = nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.webSocketSessions.values.forEach { $0.close() }
            self.webSocketSessions.removeAll()
            self.mjpegSessions.values.forEach { $0.close() }
            self.mjpegSessions.removeAll()
            DispatchQueue.main.async { self.connectedClients = 0; self.isRunning = false }
        }
    }

    func broadcastFrame(_ data: Data) {
        latestFrame = data
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.webSocketSessions.values.forEach { $0.sendFrame(data) }
            self.mjpegSessions.values.forEach { $0.sendFrame(data) }
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let id = UUID()
        let rawConn = RawHTTPConnection(connection: connection)
        rawConn.onRequest = { [weak self] request in self?.routeRequest(request, connection: connection, id: id) }
        rawConn.start()
    }

    private func routeRequest(_ request: HTTPRequest, connection: NWConnection, id: UUID) {
        if request.isWebSocketUpgrade {
            let session = WebSocketSession(connection: connection, id: id)
            session.sendHandshake(key: request.webSocketKey ?? "")
            session.onClose = { [weak self] in
                self?.sessionQueue.async {
                    self?.webSocketSessions.removeValue(forKey: id)
                    DispatchQueue.main.async { self?.updateClientCount() }
                }
            }
            sessionQueue.async { [weak self] in
                self?.webSocketSessions[id] = session
                if let frame = self?.latestFrame { session.sendFrame(frame) }
                DispatchQueue.main.async { self?.updateClientCount() }
            }
            session.startReceiving()
        } else if request.path == "/mjpeg" {
            let session = MJPEGSession(connection: connection, id: id)
            session.sendHeaders()
            session.onClose = { [weak self] in
                self?.sessionQueue.async {
                    self?.mjpegSessions.removeValue(forKey: id)
                    DispatchQueue.main.async { self?.updateClientCount() }
                }
            }
            sessionQueue.async { [weak self] in
                self?.mjpegSessions[id] = session
                if let frame = self?.latestFrame { session.sendFrame(frame) }
                DispatchQueue.main.async { self?.updateClientCount() }
            }
        } else {
            let html = HTMLPage.content
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    private func updateClientCount() {
        connectedClients = webSocketSessions.count + mjpegSessions.count
    }
}

enum ServerError: LocalizedError {
    case invalidPort, bindFailed
    var errorDescription: String? {
        switch self {
        case .invalidPort: return "잘못된 포트 번호입니다."
        case .bindFailed: return "서버 포트를 열 수 없습니다."
        }
    }
}

struct HTTPRequest {
    let method: String; let path: String; let headers: [String: String]
    var isWebSocketUpgrade: Bool { headers["Upgrade"]?.lowercased() == "websocket" }
    var webSocketKey: String? { headers["Sec-WebSocket-Key"] }
    static func parse(from data: Data) -> HTTPRequest? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let idx = line.firstIndex(of: ":") ?? line.endIndex
            if idx != line.endIndex {
                headers[String(line[line.startIndex..<idx]).trimmingCharacters(in: .whitespaces)] = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return HTTPRequest(method: parts[0], path: parts[1], headers: headers)
    }
}

class RawHTTPConnection {
    var onRequest: ((HTTPRequest) -> Void)?
    private let connection: NWConnection
    private var buffer = Data()
    init(connection: NWConnection) { self.connection = connection }
    func start() { connection.start(queue: .global(qos: .userInitiated)); receive() }
    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { self.buffer.append(data) }
            if self.buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                if let request = HTTPRequest.parse(from: self.buffer) { self.onRequest?(request) }
                return
            }
            if !isComplete && error == nil { self.receive() }
        }
    }
}

class MJPEGSession {
    let id: UUID; var onClose: (() -> Void)?
    private let connection: NWConnection
    init(connection: NWConnection, id: UUID) {
        self.connection = connection; self.id = id
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.onClose?() }
            if case .cancelled = state { self?.onClose?() }
        }
    }
    func sendHeaders() {
        let h = "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
        connection.send(content: h.data(using: .utf8), completion: .idempotent)
    }
    func sendFrame(_ jpegData: Data) {
        var frame = Data()
        let header = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpegData.count)\r\n\r\n"
        frame.append(header.data(using: .utf8)!)
        frame.append(jpegData)
        frame.append("\r\n".data(using: .utf8)!)
        connection.send(content: frame, completion: .idempotent)
    }
    func close() { connection.cancel() }
}
