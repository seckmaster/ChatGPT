//
//  GPTConsole.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI
import SwiftchainOpenAI

struct GPTConsole: View {
  @ObservedObject var viewModel: ViewModel
  @State var editingText: String = ""
  @State var isLoading: Bool = false
  var didUpdateDocument: (ChatOpenAILLM.Messages) -> Void
  
  init(
    viewModel: ViewModel,
    didUpdateDocument: @escaping (ChatOpenAILLM.Messages) -> Void
  ) {
    self.viewModel = viewModel
    self.didUpdateDocument = didUpdateDocument
  }
  
  var body: some View {
    GeometryReader { metrics in
      VStack(alignment: .leading) {
        List {
          ForEach(viewModel.messages) { message in
            GPTConsoleCell(message: message) { modifiedText in
              viewModel.history[message.id] = .init(
                role: message.message.role,
                content: String(modifiedText.characters[...])
              )
            } didStopEditing: {
              viewModel.updateMessages()
            }
          }
          .onDelete { indexSet in
            DispatchQueue.main.async {
              viewModel.history.remove(atOffsets: indexSet)
              viewModel.updateMessages()
            }
          }
        }
        input(height: metrics.size.height * 0.3 - 40)
      }
      .padding(.all, 10)
      .background(Color.palette.background1)
    }
  }
  
  @ViewBuilder func input(height: CGFloat) -> some View {
    ZStack {
      HStack {
        TextEditor(text: $editingText)
          .font(Font.system(size: 14))
          .scrollContentBackground(.hidden)
      }
      .padding()
      HStack { 
        Spacer()
        VStack {
//          Button {
//            editingText = ""
//          } label: {
//            Image(systemName: "trash.slash.fill")
//              .frame(width: 50, height: 50)
//          }
//          .background(Color.palette.background)
//          .buttonStyle(.borderless)
          Spacer()
          
          LoadingButton(isLoading: $isLoading) { 
            callGPT()
          } label: { 
            Image(systemName: "paperplane.fill")
              .frame(width: 50, height: 50)
          }
          .background(Color.palette.background)
          .buttonStyle(.borderless)
        }
        .padding()
      }
    }
    .frame(height: min(300, max(120, height)))
    .background(Color.palette.background2)
    .cornerRadius(12)
    .onKeyDown { event in
      let enterKeyCode: UInt16 = 36
      let kKeyKode: UInt16 = 40
      switch (event.keyCode, event.modifierFlags.contains(.command)) {
      case (enterKeyCode, true):
        callGPT()
      case (kKeyKode, true):
        editingText = ""
      case _:
        break
      }
    }
  }
  
  @MainActor
  func callGPT() {
    guard !editingText.isEmpty else { return }
    let editingText = editingText
      .trimmingCharacters(in: .whitespacesAndNewlines)
    viewModel.history.append(.init(role: .user, content: editingText))
    viewModel.updateMessages()
    didUpdateDocument(viewModel.history)
    Task {
      isLoading = true
      let content = editingText
      self.editingText = ""
      await viewModel.callGPT(content: content)
      didUpdateDocument(viewModel.history)
      isLoading = false
    }
  }
}

extension GPTConsole {
  class ViewModel: ObservableObject {
    @Published var title: String?
    @Published var messages: [GPTConsoleCell.Message] = []
    var history: ChatOpenAILLM.Messages
    var apiKey: String? {
      didSet {
        llm = apiKey.map { .init(apiKey: $0) }
      }
    }
    
    private var llm: ChatOpenAILLM!
    
    init() {
      history = [
        .init(
          role: .system, 
          content: defaultChatGPTPrompt
        )
      ]
      updateMessages()
    }
   
    init(prompt: String) {
      history = [
        .init(
          role: .system, 
          content: prompt
        )
      ]
      updateMessages()
    } 
    
    init(history: ChatOpenAILLM.Messages) {
      self.history = history
      updateMessages()
    }
    
    @MainActor
    func callGPT(content: String) async {
      do {
        let response = try await llm.invoke(
          history.filter { $0.role.rawValue != "error" }, 
          temperature: 0.0, 
          numberOfVariants: 1, 
          model: "gpt-4"
        )
        guard !response.messages.isEmpty else { return }
        history.append(.init(role: .assistant, content: response.messages[0].content))
      } catch {
        history.append(.init(role: .custom("error"), content: String(describing: error)))
      }
      updateMessages()
    }
    
    func updateMessages() {
      messages = history.enumerated().map {
        .init(id: $0.offset, message: $0.element)
      }
    }
    
    func prepareNewDocument() {
      history = [
        .init(
          role: .system, 
          content: defaultChatGPTPrompt
        )
      ]
      updateMessages()
    }
  }
}

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

let defaultChatGPTPrompt = """
You are a helpful assistant. Respond to user's queries in an informative, professional and honest manner. Be as comprehensive as possible!
"""
