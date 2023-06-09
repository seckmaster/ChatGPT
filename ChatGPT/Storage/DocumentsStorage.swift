//
//  DocumentsStorage.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import Foundation
import SwiftchainOpenAI

struct Document: Identifiable, Codable, Hashable {
  var id: UUID
  var title: String?
  var history: [ChatOpenAILLM.Message]
  var createdAt: Date
  var lastModifiedAt: Date
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  var displayName: String {
    if let title, !title.isEmpty { return title }
    return "New document"
  }
}

struct DocumentsStorage {
  init() {
    if !FileManager.default.fileExists(atPath: url.absoluteString, isDirectory: nil) {
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }
  }
  
  func documents() throws -> [Document] {
    let ids = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    let documents = try ids.map { try loadDocument(from: $0) }
    return documents
  }
  
  func loadDocument(for id: Document.ID) throws -> Document {
    let document = try JSONDecoder().decode(
      Document.self, 
      from: Data(contentsOf: url.appending(path: id))
    )
    return document
  }
  
  func loadDocument(from url: URL) throws -> Document {
    let document = try JSONDecoder().decode(
      Document.self, 
      from: Data(contentsOf: url)
    )
    return document
  }
  
  func store(document: Document) throws {
    let data = try JSONEncoder().encode(document)
    try data.write(to: url.appending(path: document.id))
  }
  
  func delete(documentID id: Document.ID) throws {
    try FileManager.default.removeItem(at: url.appending(path: id))
  }
  
  private var url: URL {
    FileManager.default.appStorageURL
      .appending(path: "documents")
  }
}

extension URL {
  func appending(path: UUID) -> URL {
    appending(path: path.uuidString)
  }
}
