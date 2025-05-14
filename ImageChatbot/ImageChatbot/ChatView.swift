//
//  ChatView.swift
//  ImageChatbot
//
//  Created by Lucas Knight on 5/13/25.
//

import SwiftUI

struct ChatView: View {
    @State private var userMessage: String = ""
    @State private var images: [NSImage] = []
    @State private var messages: [(String, Bool, [NSImage])] = []
    @State private var isTyping: Bool = false
    @State private var showingAlert: Bool = false

    private let networkManager = NetworkManager()
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages, id: \.0) { message, isUserMessage, images in
                    HStack {
                        if !isUserMessage { // MARK: AI response
                            VStack(alignment: .leading) {
                                Text(message)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .frame(maxWidth: 300, alignment: .leading)
                            }
                            Spacer()
                        } else { // MARK: User message
                            Spacer()
                            VStack(alignment: .trailing) {
                                if !images.isEmpty {
                                    HStack {
                                        // TODO: Make Image Preview View
                                        ForEach(images, id: \.self) { image in
                                            Image(nsImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                                .padding(4)
                                        }
                                    }
                                }
                                Text(message)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                    .frame(maxWidth: 300, alignment: .trailing)
                                // TODO: Make Text ViewModifier for reuseability
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                // TODO: Make Typing/Response View using an animated  "three dots" or "ellipsis"
                HStack {
                    if isTyping {
                        Text("Typing...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(5)
                            .opacity(0.7)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.bottom, 5)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            
            VStack {
                if !images.isEmpty {
                    HStack {
                        ForEach(images, id: \.self) { image in
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .padding(4)
                        }
                    }
                    .padding()
                }
                
                TextField("Enter your message", text: $userMessage)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 8)
                
                HStack {
                    Button {
                        selectImage()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .frame(width: 600)
        .alert(Text("Too Many Images"), isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can only upload up to 4 images. Please remove some images to upload more.")
        }
        .padding()
        // TODO: Fix Alert Image Bug
    }
    
    // TODO: Move into ViewModel logic
    private func selectImage() {
        if images.count >= 4 {
            self.showingAlert = true
            return
        }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["jpg", "jpeg", "png", "gif", "webp"]
        
        if panel.runModal() == .OK {
            if panel.urls.count + images.count > 4 {
                self.showingAlert = true
                return
            }
            
            let remainingSlots = 4 - images.count
            let selectedImages = panel.urls.prefix(remainingSlots).map { url -> NSImage in
                return NSImage(contentsOf: url) ?? NSImage()
            }
            images.append(contentsOf: selectedImages)
        }
    }

    private func sendMessage() {
        if !userMessage.isEmpty {
            let message = self.userMessage
            let images = self.images
            
            messages.append((message, true, images))
            self.isTyping = true
            
            // Call OpenAI API with the question and images
            Task {
                do {
                    let aiResponse = try await networkManager.queryImageQuestion(question: message, images: images)
                    messages.append((aiResponse, false, []))
                } catch {
                    messages.append(("Error: \(error.localizedDescription)", false, []))
                }
                
                self.isTyping = false
            }
            
            self.userMessage = ""
            self.images = []
        }
    }
}
