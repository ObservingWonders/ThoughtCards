//
//  DocumentDetailView.swift
//  ThoughtCards
//
//  Created by Kevin Oberhausen on 4/18/25.
//


import SwiftUI

struct DocumentDetailView: View {
    @Binding var document: Document?
    var appData: AppData
    @State private var documentContent: String = ""
    @State private var showDeleteConfirmation = false
    @State private var cursorPosition: Int = 0
    @State private var textViewId = UUID() // Used to force NSTextView refresh
    
    var body: some View {
        VStack {
            // Document content
            TextEditorWithCursor(text: $documentContent, cursorPosition: $cursorPosition)
                .padding()
                .id(textViewId) // Force view refresh when needed
                .onChange(of: documentContent) { newValue in
                    if let index = appData.documents.firstIndex(where: { $0.id == document?.id }) {
                        appData.documents[index].content = newValue
                    }
                }
                .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                    handleDropOnDocument(providers)
                    return true
                }
        }
        .navigationTitle(document?.name ?? "Document")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    document = nil
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(document?.isTaskDocument == true) // Can't delete the default Tasks document
            }
        }
        .onAppear {
            documentContent = document?.content ?? ""
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Document"),
                message: Text("Are you sure you want to delete this document? All associated cards will be unassigned."),
                primaryButton: .destructive(Text("Delete")) {
                    if let doc = document {
                        appData.deleteDocument(doc)
                        document = nil
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Handle dropping a card onto the document content
    private func handleDropOnDocument(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { data, error in
                    if let cardID = data as? String,
                       let uuid = UUID(uuidString: cardID),
                       let card = appData.cards.first(where: { $0.id == uuid }),
                       let doc = document {
                        
                        DispatchQueue.main.async {
                            // Use cursor position for insertion
                            if let docIndex = appData.documents.firstIndex(where: { $0.id == doc.id }) {
                                if doc.isTaskDocument {
                                    // For task documents, always append as a new bullet
                                    appData.moveCardContentToDocument(card, document: doc)
                                } else {
                                    // For regular documents, insert at cursor position
                                    appData.moveCardContentToDocument(card, document: doc, atPosition: cursorPosition)
                                }
                                documentContent = appData.documents[docIndex].content
                                textViewId = UUID() // Force refresh to update
                            }
                        }
                    }
                }
            }
        }
    }
}

// Custom TextEditor that tracks cursor position
struct TextEditorWithCursor: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Only update if the text has actually changed
        if textView.string != text {
            textView.string = text
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorWithCursor
        
        init(_ parent: TextEditorWithCursor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            
            // Update cursor position
            if let selectedRange = textView.selectedRanges.first as? NSRange {
                parent.cursorPosition = selectedRange.location
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if let selectedRange = textView.selectedRanges.first as? NSRange {
                parent.cursorPosition = selectedRange.location
            }
        }
    }
}
