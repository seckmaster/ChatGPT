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

func parseMarkdown(
  _ markdown: String,
  allowsExtendedAttributes: Bool = false,
  interpretedSyntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax = .inlineOnlyPreservingWhitespace,
  failurePolicy: AttributedString.MarkdownParsingOptions.FailurePolicy = .returnPartiallyParsedIfPossible,
  primaryForegroundColor: Color? = nil
) -> AttributedString {
  do {
    var attributedString = try AttributedString(
      markdown: markdown, 
      options: .init(
        allowsExtendedAttributes: allowsExtendedAttributes, 
        interpretedSyntax: interpretedSyntax, 
        failurePolicy: failurePolicy
      )
    )
    
    var globalContainer = AttributeContainer()
    globalContainer.font = .systemFont(ofSize: 14)
    if let color = primaryForegroundColor {
      globalContainer.foregroundColor = color
    }
    attributedString.mergeAttributes(globalContainer, mergePolicy: .keepNew)
    
    markdown.ranges(of: /###(.+?)\n/).forEach {
      let range1 = attributedString.range(of: markdown[$0])!
      let range2 = attributedString.range(of: markdown[$0].dropFirst(4))!
      var container = AttributeContainer()
      container.font = .heading3
      attributedString.replaceSubrange(
        range1, 
        with: attributedString[range2].settingAttributes(container)
      )
    }
    markdown.ranges(of: /##(.+?)\n/).forEach {
      guard let range1 = attributedString.range(of: markdown[$0]) else { return } 
      let range2 = attributedString.range(of: markdown[$0].dropFirst(3))!
      var container = AttributeContainer()
      container.font = .heading2
      attributedString.replaceSubrange(
        range1, 
        with: attributedString[range2].settingAttributes(container)
      )
    }
    markdown.ranges(of: /#(.+?)\n/).forEach {
      guard let range1 = attributedString.range(of: markdown[$0]) else { return } 
      let range2 = attributedString.range(of: markdown[$0].dropFirst(2))!
      var container = AttributeContainer()
      container.font = .heading1
      //      let paragraphStyle = NSMutableParagraphStyle()
      //      paragraphStyle.paragraphSpacing = 40
      //      paragraphStyle.lineSpacing = 40
      //      paragraphStyle.headIndent = 100
      //      container.paragraphStyle = paragraphStyle
      attributedString.replaceSubrange(
        range1, 
        with: attributedString[range2].settingAttributes(container)
      )
    }
    return attributedString
  } catch {
    return .init(markdown)
  }
}

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

func chatToAttributedString(
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
      substr = AttributedString(message.content + "\n" + "\n")
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
        substr = AttributedString(message.content + "\n" + "\n")
        substr.setAttributes(container)
        string.append(substr)
      } else {
        var lowerBound = message.content.startIndex
        
        for match in message.content.matches(of: regex) {
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
            attributedString.addAttribute(
              .backgroundColor, 
              value: NSColor.black, 
              range: .init(location: 0, length: attributedString.string.utf8.count)
            )
            
            let beforeRange = lowerBound..<match.range.lowerBound
            container = AttributeContainer()
            container.foregroundColor = .white
            container.font = .systemFont(ofSize: 14)
            substr = AttributedString(message.content[beforeRange])
            substr.setAttributes(container)
            string.append(substr)
            string.append(AttributedString(attributedString))
            lowerBound = match.range.upperBound
          } catch {
            continue
          }
        }
        if lowerBound < message.content.endIndex {
          container = AttributeContainer()
          container.foregroundColor = .white
          container.font = .systemFont(ofSize: 14)
          substr = AttributedString(message.content[lowerBound..<message.content.endIndex])
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
      substr = AttributedString(message.content + "\n" + "\n")
      substr.setAttributes(container)
      string.append(substr)
    case .custom("error"):
      var container = AttributeContainer()
      container.foregroundColor = .orange
      container.font = .boldSystemFont(ofSize: 14)
      var substr = AttributedString("⦿  Error\n\n")
      substr.setAttributes(container)
      string.append(substr)
      
      container = AttributeContainer()
      container.foregroundColor = .red
      container.font = .systemFont(ofSize: 12)
      substr = AttributedString(message.content + "\n" + "\n")
      substr.setAttributes(container)
      string.append(substr)
    case _:
      fatalError()
    }
  }
  return string
}

func codeToHtml(code: String, url: URL) async throws -> String {
  if let html = lock.withLock({ syntaxHighlightingCache[code] }) {
    print("From cache ...")
    return html
  }
  try code.data(using: .utf8)!.write(to: url)
  let html = try await executeCommand(
    executable: .init(filePath: "/opt/homebrew/bin/pygmentize"),
    arguments: [
      "-O",
      "full,style=monokai,lineos=1",
      "-f",
      "html",
      "/" + url.pathComponents.dropFirst().joined(separator: "/")
    ]
  )
  try FileManager.default.removeItem(at: url)
  lock.withLock {
    syntaxHighlightingCache[code] = html
  }
  return html
}

func messageToAttributedString(
  _ message: ChatOpenAILLM.Message
) async -> AttributedString {
  await chatToAttributedString([message])
}

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
  
  if #available(macOS 10.13, *) {
    do {
      try process.run()
    } catch {
      throw error
    }
  } else {
    process.launch()
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
