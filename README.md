# iOS RAG Chatbot

An iOS chatbot application with RAG system, voice capabilities, and on-device memory storage.

## Features

- On-device RAG (Retrieval-Augmented Generation) system
- Voice chat capabilities (STT and TTS)
- Structured storage for chat history and user data
- Vector storage for semantic search

## Architecture

### Storage
- Vector Database for RAG using Apple's Natural Language framework
- Core Data for structured storage

### Voice Processing
- Speech framework for STT
- AVSpeechSynthesizer for TTS

## Project Structure

```
RAGChatbot/
├── Sources/
│   ├── App/
│   │   └── RAGChatbotApp.swift
│   ├── Views/
│   │   └── ContentView.swift
│   ├── Models/
│   │   └── ChatMessage.swift
│   └── Services/
│       ├── StorageService.swift
│       └── VoiceService.swift
└── Resources/
    └── Assets.xcassets
```

## Setup

1. Clone the repository
2. Open RAGChatbot.xcodeproj in Xcode
3. Build and run

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.0+