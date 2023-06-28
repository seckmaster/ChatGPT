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
    var sb: stat = .init()
    let path = FileManager.default.appStorageURL.path().removingPercentEncoding!
    if stat(path, &sb) != 0 {
      mkdir(path, 0777)
    } else {
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
