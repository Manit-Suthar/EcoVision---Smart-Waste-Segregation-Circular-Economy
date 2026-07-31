# EcoVision - Smart Waste Segregation & Circular Economy

EcoVision is an intelligent computer vision system designed to classify waste categories and recommend nearby specialized collection or recycling points. 

## Offline-First Architecture

The EcoVision platform is built with an **offline-first philosophy**. 
- **AI Inference** runs entirely on-device via ONNX Runtime (Mobile & Web). Images never leave your device.
- **Core Functionality** works completely without an internet connection.
- **Shared Intelligence**: The AI models and knowledge base are statically bundled into the app/web clients. No backend servers required.

## Monorepo Structure

EcoVision is structured as a scalable monorepo, cleanly separating the shared ML assets from the platform-specific UI clients.

```text
EcoVision/
├── mobile/                 # Flutter Mobile App (Android/iOS)
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
├── web/                    # Progressive Web App (PWA)
│   ├── index.html
│   ├── script.js
│   └── styles.css
└── shared/                 # Cross-platform knowledge base & ML models
    ├── ecovision_model.onnx
    ├── labels.json
    ├── waste_database.json
    └── icons/
```

## Running the Web Version
1. Start a local server in the root of the repository:
```bash
python3 -m http.server 8000
```
2. Open `http://localhost:8000/web/` in your browser.

## Running the Mobile App
1. Ensure Flutter is installed and configured.
2. Navigate to the `mobile` directory and run:
```bash
cd mobile
flutter run
```

## Segregation Categories (MoEFCC Guidelines)
We enforce the Ministry of Environment (MoEFCC) 4-stream color-coded system:
- 🟢 **Green Bin**: Wet/Organic Waste
- 🔵 **Blue Bin**: Dry/Recyclable Waste
- 🔴 **Red Bin**: Sanitary Waste
- ⚫ **Black Bin**: Hazardous/E-waste

The AI currently categorizes items into 9 primary classes (e.g. Battery, Paper, Plastic, Organic, Metal) and maps them dynamically to their respective Government bins, calculating accurate Estimated Scrap Value and Gamified Green Scores.
