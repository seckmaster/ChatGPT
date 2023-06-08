//
//  LoadingButton.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import Foundation
import SwiftUI

struct LoadingButton<T: View>: View {
  @Binding var isLoading: Bool
  let action: () -> Void
  let label: () -> T
  
  var body: some View {
    Button {
      action()
    } label: {
      if isLoading {
        ProgressView()
          .tint(.white)
          .padding()
      } else {
        label()
      }
    }
    .disabled(isLoading)
  }
}
