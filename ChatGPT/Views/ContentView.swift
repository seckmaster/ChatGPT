//
//  ContentView.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI
import SwiftchainOpenAI

struct ContentView: View {
  @State var isShowingDocumentsView = true
  @State var showEnterApiKey = false
  @State var apiKey: String? {
    didSet {
      showEnterApiKey = apiKey == nil
      documentsViewModel.apiKey = apiKey
      consoleViewModel.apiKey = apiKey
    }
  }
  @ObservedObject var consoleViewModel: GPTConsole.ViewModel = .init()
  @ObservedObject var documentsViewModel: DocumentsView.ViewModel = .init()
  
  var body: some View {
    VStack {
      HStack(spacing: 20) {
        if isShowingDocumentsView {
          try? DocumentsView(viewModel: documentsViewModel) {
            if let history = $0 {
              consoleViewModel.history = history
              consoleViewModel.updateMessages()
            } else {
              consoleViewModel.prepareNewDocument()
            }
          }
          .frame(maxWidth: 350)
        }
        if apiKey != nil {
          GPTConsole(viewModel: consoleViewModel) {
            didUpdateDocument(history: $0)
          }
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
  
  func didUpdateDocument(history: ChatOpenAILLM.Messages) {
    documentsViewModel.didUpdateDocument(history: history)
  }
}
