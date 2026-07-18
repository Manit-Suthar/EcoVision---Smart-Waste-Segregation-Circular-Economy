# EcoVision - Smart Waste Segregation & Circular Economy

EcoVision is an intelligent computer vision system designed to classify waste categories and recommend nearby specialized collection or recycling points. The application runs entirely in the browser — no backend server or API required.

## System Architecture

The application is a fully client-side, serverless single-page application (SPA):

- **Frontend:** Responsive, glassmorphism-styled interface built with vanilla HTML, CSS, and JavaScript.
- **Machine Learning:** A MobileNetV2 model converted to TensorFlow.js format and quantized to uint8, running locally in the browser with no server round-trips.
- **Camera Integration:** Live webcam support via the `getUserMedia` API, with automatic fallback to file upload. Prioritizes the rear camera on mobile devices.
- **Geolocation Services:** Dynamic Google Maps integration that routes users to the nearest appropriate disposal facility based on the AI classification result.

## Features

- **Offline AI Inference:** The 34MB TensorFlow.js model loads once and runs entirely on-device. No data is sent to any server.
- **9-Class Waste Classification:** Identifies E-waste, Automobile Waste, Battery Waste, Glass Waste, Light Bulbs, Metal Waste, Organic Waste, Paper Waste, and Plastic Waste.
- **Disposal Intelligence:** Reports waste category (Wet/Dry/Hazardous), recyclability, and the appropriate bin type.
- **Targeted Location Routing:** Uses the device GPS to generate specific Google Maps queries (e.g., "battery recycling drop-off") rather than generic recycling searches.
- **Live Camera Capture:** Mobile-ready camera tab for immediate photo capture without leaving the browser.

## Getting the AI Model

The TensorFlow.js model weight files (`.bin`) exceed GitHub's file size limits and are excluded from version control. To run the application locally you must obtain these files separately.

**To regenerate the model from scratch:**

1. Open the Kaggle notebook used to train the original MobileNetV2 model.
2. Download the output file `mobilenetv2_waste_classification.h5`.
3. Open a fresh Google Colab notebook and run the conversion script (see `model_conversion_guide.md` for the full script).
4. Download the resulting `tfjs_model_final.zip`.
5. Unzip it and place the `tfjs_model_final/` folder in the root of this repository.

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
├── script.js               # TensorFlow.js inference, camera, and maps logic
├── tfjs_model_final/       # TensorFlow.js model (model.json + .bin weight shards)
│   ├── model.json          # Model graph and weight manifest
│   └── group1-shard*.bin   # Quantized weight files (not committed to Git)
└── README.md
```

## Classification Categories

| Class | Category | Recyclable | Bin |
|---|---|---|---|
| E-waste | E-Waste | Yes | E-Waste Drop-off |
| Automobile Wastes | Automotive Waste | Yes | Hazardous Waste Facility |
| Battery Waste | Hazardous Waste | Yes | Battery Drop-off |
| Glass Waste | Dry Waste | Yes | Green/Glass Bin |
| Light Bulbs | Hazardous Waste | Yes | Special Drop-off |
| Metal Waste | Dry Waste | Yes | Blue Bin |
| Organic Waste | Wet Waste | No (Compostable) | Green/Compost Bin |
| Paper Waste | Dry Waste | Yes | Blue Bin |
| Plastic Waste | Dry Waste | Yes | Blue Bin |
