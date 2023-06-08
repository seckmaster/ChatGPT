//
//  ContentView.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      if let apiKey = try? ConfigStorage().config.apiKey {
        GPTConsole(viewModel: .init(apiKey: apiKey))
      } else {
        GPTConsole(viewModel: .init())
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
