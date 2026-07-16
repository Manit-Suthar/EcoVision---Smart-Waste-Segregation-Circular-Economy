# EcoVision - Smart Waste Segregation & Circular Economy

EcoVision is an intelligent computer vision system designed to classify waste categories and recommend nearby specialized collection or recycling points. This project aims to create significant civic impact by streamlining waste segregation and promoting a circular economy.

## System Architecture

The application is structured with a decoupled frontend and backend:
- **Frontend:** A responsive, glassmorphism-styled single-page application (SPA) built with vanilla HTML, CSS, and JavaScript. It features live webcam integration for immediate image capture.
- **Backend:** A lightweight Python Flask server.
- **Machine Learning:** A MobileNetV2 deep learning model trained to classify waste into 9 distinct categories.
- **Geolocation Services:** Dynamic Google Maps integration to route users to the nearest appropriate disposal facility based on the AI classification.

## Features
- **AI Waste Detection:** Upload or capture images of waste to receive instant classification.
- **Disposal Intelligence:** Provides precise information on whether the waste is recyclable, its category (Wet/Dry/Hazardous), and the appropriate bin.
- **Location Routing:** Uses the user's GPS coordinates to dynamically generate targeted Google Maps queries (e.g., locating the nearest "e-waste recycling facility" or "compost center").
- **Live Camera Integration:** Mobile-friendly webcam support for immediate photo capture.

## Prerequisites

- Python 3.9+
- Modern Web Browser (Chrome, Firefox, Safari)

## Local Setup Instructions

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/Manit-Suthar/EcoVision---Smart-Waste-Segregation-Circular-Economy.git
   cd EcoVision---Smart-Waste-Segregation-Circular-Economy
   ```

2. **Download the AI Model:**
   *Note: The trained model exceeds GitHub's file size limits and is excluded from version control.*
   - Obtain the `mobilenetv2_waste_classification.h5` file.
   - Place the `.h5` file directly in the root directory of this repository.

3. **Set Up the Virtual Environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

4. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

5. **Run the Backend Server:**
   ```bash
   python app.py
   ```
   The Flask API will start running on `http://127.0.0.1:5000`.

6. **Serve the Frontend:**
   In a separate terminal window, serve the frontend files:
   ```bash
   python3 -m http.server 8000
   ```
   Navigate to `http://localhost:8000` in your web browser.

## Classification Categories
The model is capable of classifying the following waste types:
- E-waste
- Automobile Wastes
- Battery Waste
- Glass Waste
- Light Bulbs
- Metal Waste
- Organic Waste
- Paper Waste
- Plastic Waste
