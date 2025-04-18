import Foundation
import SwiftUI

// A Card represents a captured thought or idea
struct Card: Identifiable, Codable, Equatable {
    var id = UUID()
    var content: String
    var creationDate = Date()
    var documentID: UUID? // nil means it's not assigned to any document
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.id == rhs.id
    }
}

// A Document can be a regular document or the special Tasks document
struct Document: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var content: String = ""
    var isTaskDocument: Bool = false
    var creationDate = Date()
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}

// Main app data model that will store all our cards and documents
class AppData: ObservableObject {
    @Published var cards: [Card] = [] {
        didSet {
            DataManager.shared.saveCards(cards)
        }
    }
    
    @Published var documents: [Document] = [] {
        didSet {
            DataManager.shared.saveDocuments(documents)
        }
    }
    
    init() {
        // Load saved data
        self.cards = DataManager.shared.loadCards()
        self.documents = DataManager.shared.loadDocuments()
        
        // Ensure we have a Tasks document
        if !documents.contains(where: { $0.isTaskDocument }) {
            let tasksDocument = Document(name: "Tasks", content: "", isTaskDocument: true)
            documents.append(tasksDocument)
        }
    }
    
    // Get all unassigned cards
    func unassignedCards() -> [Card] {
        return cards.filter { $0.documentID == nil }
    }
    
    // Get cards assigned to a specific document
    func cardsForDocument(documentID: UUID) -> [Card] {
        return cards.filter { $0.documentID == documentID }
    }
    
    // Create a new card
    func addCard(content: String) {
        let newCard = Card(content: content)
        cards.append(newCard)
    }
    
    // Create a new document
    func addDocument(name: String) {
        let newDocument = Document(name: name)
        documents.append(newDocument)
    }
    
    // Assign a card to a document
    func assignCard(_ card: Card, toDocumentWithID documentID: UUID) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].documentID = documentID
        }
    }
    
    // Remove a card from a document (set documentID to nil)
    func unassignCard(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].documentID = nil
        }
    }
    
    // Move card content to document and remove the card
    func moveCardContentToDocument(_ card: Card, document: Document, atPosition position: Int? = nil) {
        if let documentIndex = documents.firstIndex(where: { $0.id == document.id }) {
            // Special handling for Tasks document
            if documents[documentIndex].isTaskDocument {
                if documents[documentIndex].content.isEmpty {
                    documents[documentIndex].content = "• \(card.content)"
                } else {
                    documents[documentIndex].content += "\n• \(card.content)"
                }
            } else {
                // Regular document
                if let position = position {
                    // Insert at position
                    let content = documents[documentIndex].content
                    let index = content.index(content.startIndex, offsetBy: min(position, content.count))
                    documents[documentIndex].content.insert(contentsOf: card.content, at: index)
                } else {
                    // Append to the end
                    if documents[documentIndex].content.isEmpty {
                        documents[documentIndex].content = card.content
                    } else {
                        documents[documentIndex].content += "\n\n\(card.content)"
                    }
                }
            }
            
            // Remove the card
            cards.removeAll(where: { $0.id == card.id })
        }
    }
    
    // Delete a document and unassign all its cards
    func deleteDocument(_ document: Document) {
        // Unassign all cards from this document
        for i in 0..<cards.count {
            if cards[i].documentID == document.id {
                cards[i].documentID = nil
            }
        }
        
        // Remove the document
        documents.removeAll(where: { $0.id == document.id })
    }
}
