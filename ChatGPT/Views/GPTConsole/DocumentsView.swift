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
  
  init(
    viewModel: ViewModel
  ) {
    self.viewModel = viewModel
  }
  
  var body: some View {
    VStack {
      Button {
        viewModel.activeDocumentId = nil
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
            guard viewModel.activeDocumentId != document.id else { return }
            viewModel.isEditingDocumentTitle = false
            viewModel.activeDocumentId = document.id
            viewModel.editableDocumentTitle = document.title ?? ""
          } label: {
            HStack {
              DocumentCell(
                documentID: document.id, 
                title: document.displayName,
                editableTitle: $viewModel.editableDocumentTitle,
                isEditingTitle: document.id == viewModel.activeDocumentId ? $viewModel.isEditingDocumentTitle : .constant(false)
              )
              Spacer()
              if viewModel.activeDocumentId == document.id {
                Button {
                  viewModel.isEditingDocumentTitle.toggle()
                  if !viewModel.isEditingDocumentTitle {
                    viewModel.updateDocumentTitle(newTitle: viewModel.editableDocumentTitle)
                  }
                } label: {
                  Image(systemName: viewModel.isEditingDocumentTitle ? "checkmark.circle" : "pencil")
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .background(Color.palette.background2)
              }
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
        .onDelete { indexSet in
          for index in indexSet {
            try? viewModel.documentsStorage.delete(documentID: viewModel.documents[index].id)
          }
          viewModel.loadDocuments()
          viewModel.activeDocumentId = nil
        }
      }
    }
    .background(Color.palette.background1)
    .onAppear {
      viewModel.loadDocuments()
    }
  }
  
  func background(documentID: Document.ID) -> Color {
    if hoveringDocumentID == documentID && viewModel.activeDocumentId == documentID {
      return .palette.background1
    }
    if hoveringDocumentID == documentID {
      return .palette.background
    }
    if viewModel.activeDocumentId == documentID {
      return .palette.background2
    }
    return .clear
  }
}

extension DocumentsView {
  struct DocumentCell: View {
    let documentID: Document.ID
    let title: String
    @Binding var editableTitle: String
    @Binding var isEditingTitle: Bool
    
    var body: some View {
      HStack(spacing: 12) {
        Image(systemName: "bubble.left")
        if isEditingTitle {
          TextField(text: $editableTitle) { Text("Title") }
            .foregroundColor(.white)
            .background(Color.clear)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .font(.system(size: 14))
        } else {
          Text(title)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .font(.system(size: 14))
        }
      }
    }
  }
}

extension DocumentsView {
  class ViewModel: ObservableObject {
    private var llm: ChatOpenAILLM!
    
    let documentsStorage = DocumentsStorage()
    
    @Published var documents: [Document] = []
    @Published var activeDocumentId: Document.ID? {
      didSet {
        activeDocumentHistory = activeDocumentId.flatMap { id in documents.first(where: { $0.id == id }) }?.history ?? .default
      }
    }
    @Published var isEditingDocumentTitle = false
    @Published var editableDocumentTitle = ""
    @Published var activeDocumentHistory: ChatOpenAILLM.Messages
    
    var apiKey: String? {
      didSet {
        llm = .init(apiKey: apiKey)
      }
    }
    
    init() {
      activeDocumentHistory = .default
    }
    
    @MainActor
    func updateDocument() {
      guard activeDocumentHistory.count >= 2 else { return }
      
      let isNewDocument = activeDocumentHistory.count == 2 // system + user
      if isNewDocument {
        do {
          var document = Document(
            id: .init(), 
            history: activeDocumentHistory, 
            createdAt: .init(), 
            lastModifiedAt: .init() 
          )
          try documentsStorage.store(document: document)
          loadDocuments()
          activeDocumentId = document.id
          Task { @MainActor in
            do {
              let response = try await llm.invoke(
                [
                  .init(
                    role: .user, 
                    content: """
                  Provide a short title for a document. The document starts with the following user query: 
                  
                  User query: \(activeDocumentHistory[1].content)
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
        guard let activeDocumentId else {
          fatalError("Invalid state?")
        }
        var document = documents.first { $0.id == activeDocumentId }!
        document.history = activeDocumentHistory
        document.lastModifiedAt = Date()
        do {
          try documentsStorage.store(document: document)
          loadDocuments()
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
    
    func updateDocumentTitle(newTitle title: String) {
      guard var document = documents.first(where: { $0.id == activeDocumentId }) else { return }
      document.title = title
      document.lastModifiedAt = Date()
      do {
        try documentsStorage.store(document: document)
        loadDocuments()
      } catch {
        print("Storing a document failed with error:", error)
      }
    }
  }
}

extension ChatOpenAILLM.Messages {
  static var `default`: ChatOpenAILLM.Messages {
    [
      .init(role: .system, content: defaultChatGPTPrompt)
    ]
  }
}
