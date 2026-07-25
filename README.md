# EcoVision - Smart Waste Segregation & Circular Economy

EcoVision is an intelligent computer vision system designed to classify waste categories and recommend nearby specialized collection or recycling points. 

## Offline-First Architecture

The EcoVision platform is built with an **offline-first philosophy**. 
- **AI Inference** runs entirely on-device via ONNX Runtime Web. Images never leave your device.
- **Core Functionality** works completely without an internet connection.
- **Cloud Services** (like analytics and future user rewards) are strictly optional enhancements. If you are offline, analytics events are queued locally and synchronized automatically when connectivity is restored.

## Monorepo Structure

EcoVision is structured as a scalable monorepo to support future mobile applications and backend services without duplicating business logic.

```text
EcoVision/
├── web/                    # The Progressive Web App (PWA)
│   ├── index.html
│   ├── script.js           # Core logic and TF.js preprocessing
│   ├── api.js              # Offline sync queue and API layer
│   ├── sw.js               # Service Worker for offline caching
│   ├── ecovision_model.onnx # Local ONNX model
│   └── ...
├── shared/                 # Cross-platform knowledge base
│   ├── labels.json         # AI class labels
│   └── waste_database.json # Recycling rules and bin mappings
├── backend/                # Optional Node.js/Express analytics backend
│   ├── server.js
│   └── package.json
└── mobile/                 # Reserved for future Android/iOS app
```

## Running Locally

Because we use a monorepo structure with shared data files, you should serve the application from the root directory.

1. Start a local server in the root of the repository:
```bash
python3 -m http.server 8000
```
2. Open `http://localhost:8000/web/` in your browser.

## Backend Development (Optional)

The `backend/` directory contains an Express stub designed for optional analytics. 
To run the backend:
```bash
cd backend
npm install
node server.js
```
The backend runs on port 3000 by default and exposes an `/api/analytics` endpoint.

## Classification Categories

We currently detect and categorize the following waste types:
- E-waste
- Automobile Wastes
- Battery Waste
- Glass Waste
- Light Bulbs
- Metal Waste
- Organic Waste
- Paper Waste
- Plastic Waste
