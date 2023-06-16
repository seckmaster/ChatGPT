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
//  @State var isShowingDocumentsView = true
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
  @ObservedObject var documentsViewModel: DocumentsView.ViewModel = .init()
  @ObservedObject var viewModel: ViewModel = .init()
  
  var body: some View {
    VStack {
      HStack(spacing: 20) {
//        if isShowingDocumentsView {
        DocumentsView(viewModel: documentsViewModel)
          .frame(maxWidth: 350)
//        }
        if apiKey != nil {
          GeometryReader { proxy in
            VStack {
              GPTConsole(
                history: $documentsViewModel.activeDocumentHistory,
                didUpdateDocument: { updatedMessage in
                  if let (index, text) = updatedMessage {
                    documentsViewModel.activeDocumentHistory[index] = .init(
                      role: documentsViewModel.activeDocumentHistory[index].role, 
                      content: text
                    )
                    documentsViewModel.updateActiveHistory()
                  }
                  documentsViewModel.storeActiveDocument()
                }
              )
              input(height: proxy.size.height * 0.3 - 40)
            }
          }
          .padding(.all, 10)
          .background(Color.palette.background1)
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
          print("Could not store api key!")
        }
      }
    )
    .onAppear {
      apiKey = try? ConfigStorage().config.apiKey
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
          Spacer()
          
          LoadingButton(isLoading: $isLoading) { 
            Task {
              await callGPT()
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
    .onKeyDown { event in
      let enterKeyCode: UInt16 = 36 // 'enter'
      let kKeyKode: UInt16 = 40     // 'k'
      switch (event.keyCode, event.modifierFlags.contains(.command)) {
      case (enterKeyCode, true):
        Task {
          await callGPT()
        }
      case (kKeyKode, true):
        editingText = ""
      case _:
        break
      }
    }
  }
  
  @MainActor
  func callGPT() async { // TODO: - Move this business logic into the ViewModel
    guard !editingText.isEmpty else { return }
    
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
    
    let editingText = editingText
      .trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      isLoading = true
      let content = editingText
      self.editingText = ""
      let response = try await viewModel.callGPT(
        content: content,
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
    var apiKey: String? {
      didSet {
        llm = .init(
          apiKey: apiKey,
          defaultTemperature: 0.3, 
          defaultNumberOfVariants: 1, 
          defaultModel: "gpt-4"
        )
      }
    }
    private var llm: ChatOpenAILLM = .init(
      defaultTemperature: 0.3, 
      defaultNumberOfVariants: 1, 
      defaultModel: "gpt-4"
    )
    
    func callGPT(content: String, history: ChatOpenAILLM.Messages) async throws -> String? {
      let response = try await llm.invoke(
        history.filter { $0.role.rawValue != "error" }, 
        temperature: 0.0, 
        numberOfVariants: 1, 
        model: "gpt-4"
      )
      guard !response.messages.isEmpty else { return nil }
      return response.messages[0].content
    }
  }
}
