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
//  @State var messages: [GPTConsoleCell.Message] = []
  @Binding var history: ChatOpenAILLM.Messages
//  var history: [ChatOpenAILLM.Message]()
  
  var didUpdateDocument: ((Int, String)?) -> Void
  
  init(
    history: Binding<ChatOpenAILLM.Messages>,
    didUpdateDocument: @escaping ((Int, String)?) -> Void
  ) {
    self._history = history
    self.didUpdateDocument = didUpdateDocument
  }
  
  var body: some View {
    List {
      ForEach(Array(zip(history.indices, history)), id: \.0) { offset, message in
        GPTConsoleCell(message: .init(id: offset, message: message)) { updatedText in
          didUpdateDocument((offset, updatedText))
        }
      }
      .onDelete { indexSet in
        history.remove(atOffsets: indexSet)
        didUpdateDocument(nil)
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
