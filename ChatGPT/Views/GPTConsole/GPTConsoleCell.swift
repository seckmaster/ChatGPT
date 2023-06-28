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
    didStopEditing: @escaping (String) -> Void,
    requestStartEdit: @escaping () -> Void
  ) {
    self.viewModel = .init(message: message)
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
        HStack {
          TextView<ViewModel>(text: $viewModel.text, delegate: delegate)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(isEditing ? 1 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    init(message: Message) {
      self.message = message
      var container = AttributeContainer()
      container.foregroundColor = .white
      container.font = .systemFont(ofSize: 14)
      self.text = AttributedString(message.message.content!, attributes: container)
      self.viewingText = .init()
//      Task { @MainActor in
//        self.viewingText = await messageToAttributedString(message.message)
//      }
      self.viewingText = messageToAttributedString(message.message)
    }
    
    func updateDocument() {
    }
    
    @MainActor
    func updateText() {
      message.message = .init(
        role: message.message.role,
        content: .init(text.characters[...])
      )
//      Task {
//        viewingText = await messageToAttributedString(message.message)
//      }

      self.viewingText = messageToAttributedString(message.message)
    }
  }
}

extension AttributedString: @unchecked Sendable {}
