# EcoVision - Smart Waste Segregation & Circular Economy

EcoVision is an intelligent computer vision system designed to classify waste categories and recommend nearby specialized collection or recycling points. The application runs entirely in the browser — no backend server or API required.

## System Architecture


The application is a fully client-side, serverless single-page application (SPA):

- **Frontend:** Responsive, glassmorphism-styled interface built with vanilla HTML, CSS, and JavaScript.
- **Machine Learning:** A MobileNetV2 model exported to ONNX format, running locally in the browser via ONNX Runtime Web, with no server round-trips. TensorFlow.js is utilized for image preprocessing.
- **Camera Integration:** Live webcam support via the `getUserMedia` API, with automatic fallback to file upload. Prioritizes the rear camera on mobile devices.
- **Geolocation Services:** Dynamic Google Maps integration that routes users to the nearest appropriate disposal facility based on the AI classification result.

## Features

- **Offline AI Inference:** The ONNX model loads once and runs entirely on-device. No data is sent to any server.
- **10-Class Waste Classification:** Identifies E-waste, Automobile Waste, Battery Waste, Glass Waste, Light Bulbs, Metal Waste, Organic Waste, Paper Waste, Plastic Waste, and a Non-Waste background class.
- **Disposal Intelligence:** Reports waste category (Wet/Dry/Hazardous), recyclability, and the appropriate bin type.
- **Targeted Location Routing:** Uses the device GPS to generate specific Google Maps queries (e.g., "battery recycling drop-off") rather than generic recycling searches.
- **Live Camera Capture:** Mobile-ready camera tab for immediate photo capture without leaving the browser.

## Getting the AI Model

The ONNX model weight file (`ecovision_model.onnx`) may exceed GitHub's file size limits and be excluded from version control (check if it exists). To run the application locally you must obtain this file if it is not present in the repository.

**To regenerate the model from scratch:**

1. Open the notebook used to train the original MobileNetV2 model.
2. Download or export the model to ONNX format (`ecovision_model.onnx`).
3. Place `ecovision_model.onnx` in the root of this repository.

## Running Locally

Since the application is entirely static, it only requires a local HTTP server (browsers block local file access for security reasons):

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000` in your browser.

## File Structure

```
waste-segregation/
├── index.html              # Main application page
├── styles.css              # Full design system and component styles
├── script.js               # ONNX inference, TF.js preprocessing, camera, and maps logic
├── sw.js                   # Service Worker for PWA
├── manifest.json           # PWA manifest
├── ecovision_model.onnx    # ONNX model (not committed to Git if too large)
└── README.md
```

## Classification Categories

| Class | Category | Recyclable | Bin |
|---|---|---|---|
| E-waste | E-Waste | Yes | E-Waste Drop-off |
| Non_Waste | - | - | - |
| Automobile Wastes | Automotive Waste | Yes | Hazardous Waste Facility |
| Battery Waste | Hazardous Waste | Yes | Battery Drop-off |
| Glass Waste | Dry Waste | Yes | Green/Glass Bin |
| Light Bulbs | Hazardous Waste | Yes | Special Drop-off |
| Metal Waste | Dry Waste | Yes | Blue Bin |
| Organic Waste | Wet Waste | No (Compostable) | Green/Compost Bin |
| Paper Waste | Dry Waste | Yes | Blue Bin |
| Plastic Waste | Dry Waste | Yes | Blue Bin |
