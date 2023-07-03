//
//  GPTConsole.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI
import SwiftchainOpenAI

struct GPTConsole: View {
  @State var title: String?
  @State var editingCellIndex: Int?
  @Binding var history: ChatOpenAILLM.Messages
  @Binding var isSyntaxHighlightingEnabled: Bool
  @Binding var isStreamingText: Bool
  
  var didUpdateDocument: ((Int, String)?) -> Void
  
  init(
    history: Binding<ChatOpenAILLM.Messages>,
    isSyntaxHighlightingEnabled: Binding<Bool>,
    isStreamingText: Binding<Bool>,
    didUpdateDocument: @escaping ((Int, String)?) -> Void
  ) {
    self._history = history
    self._isSyntaxHighlightingEnabled = isSyntaxHighlightingEnabled
    self._isStreamingText = isStreamingText
    self.didUpdateDocument = didUpdateDocument
  }
  
  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(Array(zip(history.indices, history)), id: \.0) { offset, message in
          GPTConsoleCell(
            message: .init(id: offset, message: message), 
            isEditing: offset == editingCellIndex,
            isSyntaxHighlightingEnabled: $isSyntaxHighlightingEnabled,
            isStreamingText: $isStreamingText,
            didStopEditing: { updatedText in
              didUpdateDocument((offset, updatedText))
              editingCellIndex = nil
            }, 
            requestStartEdit: {
              editingCellIndex = offset
              history.append(.init(role: .assistant, content: nil))
              history.removeLast()
            }
          )
          .id(offset)
        }
        .onDelete { indexSet in
          history.remove(atOffsets: indexSet)
          didUpdateDocument(nil)
        }
      }
      .onChange(of: history) { _ in
        proxy.scrollTo(history.indices.last!)
        editingCellIndex = nil
      }
    }
  }
}

#if canImport(AppKit)
import AppKit

struct ObserveKeyEventsView: ViewRepresentable {
  class ObserveKeyView: NSView {
    let observer: (NSEvent) -> Void 
    
    init(observer: @escaping (NSEvent) -> Void) {
      self.observer = observer
      super.init(frame: .zero)
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        self.keyDown(with: event)
        return event
      }
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func keyDown(with event: NSEvent) {
      observer(event)
    }
  }
  
  let observer: (NSEvent) -> Void
  
  func makeNSView(context: Context) -> ObserveKeyView {
    .init(observer: observer)
  }
  
  func updateNSView(_ view: ObserveKeyView, context: Context) {
  }
}

struct ObserveKeyEventsModifier: ViewModifier {
  let observer: (NSEvent) -> Void
  
  func body(content: Content) -> some View {
    content
      .overlay { 
        ObserveKeyEventsView(observer: observer)
          .allowsHitTesting(false)
      }
  }
}

extension View {
  func onKeyDown(observer: @escaping (NSEvent) -> Void) -> some View {
    modifier(ObserveKeyEventsModifier(observer: observer))
  }
}
#endif

let defaultChatGPTPrompt = """
You are a helpful assistant. Respond to user's queries in an informative, professional and honest manner. Be as comprehensive as possible!
"""
