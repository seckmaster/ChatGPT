//
//  ApiKeyView.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 02/05/2023.
//

import SwiftUI

struct ApiKeyView: View {
  @State private var text: String = ""
  
  let save: (String) -> Void
  
  var body: some View {
    GeometryReader { metrics in
      VStack() {
        VStack {}
        VStack {
          Text("Enter your OpenAI API Key:")
            .foregroundColor(.white)
            .font(.system(size: 14))
          TextField("API key", text: $text)
          Button("Save") { 
            save(text)
          }
          .buttonStyle(.borderedProminent)
        }
        VStack {}
      }
    }
    .background()
  }
}

struct ApiKeyViewModifier: ViewModifier {
  @Binding var isVisible: Bool
  let save: (String) -> Void
  
  func body(content: Content) -> some View {
    ZStack {
      content
      if isVisible {
        ApiKeyView(save: save)
      }
    }
  }
}

struct ApiKeyView_Previews: PreviewProvider {
  static var previews: some View {
    ApiKeyView(save: { _ in })
  }
}

extension View {
  func enterApiKey(
    isVisible: Binding<Bool>,
    save: @escaping (String) -> Void
  ) -> some View {
    modifier(ApiKeyViewModifier(
      isVisible: isVisible, 
      save: save
    ))
  }
}
