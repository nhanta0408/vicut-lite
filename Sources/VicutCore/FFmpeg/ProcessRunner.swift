import Foundation

public struct ProcessResult: Sendable {
  public let exitCode: Int32
  public let stdout: Data
  public let stderrTail: [String]
}

/// Thin async wrapper over `Process`. Cancelling the calling Task terminates the child process.
public enum ProcessRunner {
  static let stderrTailLimit = 30

  public static func run(
    executable: URL,
    arguments: [String],
    onStdoutLine: (@Sendable (String) -> Void)? = nil
  ) async throws -> ProcessResult {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.standardInput = FileHandle.nullDevice

    let stdoutCollector = OutputCollector(onLine: onStdoutLine, keepAll: true)
    let stderrCollector = OutputCollector(onLine: nil, keepAll: false)
    stdoutPipe.fileHandleForReading.readabilityHandler = { stdoutCollector.append($0.availableData) }
    stderrPipe.fileHandleForReading.readabilityHandler = { stderrCollector.append($0.availableData) }

    let handle = ProcessHandle(process)
    let exitCode: Int32 = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        process.terminationHandler = { finished in
          continuation.resume(returning: finished.terminationStatus)
        }
        do {
          try process.run()
        } catch {
          process.terminationHandler = nil
          continuation.resume(throwing: error)
        }
      }
    } onCancel: {
      handle.terminate()
    }

    stdoutPipe.fileHandleForReading.readabilityHandler = nil
    stderrPipe.fileHandleForReading.readabilityHandler = nil
    stdoutCollector.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
    stderrCollector.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
    stdoutCollector.flush()
    stderrCollector.flush()

    try Task.checkCancellation()
    return ProcessResult(
      exitCode: exitCode,
      stdout: stdoutCollector.allData,
      stderrTail: stderrCollector.tail(stderrTailLimit)
    )
  }
}

private final class ProcessHandle: @unchecked Sendable {
  private let process: Process

  init(_ process: Process) {
    self.process = process
  }

  func terminate() {
    if process.isRunning {
      process.terminate()
    }
  }
}

/// Thread-safe line splitter; pipe handlers fire on arbitrary queues.
private final class OutputCollector: @unchecked Sendable {
  private let lock = NSLock()
  private let onLine: (@Sendable (String) -> Void)?
  private let keepAll: Bool
  private var buffer = Data()
  private var all = Data()
  private var lines: [String] = []

  init(onLine: (@Sendable (String) -> Void)?, keepAll: Bool) {
    self.onLine = onLine
    self.keepAll = keepAll
  }

  func append(_ data: Data) {
    guard !data.isEmpty else { return }
    lock.lock()
    if keepAll { all.append(data) }
    buffer.append(data)
    var emitted: [String] = []
    while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
      let lineData = buffer[buffer.startIndex..<newline]
      buffer.removeSubrange(buffer.startIndex...newline)
      emitted.append(String(decoding: lineData, as: UTF8.self))
    }
    record(emitted)
    lock.unlock()
    emitted.forEach { onLine?($0) }
  }

  func flush() {
    lock.lock()
    var emitted: [String] = []
    if !buffer.isEmpty {
      emitted.append(String(decoding: buffer, as: UTF8.self))
      buffer.removeAll()
    }
    record(emitted)
    lock.unlock()
    emitted.forEach { onLine?($0) }
  }

  var allData: Data {
    lock.lock()
    defer { lock.unlock() }
    return all
  }

  func tail(_ count: Int) -> [String] {
    lock.lock()
    defer { lock.unlock() }
    return Array(lines.suffix(count))
  }

  private func record(_ emitted: [String]) {
    lines.append(contentsOf: emitted.filter { !$0.isEmpty })
    if lines.count > ProcessRunner.stderrTailLimit * 4 {
      lines.removeFirst(lines.count - ProcessRunner.stderrTailLimit)
    }
  }
}
