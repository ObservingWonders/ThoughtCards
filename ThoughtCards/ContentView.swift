//
//  ContentView.swift
//  ThoughtCards
//
//  Created by Kevin Oberhausen on 4/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appData = AppData()
    @State private var newCardText = ""
    @State private var selectedDocument: Document? = nil
    @State private var newDocumentName = ""
    @State private var showingNewDocumentDialog = false
    @State private var draggedCard: Card? = nil
    
    // Grid layout for documents
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            // Main content area: Document grid or document content
            if selectedDocument == nil {
                // Document grid view
                VStack {
                    // Grid of documents
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            // Add new document button
                            DocumentGridItem(icon: "plus.circle", title: "New Document", action: {
                                showingNewDocumentDialog = true
                            })
                            .transition(.scale)
                            
                            // Existing documents
                            ForEach(appData.documents) { document in
                                DocumentGridItem(
                                    icon: document.isTaskDocument ? "checklist" : "doc.text",
                                    title: document.name,
                                    action: {
                                        withAnimation {
                                            selectedDocument = document
                                        }
                                    }
                                )
                                .transition(.scale)
                                .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                                    handleDrop(providers, onDocument: document)
                                    return true
                                }
                            }
                        }
                        .padding()
                        .animation(.spring(), value: appData.documents.count)
                    }
                }
                .navigationTitle("Documents")
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            showingNewDocumentDialog = true
                        }) {
                            Label("New Document", systemImage: "plus")
                        }
                    }
                }
                .frame(minWidth: 400)
            } else {
                // Document detail view
                DocumentDetailView(document: $selectedDocument, appData: appData)
                    .transition(.move(edge: .trailing))
            }
            
            // Card sidebar
            VStack {
                // Card input area
                HStack {
                    TextField("Capture a thought...", text: $newCardText, onCommit: {
                        if !newCardText.isEmpty {
                            withAnimation {
                                appData.addCard(content: newCardText)
                                newCardText = ""
                            }
                        }
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        if !newCardText.isEmpty {
                            withAnimation {
                                appData.addCard(content: newCardText)
                                newCardText = ""
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(newCardText.isEmpty)
                }
                .padding()
                
                // Card stream
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let relevantCards = selectedDocument == nil
                            ? appData.unassignedCards()
                            : appData.cardsForDocument(documentID: selectedDocument!.id)
                            
                        ForEach(relevantCards) { card in
                            CardView(card: card, appData: appData, selectedDocument: $selectedDocument, draggedCard: $draggedCard)
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .padding(.bottom)
                    .animation(.spring(), value: appData.cards.map { $0.id })
                }
            }
            .frame(width: 300)
            .background(Color(.systemGray6))
        }
        .sheet(isPresented: $showingNewDocumentDialog) {
            NewDocumentView(isPresented: $showingNewDocumentDialog, appData: appData)
        }
    }
    
    // Handle drag and drop of cards onto documents
    private func handleDrop(_ providers: [NSItemProvider], onDocument document: Document) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { data, error in
                    if let cardID = data as? String,
                       let uuid = UUID(uuidString: cardID),
                       let card = appData.cards.first(where: { $0.id == uuid }) {
                        
                        DispatchQueue.main.async {
                            withAnimation {
                                if document.isTaskDocument {
                                    appData.moveCardContentToDocument(card, document: document)
                                } else {
                                    appData.assignCard(card, toDocumentWithID: document.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// Enhanced Card view component
struct CardView: View {
    let card: Card
    let appData: AppData
    @Binding var selectedDocument: Document?
    @Binding var draggedCard: Card?
    @State private var showingDocumentMenu = false
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(card.content)
                .font(.body)
                .padding(8)
            
            HStack {
                Text(card.creationDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if selectedDocument != nil {
                    // If we're in a document view, show document menu button
                    Button(action: {
                        showingDocumentMenu = true
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .popover(isPresented: $showingDocumentMenu) {
                        VStack(alignment: .leading) {
                            Button("Back to Idea Capture") {
                                withAnimation {
                                    appData.unassignCard(card)
                                }
                                showingDocumentMenu = false
                            }
                            .padding(.vertical, 5)
                            
                            Divider()
                            
                            ForEach(appData.documents) { doc in
                                if doc.id != selectedDocument?.id {
                                    Button(doc.name) {
                                        withAnimation {
                                            appData.assignCard(card, toDocumentWithID: doc.id)
                                        }
                                        showingDocumentMenu = false
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                        }
                        .padding()
                        .frame(width: 200)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: isDragging ? 5 : 1)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .animation(.spring(response: 0.3), value: isDragging)
        .onDrag {
            // Make card draggable with visual feedback
            self.isDragging = true
            self.draggedCard = card
            
            // Reset isDragging after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isDragging = false
            }
            
            return NSItemProvider(object: card.id.uuidString as NSString)
        }
    }
}

// Enhanced Document grid item component
struct DocumentGridItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .padding()
                    .foregroundColor(isHovered ? .accentColor : .primary)
                
                Text(title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 120, height: 120)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .shadow(radius: isHovered ? 5 : 1)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Enhanced dialog for creating a new document
struct NewDocumentView: View {
    @Binding var isPresented: Bool
    var appData: AppData
    @State private var documentName = ""
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack {
            Text("Create New Document")
                .font(.headline)
                .padding()
            
            TextField("Document Name", text: $documentName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .focused($isNameFieldFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNameFieldFocused = true
                    }
                }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Create") {
                    if !documentName.isEmpty {
                        withAnimation {
                            appData.addDocument(name: documentName)
                        }
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(documentName.isEmpty)
            }
            .padding()
        }
        .frame(width: 300)
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
