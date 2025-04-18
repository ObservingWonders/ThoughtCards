//
//  DataManager.swift
//  ThoughtCards
//
//  Created by Kevin Oberhausen on 4/18/25.
//


import Foundation

class DataManager {
    static let shared = DataManager()
    
    private let cardsKey = "saved_cards"
    private let documentsKey = "saved_documents"
    
    // Get the URL for the documents directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Save cards to disk
    func saveCards(_ cards: [Card]) {
        do {
            let data = try JSONEncoder().encode(cards)
            UserDefaults.standard.set(data, forKey: cardsKey)
        } catch {
            print("Failed to save cards: \(error.localizedDescription)")
        }
    }
    
    // Load cards from disk
    func loadCards() -> [Card] {
        guard let data = UserDefaults.standard.data(forKey: cardsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([Card].self, from: data)
        } catch {
            print("Failed to load cards: \(error.localizedDescription)")
            return []
        }
    }
    
    // Save documents to disk
    func saveDocuments(_ documents: [Document]) {
        do {
            let data = try JSONEncoder().encode(documents)
            UserDefaults.standard.set(data, forKey: documentsKey)
        } catch {
            print("Failed to save documents: \(error.localizedDescription)")
        }
    }
    
    // Load documents from disk
    func loadDocuments() -> [Document] {
        guard let data = UserDefaults.standard.data(forKey: documentsKey) else {
            // Return default documents if nothing is saved
            return [Document(name: "Tasks", content: "", isTaskDocument: true)]
        }
        
        do {
            let documents = try JSONDecoder().decode([Document].self, from: data)
            // Ensure we always have a Tasks document
            if !documents.contains(where: { $0.isTaskDocument }) {
                var updatedDocuments = documents
                updatedDocuments.append(Document(name: "Tasks", content: "", isTaskDocument: true))
                return updatedDocuments
            }
            return documents
        } catch {
            print("Failed to load documents: \(error.localizedDescription)")
            return [Document(name: "Tasks", content: "", isTaskDocument: true)]
        }
    }
}