//
//  RestAPITest.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2026/02/01.
//

import SwiftUI

struct APITestView: View {
    @State private var APIText: String = ""
    var body: some View {
        Text(APIText)
            .onAppear {
                let urlPath = "http://localhost:8100"
                let url = URL(string: urlPath)!
                let session = URLSession.shared
                let task = session.dataTask(with: url) { data, response, error in
                    print("Task completed")
                    
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription)
                        return
                    }
                    
                    do {
                        if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let results = jsonResult["status"] as? String {
                                DispatchQueue.main.async {
                                    self.APIText = results
                                }
                            }
                        }
                    } catch let parseError {
                        print("JSON Error \(parseError.localizedDescription)")
                    }
                }
                
                task.resume()
                
            }
    }
}
