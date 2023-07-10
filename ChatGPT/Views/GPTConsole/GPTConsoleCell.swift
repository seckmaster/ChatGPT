//
//  GPTConsoleCell.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import Foundation
import SwiftUI
import SwiftchainOpenAI

struct GPTConsoleCell: View {
  @ObservedObject var viewModel: ViewModel
  @State var background: Color = Color.palette.background1
  @State var isHovering = false
  @State var delegate: TextViewDelegate<ViewModel>?
  
  init(
    message: Message, 
    isSyntaxHighlightingEnabled: Binding<Bool>,
    isStreamingText: Binding<Bool>,
    didUpdateMessage: @escaping (String) -> Void
  ) {
    self.viewModel = .init(
      message: message,
      isSyntaxHighlightingEnabled: isSyntaxHighlightingEnabled,
      isStreamingText: isStreamingText,
      didUpdateMessage: didUpdateMessage
    )
    self._delegate = .init(initialValue: .init(viewModel: viewModel))
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 17) {
      HStack {
        Text(viewModel.header)
        Spacer()
      }
      .padding(.top)
      ZStack {
        Text(viewModel.text)
        TextView<ViewModel>(text: $viewModel.text, delegate: delegate)
          .frame(maxWidth: .infinity)
          .background(background)
      }
      .padding([.top, .bottom])
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(background)
    .onHover { over in
      background = over ? .palette.background2 : .palette.background1
      isHovering = over
    }
    .onChange(of: viewModel.text) { newValue in
      viewModel.performSyntaxHighlighting()
    }
  }
}

extension GPTConsoleCell {
  struct Message: Identifiable {
    let id: Int
    var message: ChatOpenAILLM.Message
  }
  
  class ViewModel: EditingViewModel {
    @Published var isBoldHighlighted: Bool = false
    @Published var isItalicHighlighted: Bool = false
    @Published var isUnderlineHighlighted: Bool = false
    @Published var isHeading1: Bool = false
    @Published var isHeading2: Bool = false
    @Published var isHeading3: Bool = false
    @Published var selectedRanges: [NSRange] = []
    @Published var text: AttributedString
    @Published var header: AttributedString
    @Binding var isSyntaxHighlightingEnabled: Bool
    @Binding var isStreamingText: Bool
    let didUpdateMessage: (String) -> Void
    
    init(
      message: Message,
      isSyntaxHighlightingEnabled: Binding<Bool>,
      isStreamingText: Binding<Bool>,
      didUpdateMessage: @escaping (String) -> Void
    ) {
      self.header = headerFromMessage(message.message)
      self._isSyntaxHighlightingEnabled = isSyntaxHighlightingEnabled
      self._isStreamingText = isStreamingText
      var container = AttributeContainer()
      container.foregroundColor = NSColor.white
      container.font = .systemFont(ofSize: 14)
      self.text = AttributedString(message.message.content!, attributes: container)
      self.didUpdateMessage = didUpdateMessage
      Task {
        await self.performSyntaxHighlighting()
      }
    }
    
    func update() {
      didUpdateMessage(String(text.characters[...]))
    }
    
    @MainActor
    func performSyntaxHighlighting() {
      guard isSyntaxHighlightingEnabled, !isStreamingText else { return }
      let content = text.characters[...]
      
      Task { @MainActor in
        let content = String(content)
        
        var highlightedBlocks = [HighlightedCodeBlock]()
        for block in parseCodeBlocks(from: content) {
          let highlightedBlock = try await highlightCodeBlock(
            string: content,
            block: block
          )
          highlightedBlocks.append(highlightedBlock)
        }
        
        guard !highlightedBlocks.isEmpty else { return }
        
        var lowerBound = content.startIndex
        var container = AttributeContainer()
        var string = AttributedString()
        
        for block in highlightedBlocks {
          do {
            let attributedString = try NSMutableAttributedString(
              data: block.html.data(using: .utf8)!, 
              options: [
                .documentType: NSAttributedString.DocumentType.html, 
                  .characterEncoding: String.Encoding.utf8.rawValue
              ],
              documentAttributes: nil
            )
            
            let match = block.block.range
            let beforeRange = lowerBound..<match.lowerBound
            container = AttributeContainer()
            container.foregroundColor = NSColor.white
            container.font = .systemFont(ofSize: 14)
            var substr = AttributedString(content[beforeRange])
            substr.setAttributes(container)
            string.append(substr)
            string.append(AttributedString(attributedString))
            lowerBound = match.upperBound
          } catch {
            continue
          }
        }
        if lowerBound < content.endIndex {
          container = AttributeContainer()
          container.foregroundColor = NSColor.white
          container.font = .systemFont(ofSize: 14)
          var substr = AttributedString(content[lowerBound..<content.endIndex])
          substr.setAttributes(container)
          string.append(substr)
        }
        
        self.text = string
      }
    }
  }
}

extension AttributedString: @unchecked Sendable {}

extension AttributedString {
  func height(availableWidth: CGFloat) -> CGFloat {
    NSAttributedString(self).boundingRect(
      with: .init(
        width: availableWidth, 
        height: .greatestFiniteMagnitude
      ),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    .height
  }
}
