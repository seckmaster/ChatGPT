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
      let text = """
      Here's a simple C++ program to generate Fibonacci numbers:
      
      ```cpp
      #include <iostream>
      
      int main() {
      int n, first = 0, second = 1, next;
      
      std::cout << "Enter the number of Fibonacci numbers to generate: ";
      std::cin >> n;
      
      std::cout << "Fibonacci series: ";
      
      for (int i = 0; i < n; ++i) {
        if (i <= 1) {
            next = i;
        } else {
            next = first + second;
            first = second;
            second = next;
        }
        std::cout << next << " ";
      }
      
      std::cout << std::endl;
      return 0;
      }
      ```
      
      This program prompts the user to enter the number of Fibonacci numbers to generate, then calculates and prints the Fibonacci series up to the specified length. The Fibonacci sequence starts with 0 and 1, and each subsequent number is the sum of the previous two numbers.
      """
      text.matches(of: Regex {
        ChoiceOf {
          "```"
          "'''"
        }
        Capture {
          OneOrMore(.word)
          Anchor.endOfLine
        }
        Capture {
          OneOrMore(.any)
        }
        ChoiceOf {
          "```"
          "'''"
        }
      }).forEach { match in
        print(match.output.1)
        print()
        print(match.output.2)
      }
    }
  }
  
  func didUpdateDocument(history: ChatOpenAILLM.Messages) {
    documentsViewModel.didUpdateDocument(history: history)
  }
}
