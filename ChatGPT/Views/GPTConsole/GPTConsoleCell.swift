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
  @State var height: CGFloat?
  @State var isEditing = false
  @State var isHovering = false
  @State var delegate: TextViewDelegate<ViewModel>!
  var didStopEditing: () -> Void
  
  init(
    message: Message, 
    modifier: @escaping (AttributedString) -> Void,
    didStopEditing: @escaping () -> Void
  ) {
    self.viewModel = .init(message: message, modifier: modifier)
    self.didStopEditing = didStopEditing
  }
  
  var body: some View {
    ZStack {
      HStack {
        if isEditing, let height {
          TextView<ViewModel>(text: $viewModel.text, delegate: delegate)
            .frame(maxWidth: .infinity)
            .frame(height: height)
        } else {
          Text(viewModel.viewingText)
            .onTapGesture {
              beginEditing()
            }
            .background(GeometryReader { proxy in
              Color.clear
                .preference(key: SizePreferenceKey.self, value: proxy.size)
            })
            .onPreferenceChange(SizePreferenceKey.self) { 
              height = $0.height
            }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
              isEditing = false
              didStopEditing()
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
  }
  
  func beginEditing() {
    delegate = .init(viewModel: viewModel)
    isEditing = true
  }
}

extension GPTConsoleCell {
  struct Message: Identifiable {
    let id: Int
    var message: ChatOpenAILLM.Message
  }
  
  class ViewModel: EditingViewModel {
    var message: Message
    let modifier: (AttributedString) -> Void
    
    @Published var isBoldHighlighted: Bool = false
    @Published var isItalicHighlighted: Bool = false
    @Published var isUnderlineHighlighted: Bool = false
    @Published var isHeading1: Bool = false
    @Published var isHeading2: Bool = false
    @Published var isHeading3: Bool = false
    @Published var selectedRanges: [NSRange] = []
    @Published var viewingText: AttributedString
    @Published var text: AttributedString
    
    init(message: Message, modifier: @escaping (AttributedString) -> Void) {
      self.message = message
      var container = AttributeContainer()
      container.foregroundColor = .white
      container.font = .systemFont(ofSize: 14)
      self.text = AttributedString(message.message.content, attributes: container)
      self.viewingText = .init()
      self.modifier = modifier
      Task { @MainActor in
        self.viewingText = await messageToAttributedString(message.message)
      }
    }
    
    func updateDocument() {
      modifier(text)
    }
    
    @MainActor
    func updateText() {
      message.message = .init(
        role: message.message.role,
        content: .init(text.characters[...])
      )
      Task {
        viewingText = await messageToAttributedString(message.message)
      }
    }
  }
}

extension AttributedString: @unchecked Sendable {}

struct SizePreferenceKey: PreferenceKey {
  typealias Value = CGSize
  static var defaultValue: Value = .zero
  
  static func reduce(value _: inout Value, nextValue: () -> Value) {
    _ = nextValue()
  }
}
