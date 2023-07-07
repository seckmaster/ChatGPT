//
//  ContentView.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI
import SwiftchainOpenAI
import RegexBuilder

struct ContentView: View {
  @State var editingText: String = ""
  @State var isLoading: Bool = false
  @State var showEnterApiKey = false
  @State var apiKey: String? {
    didSet {
      showEnterApiKey = apiKey == nil
      viewModel.apiKey = apiKey
      documentsViewModel.apiKey = apiKey
    }
  }
  @State var showSettingsPanel = false
  @State var showImportConversationView = false
  @ObservedObject var documentsViewModel: DocumentsView.ViewModel = .init()
  @ObservedObject var viewModel: ViewModel = .init()
  
  var body: some View {
    VStack {
      HStack(spacing: 20) {
        DocumentsView(viewModel: documentsViewModel)
          .frame(maxWidth: 350)
        if apiKey != nil {
          GeometryReader { proxy in
            VStack {
              GPTConsole(
                history: $documentsViewModel.activeDocumentHistory,
                isSyntaxHighlightingEnabled: $viewModel.enableSyntaxHighlighting,
                isStreamingText: $isLoading,
                didUpdateDocument: { updatedMessage in
                  if let (index, text) = updatedMessage {
                    documentsViewModel.activeDocumentHistory[index] = .init(
                      role: documentsViewModel.activeDocumentHistory[index].role, 
                      content: text
                    )
                    if documentsViewModel.activeDocumentId == nil {
                    } else {
                      documentsViewModel.storeActiveDocument(reload: true)
                    }
                  }
                }
              )
              input(height: proxy.size.height * 0.3 - 40)
            }
          }
          .padding(.all, 10)
          .background(Color.palette.background1)
        }
        if showSettingsPanel {
          SettingsPanel(
            temperature: $viewModel.temperature,
            model: $viewModel.model,
            stream: $viewModel.stream,
            enableSyntaxHighlight: $viewModel.enableSyntaxHighlighting
          )
          .frame(maxWidth: 350)
        }
      }
    }
    .enterApiKey(
      isVisible: $showEnterApiKey,
      save: {
        do {
          try ConfigStorage().store(config: .init(
            apiKey: $0
          ))
          apiKey = $0
        } catch {
          apiKey = $0
          print("Could not store api key!")
        }
      }
    )
    .onAppear {
      apiKey = try? ConfigStorage().config.apiKey
    }
    .sheet(isPresented: $showImportConversationView) { 
      HStack {
        Spacer()
        VStack {
          Spacer()
          Text("Beta")
            .font(.body.italic())
            .foregroundColor(.cyan)
          Text("Drop `conversation.json` file")
            .font(.body)
            .foregroundColor(.white)
          Spacer()
        }
        Spacer()
      }
      .frame(width: 300, height: 300, alignment: .center)
      .onDrop(of: [.json], isTargeted: nil) { providers, location in
        _ = providers[0].loadDataRepresentation(for: .json) { data, error in
          guard let data, error == nil else {
            return
          }
          Task { @MainActor in
            try documentsViewModel.importConversationsFromChatGPT(data: data)
            self.showImportConversationView = false
          }
        }
        return true
      }
    }
    .onDrop(
      of: [.fileURL], 
      isTargeted: nil
    ) { providers, location in
      _ = providers[0].loadDataRepresentation(for: .pdf) { data, error in
        guard let data, error == nil else {
          return
        }
        Task {
          try await dataToEmbedding(data)
        }
      }
      return true
    }
    #if os(macOS)
    .onExitCommand { 
      exit(0)
    }
    #endif
    .toolbar { 
      Button {
        print("expand")
        showSettingsPanel.toggle()
      } label: {
        Image(systemName: showSettingsPanel ? "forward.frame" : "backward.frame.fill")
      }
    }
    .toolbar { 
      Button("Import conversation") { 
        showImportConversationView = true
      }
    }
    .preferredColorScheme(.dark)
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
          Spacer()
          LoadingButton(isLoading: $isLoading) { isLoading in
            if isLoading {
              viewModel.activeTask?.cancel()
            } else {
              let task = Task {
                await callGPT()
              }
              viewModel.activeTask = task
            }
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
    #if os(macOS)
    .onKeyDown { event in
      let enterKeyCode: UInt16 = 36 // 'enter'
      let kKeyKode: UInt16 = 40     // 'k'
      switch (event.keyCode, event.modifierFlags.contains(.command)) {
      case (enterKeyCode, true):
        let task = Task {
          await callGPT()
        }
        viewModel.activeTask = task
      case (kKeyKode, true):
        editingText = ""
      case _:
        break
      }
    }
    #endif
  }
  
  // TODO: - Refactor this function
  @MainActor
  func callGPT() async { // TODO: - Move this business logic into the ViewModel
    guard !editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    guard viewModel.model.modelIdentifier != nil else { return } 
    
    documentsViewModel.activeDocumentHistory.append(.init(
      role: .user, 
      content: editingText.trimmingCharacters(in: .whitespacesAndNewlines)
    ))
    
    if documentsViewModel.activeDocumentId == nil {
      documentsViewModel.createNewDocument()
    } else {
      documentsViewModel.storeActiveDocument()
    }
    let documentID = documentsViewModel.activeDocumentId! 
    
    do {
      isLoading = true
      self.editingText = ""
      
      if viewModel.stream {
        documentsViewModel.appendMessage(
          .init(
            role: .assistant, 
            content: ""
          ),
          documentID: documentID
        )
        documentsViewModel.updateActiveHistory()

        for try await chunk in try viewModel.streamCallGPT(history: documentsViewModel.activeDocumentHistory) {
          let messages = chunk as! [ChatOpenAILLM.Message]
          for message in messages {
            guard let index = documentsViewModel.documentIndex(documentID: documentID) else { continue }
            documentsViewModel.documents[index].history[documentsViewModel.documents[index].history.count - 1].content!.append(message.content ?? "")
            if documentID == documentsViewModel.activeDocumentId {
              documentsViewModel.updateActiveHistory()
            }
          }
        }
        if let index = documentsViewModel.documentIndex(documentID: documentID) {
          documentsViewModel.storeDocument(documentsViewModel.documents[index])
        }
      } else {
        let response = try await viewModel.callGPT(
          history: documentsViewModel.activeDocumentHistory
        )
        documentsViewModel.appendMessage(
          .init(
            role: .assistant, 
            content: response ?? "<no response>"
          ),
          documentID: documentID
        )
        if documentID == documentsViewModel.activeDocumentId {
          documentsViewModel.updateActiveHistory()
        }
      }
    } catch {
      documentsViewModel.appendMessage(
        .init(
          role: .custom("Error"), 
          content: "There was an issue with calling GPT4:\n\(String(describing: error))"
        ),
        documentID: documentID
      )
      if documentID == documentsViewModel.activeDocumentId {
        documentsViewModel.updateActiveHistory()
      }
    }
    isLoading = false
  }
}

extension ContentView {
  class ViewModel: ObservableObject {
    @Published var temperature: Double = 0.3
    @Published var model: SettingsPanel.Model = .gpt4
    @Published var stream: Bool = true
    @Published var enableSyntaxHighlighting: Bool = true
    var activeTask: Task<(), Never>?
    
    var apiKey: String? {
      didSet {
        llm = .init(apiKey: apiKey, defaultModel: "gpt-4")
      }
    }
    private var llm: ChatOpenAILLM!
    
    func callGPT(history: ChatOpenAILLM.Messages) async throws -> String? {
      let response = try await llm.invoke(
        history.filter { $0.role.rawValue.lowercased() != "error" }, 
        temperature: temperature, 
        model: model.modelIdentifier!
      )
      guard !response.messages.isEmpty else { return nil }
      return response.messages[0].content
    }
    
    func streamCallGPT<C: Collection<ChatOpenAILLM.Message>>(history: C) throws -> any AsyncSequence {
      try llm.stream(
        history.filter { $0.role.rawValue.lowercased() != "error" }, 
        temperature: temperature, 
        model: model.modelIdentifier!
      )
    }
  }
}

extension SettingsPanel.Model {
  var modelIdentifier: String? {
    switch self {
    case .gpt3:
      return "gpt-3.5-turbo"
    case .gpt4:
      return "gpt-4"
    case .custom(let model):
      return model.isEmpty ? nil : model
    }
  }
}
