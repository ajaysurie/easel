# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Easel is an AI-powered AR home design application for iOS that transforms iPhones/iPads into complete scan-to-build pipelines for home renovation projects. The app allows users to scan rooms, generate AR designs from natural language prompts, and export professional documentation.

## Current State

This repository is in the initial planning phase and currently contains only:
- `easel-prd-enhanced.md` - Comprehensive Product Requirements Document with technical specifications

**No code implementation exists yet.** All development work will be net-new implementation based on the PRD specifications.

## Architecture Overview

Based on the PRD, the system will consist of:

### iOS Application Structure
```
EaselApp/
├── Core/
│   ├── ARSessionManager.swift - ARKit session management
│   ├── SceneReconstruction/ - Room scanning and mesh generation
│   └── Calibration/ - Scale calibration using reference objects
├── Features/
│   ├── Scanning/ - Room capture workflow
│   ├── Design/ - AI design generation
│   ├── Editing/ - Object interaction and manipulation
│   └── Export/ - PDF/3D model export
├── Services/
│   ├── AIService.swift - Backend AI integration
│   ├── CloudSyncService.swift - iCloud storage
│   └── CommerceService.swift - Product pricing
└── Resources/
    ├── Models/ - 3D assets
    └── Shaders/ - Metal rendering shaders
```

### Backend Services
```
easel-backend/
├── services/
│   ├── ai_design/ - AI design generation service
│   ├── code_compliance/ - Building code RAG engine
│   └── commerce/ - Price aggregation APIs
├── infrastructure/ - Terraform/K8s deployment
└── shared/ - Common schemas and utilities
```

## Key Technical Requirements

### iOS Development
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **Minimum iOS**: 15.0
- **Required Frameworks**: ARKit 6.0, RealityKit 2.0, CoreML 7.0

### Core Dependencies
- ARKit for room scanning and plane detection
- CoreData + CloudKit for data persistence and sync
- Firebase for authentication
- Metal for optimized 3D rendering

### Backend Stack
- **Python**: 3.11+ (AI services)
- **Node.js**: 20.0+ (build tools)
- **FastAPI** for REST APIs
- **PyTorch + Transformers** for AI models
- **Docker** for containerization

## Development Workflow

### Initial Setup Commands
```bash
# iOS project setup (when created)
open EaselApp.xcodeproj
pod install  # if using CocoaPods
# or
xcodebuild -resolvePackageDependencies  # for SPM

# Backend setup (when created)
cd easel-backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Build Commands
```bash
# iOS build
xcodebuild -scheme EaselApp -destination 'platform=iOS Simulator,name=iPhone 15' build

# Backend services
docker-compose up -d
```

### Testing
```bash
# iOS tests
xcodebuild test -scheme EaselApp -destination 'platform=iOS Simulator,name=iPhone 15'

# Backend tests
pytest tests/ -v
```

## Performance Targets

Based on PRD specifications:
- **AR Rendering**: 30+ FPS on iPhone 12+
- **AI Generation**: <4s prompt-to-render (P95)
- **Scanning Accuracy**: ≤5cm dimensional accuracy
- **Memory Usage**: <350MB during AR sessions

## Key Implementation Patterns

### AR Session Management
- Use ARKit's scene reconstruction for universal camera support
- Implement temporal filtering for depth data stability
- Credit card calibration for real-world scale reference

### AI Integration
- Compress mesh data to <10k vertices before API calls
- Implement object grounding to detected planes
- Use vector search for similar object recommendations

### Performance Optimization
- Level-of-detail (LOD) management for 3D objects
- Texture compression and memory budgeting
- Frustum culling for off-screen objects

## API Integration

### Backend Endpoints
- `POST /ai/design` - Generate AR designs from prompts
- `POST /ai/code` - Building code compliance queries
- `POST /commerce/prices` - Multi-vendor price aggregation

### Authentication
- Sign in with Apple for user authentication
- Firebase for token management
- Custom JWT tokens for backend services

## Data Models

### Core Entities
- **Project**: Room scans with associated designs
- **ProjectVersion**: Design iteration history (max 10)
- **Measurement**: Point-to-point measurements with snapping
- **SceneGraph**: 3D object hierarchy with transforms

### Storage Strategy
- CoreData for local persistence
- CloudKit for cross-device sync
- Compressed mesh storage for bandwidth efficiency

## Export Capabilities

- **PDF Generation**: Floor plans, elevations, 3D renders
- **3D Model Export**: GLB format with embedded textures
- **Bill of Materials**: Itemized list with pricing and SKUs
- **Code Compliance**: Flagged warnings for building violations

## Important Development Notes

- Never manually edit Core Data models - use Xcode's data model editor
- Implement proper error handling for AR session failures
- Use Metal Performance Shaders for compute-intensive operations
- Follow Apple's ARKit best practices for session configuration
- Implement proper camera permission handling and user education

## Security Considerations

- Secure API key storage using Keychain Services
- Validate all user inputs for AI prompt injection
- Implement proper SSL certificate pinning
- Use App Transport Security (ATS) for network communications