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
  @State var delegate: TextViewDelegate<ViewModel>!
  private var isEditing: Bool
  var didStopEditing: (String) -> Void
  var requestStartEdit: () -> Void
  
  init(
    message: Message, 
    isEditing: Bool,
    isSyntaxHighlightingEnabled: Binding<Bool>,
    isStreamingText: Binding<Bool>,
    didStopEditing: @escaping (String) -> Void,
    requestStartEdit: @escaping () -> Void
  ) {
    self.viewModel = .init(
      message: message,
      isSyntaxHighlightingEnabled: isSyntaxHighlightingEnabled,
      isStreamingText: isStreamingText
    )
    self.isEditing = isEditing
    self.didStopEditing = didStopEditing
    self.requestStartEdit = requestStartEdit
  }
  
  var body: some View {
    ZStack {
      ZStack {
        Text(viewModel.viewingText)
          .onTapGesture {
            beginEditing()
          }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .opacity(isEditing ? 0 : 1)
        VStack(alignment: .leading, spacing: 17) {
          Text(viewModel.header)
          TextView<ViewModel>(text: $viewModel.text, delegate: delegate)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .opacity(isEditing ? 1 : 0)
        .frame(maxWidth: .infinity)
      }
      .padding()
      .background(background)
      .onHover { over in
        background = over ? .palette.background2 : .palette.background1
        isHovering = over
      }
      HStack {
        Spacer()
        VStack {
          if isEditing {
            Button {
              viewModel.updateText()
              didStopEditing(.init(viewModel.text.characters))
            } label: {
              Image(systemName: "checkmark.rectangle.fill")
                .frame(width: 40, height: 40)
            }
            .background(Color.palette.background)
            .buttonStyle(.borderless)
          } else if isHovering {
            Button {
              beginEditing()
            } label: {
              Image(systemName: "pencil")
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.borderless)
            .background(Color.palette.background)
            .onHover { over in
              isHovering = isHovering || over
            }
          }
          Spacer()
        }
      }
    }
    .onChange(of: isEditing) { isEditing in
      if !isEditing {
        didStopEditing(.init(viewModel.text.characters))
      }
    }
  }
  
  func beginEditing() {
    delegate = .init(viewModel: viewModel)
    requestStartEdit()
  }
}

extension GPTConsoleCell {
  struct Message: Identifiable {
    let id: Int
    var message: ChatOpenAILLM.Message
  }
  
  class ViewModel: EditingViewModel {
    var message: Message
    
    @Published var isBoldHighlighted: Bool = false
    @Published var isItalicHighlighted: Bool = false
    @Published var isUnderlineHighlighted: Bool = false
    @Published var isHeading1: Bool = false
    @Published var isHeading2: Bool = false
    @Published var isHeading3: Bool = false
    @Published var selectedRanges: [NSRange] = []
    @Published var viewingText: AttributedString
    @Published var text: AttributedString
    @Published var header: AttributedString
    @Binding var isSyntaxHighlightingEnabled: Bool
    @Binding var isStreamingText: Bool
    
    init(
      message: Message,
      isSyntaxHighlightingEnabled: Binding<Bool>,
      isStreamingText: Binding<Bool>
    ) {
      self.message = message
      self.header = headerFromMessage(message.message)
      self._isSyntaxHighlightingEnabled = isSyntaxHighlightingEnabled
      self._isStreamingText = isStreamingText
      var container = AttributeContainer()
      container.foregroundColor = .white
      container.font = .systemFont(ofSize: 14)
      self.text = AttributedString(message.message.content!, attributes: container)
      self.viewingText = messageToAttributedString(message.message)
      Task {
        await self.updateViewingText()
      }
    }
    
    func updateDocument() {
    }
    
    @MainActor
    func updateText() {
      message.message = .init(
        role: message.message.role,
        content: .init(text.characters[...])
      )
      updateViewingText()
    }
    
    @MainActor
    func updateViewingText() {
      self.viewingText = messageToAttributedString(message.message)
      guard isSyntaxHighlightingEnabled, !isStreamingText else { return }
      
      Task { @MainActor in
        var highlightedBlocks = [HighlightedCodeBlock]()
        for block in parseCodeBlocks(from: self.message.message.content ?? "") {
          let highlightedBlock = try await highlightCodeBlock(
            string: self.message.message.content ?? "", 
            block: block
          )
          highlightedBlocks.append(highlightedBlock)
        }
        
        var lowerBound = self.message.message.content!.startIndex
        var container = AttributeContainer()
        var string = messageToAttributedString(
          .init(role: self.message.message.role, content: nil)
        )
        
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
            container.foregroundColor = .white
            container.font = .systemFont(ofSize: 14)
            var substr = AttributedString(self.message.message.content![beforeRange])
            substr.setAttributes(container)
            string.append(substr)
            string.append(AttributedString(attributedString))
            lowerBound = match.upperBound
          } catch {
            continue
          }
        }
        if lowerBound < self.message.message.content!.endIndex {
          container = AttributeContainer()
          container.foregroundColor = .white
          container.font = .systemFont(ofSize: 14)
          var substr = AttributedString(self.message.message.content![lowerBound..<self.message.message.content!.endIndex])
          substr.setAttributes(container)
          string.append(substr)
        }
        
        self.viewingText = string
      }
    }
  }
}

extension AttributedString: @unchecked Sendable {}
