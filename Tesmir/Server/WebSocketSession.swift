import Foundation
import Network
import CryptoKit

class WebSocketSession {
    let id: UUID
    var onClose: (() -> Void)?
    private let connection: NWConnection
    private var isClosed = false
    private let sendQueue = DispatchQueue(label: "com.tesmir.websocket.send")

    init(connection: NWConnection, id: UUID) {
        self.connection = connection
        self.id = id
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.handleClose()
            default: break
            }
        }
    }

    func sendHandshake(key: String) {
        let acceptKey = computeAcceptKey(key: key)
        let response = ["HTTP/1.1 101 Switching Protocols","Upgrade: websocket","Connection: Upgrade","Sec-WebSocket-Accept: \(acceptKey)","",""].joined(separator: "\r\n")
        connection.send(content: response.data(using: .utf8), completion: .idempotent)
    }

    func sendFrame(_ data: Data) {
        guard !isClosed else { return }
        sendQueue.async { [weak self] in
            guard let self, !self.isClosed else { return }
            self.connection.send(content: self.encodeWebSocketFrame(data: data, opcode: 0x02), completion: .idempotent)
        }
    }

    func startReceiving() { receiveNextFrame() }

    private func receiveNextFrame() {
        guard !isClosed else { return }
        connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil || isComplete || data == nil { self.handleClose(); return }
            if let data { self.processReceivedFrame(data) }
            self.receiveNextFrame()
        }
    }

    private func processReceivedFrame(_ data: Data) {
        guard data.count >= 2 else { return }
        switch data[0] & 0x0F {
        case 0x08: handleClose()
        case 0x09: connection.send(content: encodeWebSocketFrame(data: Data(), opcode: 0x0A), completion: .idempotent)
        default: break
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.send(content: encodeWebSocketFrame(data: Data(), opcode: 0x08), completion: .contentProcessed { [weak self] _ in self?.connection.cancel() })
    }

    private func handleClose() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        onClose?()
    }

    private func encodeWebSocketFrame(data: Data, opcode: UInt8) -> Data {
        var frame = Data()
        frame.append(0x80 | opcode)
        let len = data.count
        if len <= 125 { frame.append(UInt8(len)) }
        else if len <= 65535 { frame.append(126); frame.append(UInt8((len >> 8) & 0xFF)); frame.append(UInt8(len & 0xFF)) }
        else { frame.append(127); for i in stride(from: 56, through: 0, by: -8) { frame.append(UInt8((len >> i) & 0xFF)) } }
        frame.append(contentsOf: data)
        return frame
    }

    private func computeAcceptKey(key: String) -> String {
        let combined = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data(combined.utf8))
        return Data(digest).base64EncodedString()
    }
}
