//
//  Utils.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI
import SwiftchainOpenAI
import RegexBuilder

let isSyntaxHighlightingEnabled = true
let lock = NSLock()
var syntaxHighlightingCache = [String: String]()
var cachedPygmentsExecutableURL: URL?

extension NSFont {
  var isHeading1: Bool {
    self.pointSize == NSFont.heading1.pointSize
  }
  var isHeading2: Bool {
    self.pointSize == NSFont.heading2.pointSize
  }
  var isHeading3: Bool {
    self.pointSize == NSFont.heading3.pointSize
  }
}

import AppKit
extension NSFont {
  var isBold: Bool {
    NSFontTraitMask(rawValue: UInt(fontDescriptor.symbolicTraits.rawValue)).contains(.boldFontMask)
  }
  var isItalic: Bool {
    NSFontTraitMask(rawValue: UInt(fontDescriptor.symbolicTraits.rawValue)).contains(.italicFontMask)
  }
  var isUnderlined: Bool {
    fatalError()
  }
  
  static var heading1: NSFont { .boldSystemFont(ofSize: 24) }
  static var heading2: NSFont { .boldSystemFont(ofSize: 20) }
  static var heading3: NSFont { .boldSystemFont(ofSize: 16) }
  
  func withTraits(_ traits: [NSFontDescriptor.SymbolicTraits?]) -> NSFont {
    let descriptor = fontDescriptor
      .withSymbolicTraits(NSFontDescriptor.SymbolicTraits(traits.compactMap { $0 }))
    return .init(descriptor: descriptor, size: descriptor.pointSize)!
  }
  
  func withTraits(_ traits: NSFontDescriptor.SymbolicTraits...) -> NSFont {
    let descriptor = fontDescriptor
      .withSymbolicTraits(NSFontDescriptor.SymbolicTraits(traits))
    return .init(descriptor: descriptor, size: descriptor.pointSize)!
  }
  
  func withSize(_ size: CGFloat) -> NSFont {
    let descriptor = fontDescriptor
    return .init(descriptor: descriptor, size: size)!
  }
  
  var traits: NSFontDescriptor.SymbolicTraits {
    fontDescriptor.symbolicTraits
  }
}

func chatToAttributedStringAsync(
  _ chat: [ChatOpenAILLM.Message]
) async -> AttributedString {
  var string = AttributedString()
  for message in chat {
    switch message.role {
    case .system:
      var container = AttributeContainer()
      container.foregroundColor = .red
      container.font = .boldSystemFont(ofSize: 14)
      var substr = AttributedString("⦿  System\n\n")
      substr.setAttributes(container)
      string.append(substr)
      
      container = AttributeContainer()
      container.foregroundColor = .white
      container.font = .systemFont(ofSize: 14)
      substr = AttributedString(message.content!)
      substr.setAttributes(container)
      string.append(substr)
    case .assistant:
      let regex = Regex {
        ChoiceOf {
          "```"
          "'''"
        }
        Capture {
          OneOrMore(.word)
          Anchor.endOfLine
        }
        Capture {
          OneOrMore(.any.subtracting(.anyOf(["'" as Character, "`"])))
        }
        ChoiceOf {
          "```"
          "'''"
        }
      }
      
      var container = AttributeContainer()
      container.foregroundColor = .orange
      container.font = .boldSystemFont(ofSize: 14)
      var substr = AttributedString("⦿  Assistant\n\n")
      substr.setAttributes(container)
      string.append(substr)
      
      if !isSyntaxHighlightingEnabled {
        container = AttributeContainer()
        container.foregroundColor = .white
        container.font = .systemFont(ofSize: 14)
        substr = AttributedString(message.content!)
        substr.setAttributes(container)
        string.append(substr)
      } else {
        var lowerBound = message.content!.startIndex
        
        for match in message.content!.matches(of: regex) {
          do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
              .appending(path: "chat-gpt-tmp-code.\(match.1)")
            let html = try await codeToHtml(code: String(match.output.2), url: url)
            let attributedString = try NSMutableAttributedString(
              data: html.data(using: .utf8)!, 
              options: [
                .documentType: NSAttributedString.DocumentType.html, 
                  .characterEncoding: String.Encoding.utf8.rawValue
              ],
              documentAttributes: nil
            )
            
            let beforeRange = lowerBound..<match.range.lowerBound
            container = AttributeContainer()
            container.foregroundColor = .white
            container.font = .systemFont(ofSize: 14)
            substr = AttributedString(message.content![beforeRange])
            substr.setAttributes(container)
            string.append(substr)
            string.append(AttributedString(attributedString))
            lowerBound = match.range.upperBound
          } catch {
            continue
          }
        }
        if lowerBound < message.content!.endIndex {
          container = AttributeContainer()
          container.foregroundColor = .white
          container.font = .systemFont(ofSize: 14)
          substr = AttributedString(message.content![lowerBound..<message.content!.endIndex])
          substr.setAttributes(container)
          string.append(substr)
        }
      }
    case .user:
      var container = AttributeContainer()
      container.foregroundColor = .magenta
      container.font = .boldSystemFont(ofSize: 14)
      var substr = AttributedString("⦿  User\n\n")
      substr.setAttributes(container)
      string.append(substr)
      
      container = AttributeContainer()
      container.foregroundColor = .white
      container.font = .systemFont(ofSize: 14)
      substr = AttributedString(message.content!)
      substr.setAttributes(container)
      string.append(substr)
    case .custom("error"), .custom("Error"):
      var container = AttributeContainer()
      container.foregroundColor = .orange
      container.font = .boldSystemFont(ofSize: 14)
      var substr = AttributedString("⦿  Error\n\n")
      substr.setAttributes(container)
      string.append(substr)
      
      container = AttributeContainer()
      container.foregroundColor = .red
      container.font = .systemFont(ofSize: 12)
      substr = AttributedString(message.content!)
      substr.setAttributes(container)
      string.append(substr)
    case _:
      fatalError()
    }
  }
  return string
}

func messageToAttributedStringAsync(
  _ message: ChatOpenAILLM.Message
) async -> AttributedString {
  await chatToAttributedStringAsync([message])
}

func messageToAttributedString(
  _ message: ChatOpenAILLM.Message
) -> AttributedString {
  func format(
    message: ChatOpenAILLM.Message,
    color: Color,
    header: String,
    prefix: String = "⦿  "
  ) -> AttributedString {
    var string = AttributedString()
    
    var container = AttributeContainer()
    container.foregroundColor = color
    container.font = .boldSystemFont(ofSize: 14)
    var substr = AttributedString(prefix + header + "\n\n")
    substr.setAttributes(container)
    string.append(substr)
    
    container = AttributeContainer()
    container.foregroundColor = .white
    container.font = .systemFont(ofSize: 14)
    substr = AttributedString(message.content!)
    substr.setAttributes(container)
    string.append(substr)
    return string
  }
  
  switch message.role {
  case .system:
    return format(
      message: message,
      color: .red, 
      header: "System"
    )
  case .assistant:
    return format(
      message: message,
      color: .purple, 
      header: "Assistant"
    )
  case .user:
    return format(
      message: message,
      color: .cyan, 
      header: "User"
    )
  case .custom("error"), .custom("Error"):
    return format(
      message: message,
      color: .orange, 
      header: "Error"
    )
  case _:
    fatalError()
  }
}

func codeToHtml(code: String, url: URL) async throws -> String {
  func fetchPygmentsExecutableURL() async throws -> URL {
//    if let url = lock.withLock({ cachedPygmentsExecutableURL }) { return url }
//    let path = try await executeCommand(
//      executable: .init(filePath: "/usr/bin/which"), 
//      arguments: ["pygmentize"]
//    )
//    let executableUrl = URL(filePath: path)
//    lock.withLock { 
//      cachedPygmentsExecutableURL = executableUrl
//    }
//    return executableUrl
    return .init(filePath: "/opt/homebrew/bin/pygmentize")
  }
  
#if os(macOS)
  if let html = lock.withLock({ syntaxHighlightingCache[code] }) {
    print("From cache ...")
    return html
  }
  try code.data(using: .utf8)!.write(to: url)
  let html = try await executeCommand(
    executable: try await fetchPygmentsExecutableURL(),
    arguments: [
      "-O",
      "full,style=monokai,lineos=1",
      "-l",
      String(url.lastPathComponent.split(separator: ".")[1]),
      "-f",
      "html",
      "/" + url.pathComponents.dropFirst().joined(separator: "/")
    ]
  )
  try FileManager.default.removeItem(at: url)
  lock.withLock {
    syntaxHighlightingCache[code] = html
  }
#else
  let html = code
#endif
  return html
}

#if os(macOS)
func executeCommand(
  executable: URL,
  arguments: [String] = []
) async throws -> String {
  do {
    guard try executable.checkResourceIsReachable() else { 
      throw NSError(domain: "Executable \(executable.absoluteString) is not reachable", code: -1)
    }
  } catch {
    throw error
  }
  
  let process = Process()
  process.executableURL = executable
  process.arguments = arguments
  
  let outputPipe = Pipe()
  let errorPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = errorPipe
  
  do {
    try process.run()
  } catch {
    throw error
  }
  var data = Data()
  for try await byte in outputPipe.fileHandleForReading.bytes {
    data.append(byte)
  }
  process.waitUntilExit()
  
  guard process.terminationStatus == 0 else {
    throw NSError(domain: "termination status", code: 0)
  }
  
  let output = String(
    data: data, 
    encoding: .utf8
  )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  
  return output
}
#else
#endif
