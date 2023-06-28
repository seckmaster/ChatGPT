//
//  SettingsPanel.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 28/06/2023.
//

import SwiftUI

struct SettingsPanel: View {
  @Binding var temperature: Double
  @Binding var model: Model
  @Binding var stream: Bool
  @Binding var enableSyntaxHighlight: Bool
  @State private var modelSelection: String = "GPT-4"
  @State private var customModelName: String = ""
  
  init(
    temperature: Binding<Double>,
    model: Binding<Model>,
    stream: Binding<Bool>,
    enableSyntaxHighlight: Binding<Bool>
  ) {
    self._temperature = temperature
    self._stream = stream
    self._model = model
    self._enableSyntaxHighlight = enableSyntaxHighlight
  }
  
  var body: some View {
    HStack {
      VStack {
        Text("Settings")
          .foregroundColor(.white)
          .padding(.bottom, 30)
        container { 
          Slider(
            value: $temperature, 
            in: 0...2, 
            label: { Text("Temperature:") },
            minimumValueLabel: { Text("0") },
            maximumValueLabel: { Text("2") }
          )
          HStack {
            Text(String(format: "Value: %.2f", temperature))
            Spacer()
          }
        }
        container { 
          Picker("Model", selection: $modelSelection) {
            ForEach(["GPT-4", "GPT-3-turbo", "Custom"], id: \.self) {
              Text($0)
            }
          }
          if modelSelection == "Custom" {
            HStack {
              Text("Enter model name: ")
              TextField("model", text: $customModelName)
            }
          }
        }
        container {
          HStack {
            Toggle(isOn: $stream) { Text("Stream:") }
              .toggleStyle(.switch)
            Spacer()
          }
        }
        container {
          HStack {
            Toggle(isOn: $stream) { Text("Stream:") }
              .toggleStyle(.switch)
            Spacer()
          }
        }
        Spacer()
      }
      .padding()
      .padding(.top, 60)
      .onChange(of: modelSelection) { selection in
        switch selection {
        case "Custom":
          break
        case "GPT-4":
          model = .gpt4
        case "GPT-3-turbo":
          model = .gpt3
        case _:
          break
        }
      }
      .onChange(of: customModelName) { modelName in
        guard modelSelection == "Custom" else { return }
        let modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        model = .custom(modelName)
      }
    }
    .background(Color.palette.background)
  }
  
  private func container(@ViewBuilder label: () -> some View) -> some View {
    VStack {
      label()
    }
    .padding()
    .background(Color.palette.background1)
    .cornerRadius(8)
  }
  
  enum Model: Hashable {
    case gpt3, gpt4
    case custom(String)
  }
}
