//
//  FileManager+ChatGPT.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 09/06/2023.
//

import Foundation

extension FileManager {
  var appStorageURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "ChatGPT")
  }
}
