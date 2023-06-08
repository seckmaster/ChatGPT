//
//  DocumentsView.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import Foundation
import SwiftUI
import SwiftchainOpenAI

struct DocumentsView: View {
  @ObservedObject var viewModel: ViewModel
  @State var hoveringDocumentID: Document.ID?
  var didSelectDocument: (ChatOpenAILLM.Messages?) -> Void
  
  init(
    viewModel: ViewModel,
    didSelectDocument: @escaping (ChatOpenAILLM.Messages?) -> Void
  ) throws {
    self.viewModel = viewModel
    self.didSelectDocument = didSelectDocument
  }
  
  var body: some View {
    VStack {
      Button {
        viewModel.activePostID = nil
        didSelectDocument(nil)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus.bubble.fill")
            .padding(.leading, 20)
          Text("New chat")
          Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
      }
      .buttonStyle(.borderless)
      .overlay { 
        RoundedRectangle(cornerRadius: 6)
          .stroke()
      }
      .padding()
      List {
        ForEach(viewModel.documents) { document in
          Button {
            viewModel.activePostID = document.id
            didSelectDocument(document.history)
          } label: {
            HStack {
              DocumentCell(
                documentID: document.id, 
                title: document.displayName
              )
              Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .padding(.horizontal, 16)
          }
          .buttonStyle(.borderless)
          .background(background(documentID: document.id))
          .cornerRadius(8)
          .onHover { over in
            hoveringDocumentID = over ? document.id : nil
          }
        }
      }
    }
    .background(Color.palette.background1)
    .onAppear {
      viewModel.loadDocuments()
    }
  }
  
  func background(documentID: Document.ID) -> Color {
    if hoveringDocumentID == documentID && viewModel.activePostID == documentID {
      return .palette.background1
    }
    if hoveringDocumentID == documentID {
      return .palette.background
    }
    if viewModel.activePostID == documentID {
      return .palette.background2
    }
    return .clear
  }
}

extension DocumentsView {
  struct DocumentCell: View {
    let documentID: Document.ID
    let title: String
    
    var body: some View {
      HStack(spacing: 12) {
        Image(systemName: "bubble.left")
        Text(title)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity, alignment: .leading)
          .multilineTextAlignment(.leading)
          .font(.system(size: 14))
      }
    }
  }
}

extension DocumentsView {
  class ViewModel: ObservableObject {
    let documentsStorage = DocumentsStorage()
    
    @Published var documents: [Document] = []
    @Published var activePostID: Document.ID?
    
    var apiKey: String? {
      didSet {
        llm = apiKey.map { .init(apiKey: $0) }
      }
    }
    
    private var llm: ChatOpenAILLM!
    
    @MainActor
    func didUpdateDocument(history: ChatOpenAILLM.Messages) {
      if history.count < 2 { fatalError() }
      let isNewDocument = history.count == 2 // system + user
      if isNewDocument {
        do {
          var document = Document(
            id: .init(), 
            history: history, 
            createdAt: .init(), 
            lastModifiedAt: .init() 
          )
          try documentsStorage.store(document: document)
          loadDocuments()
          activePostID = document.id
          Task { @MainActor in
            do {
              let response = try await llm.invoke(
                [
                  .init(
                    role: .user, 
                    content: """
                  Provide a document a short title for the following start of the conversation:
                  
                  Conversation: \(history[1].content)
                  """
                  )
                ], 
                temperature: 1.0, 
                numberOfVariants: 1, 
                model: "gpt-4"
              )
              document.title = response.messages.first?.content
              try documentsStorage.store(document: document)
              loadDocuments()
            } catch {
              print("Error while fetching title for the document!")
            }
          }
        } catch {
          print("Storing a document failed with error:", error)
        }
      } else {
        guard let activePostID else {
          fatalError("Invalid state?")
        }
        var document = documents.first { $0.id == activePostID }!
        document.history = history
        document.lastModifiedAt = Date()
        do {
          try documentsStorage.store(document: document)
          loadDocuments()
          print("Did update document with id: \(document.id)")
        } catch {
          print("Storing a document failed with error:", error)
        }
      }
    }
    
    func loadDocuments() {
      do {
        documents = try documentsStorage
          .documents()
          .sorted { $0.createdAt > $1.createdAt }
      } catch {
        print("Loading documents failed with error:", error)
      }
    }
  }
}
