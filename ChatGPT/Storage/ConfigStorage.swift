//
//  ConfigStorage.swift
//  ChatGPT
//
//  Created by Toni K. Turk on 08/06/2023.
//

import Foundation

struct ConfigStorage {
  struct Config: Codable {
    let apiKey: String
  }
  
  init() {
    let path = FileManager.default.appStorageURL.path().removingPercentEncoding!
    if !FileManager.default.fileExists(atPath: path) {
      try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
      try! FileManager.default.createDirectory(atPath: path+"/documents", withIntermediateDirectories: false)
    }
  }
  
  var config: Config {
    get throws {
      let data = try Data(contentsOf: url)
      let config = try JSONDecoder().decode(Config.self, from: data)
      return config
    } 
  }
  
  func store(config: Config) throws {
    let data = try JSONEncoder().encode(config)
    try data.write(to: url)
  }
  
  func delete() throws {
    try FileManager.default.removeItem(at: url)
  }
  
  private var url: URL {
    FileManager.default.appStorageURL
      .appending(path: "config")
  }
}
