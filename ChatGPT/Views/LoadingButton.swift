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
  let action: (Bool) -> Void
  let label: () -> T
  
  var body: some View {
    Button {
      action(isLoading)
    } label: {
      if isLoading {
        ProgressView()
          .controlSize(.small)
          .tint(.white)
          .padding()
      } else {
        label()
      }
    }
  }
}
