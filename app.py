import os
import io
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image
from PIL import Image

app = Flask(__name__)
CORS(app)

# Load Model
print("Loading model...")
try:
    model = load_model("mobilenetv2_waste_classification.h5", compile=False)
    print("Model loaded successfully.")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

# Class labels mapped to exactly what the model outputs
CLASS_LABELS = {
    0: 'E-waste', 1: 'automobile wastes', 2: 'battery waste', 
    3: 'glass waste', 4: 'light bulbs', 5: 'metal waste', 
    6: 'organic waste', 7: 'paper waste', 8: 'plastic waste'
}

# Waste info database
WASTE_INFO_DB = {
    "E-waste": {
        "Category": "E-Waste", "Recyclable": "Yes", "Dispose In": "E-Waste Drop-off", 
        "google_query": "e-waste+recycling+facility"
    },
    "automobile wastes": {
        "Category": "Automotive Waste", "Recyclable": "Yes", "Dispose In": "Hazardous Waste Facility", 
        "google_query": "automotive+waste+disposal+facility"
    },
    "battery waste": {
        "Category": "Hazardous Waste", "Recyclable": "Yes", "Dispose In": "Battery Drop-off", 
        "google_query": "battery+recycling+drop-off"
    },
    "glass waste": {
        "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Green/Glass Bin", 
        "google_query": "glass+recycling+center"
    },
    "light bulbs": {
        "Category": "Hazardous Waste", "Recyclable": "Yes", "Dispose In": "Special Drop-off", 
        "google_query": "light+bulb+recycling"
    },
    "metal waste": {
        "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Blue Bin", 
        "google_query": "scrap+metal+recycling"
    },
    "organic waste": {
        "Category": "Wet Waste", "Recyclable": "No (Compostable)", "Dispose In": "Green/Compost Bin", 
        "google_query": "compost+facility"
    },
    "paper waste": {
        "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Blue Bin", 
        "google_query": "paper+recycling+center"
    },
    "plastic waste": {
        "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Blue Bin", 
        "google_query": "plastic+recycling+center"
    }
}

@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({"error": "Model not loaded"}), 500
        
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
        
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    try:
        # Read the image
        img_bytes = file.read()
        img = Image.open(io.BytesIO(img_bytes)).convert('RGB')
        img = img.resize((224, 224))
        
        # Preprocess
        x = image.img_to_array(img)
        x = np.expand_dims(x, axis=0)
        x = x / 255.0  # Rescaling as per training script
        
        # Predict
        predictions = model.predict(x)
        predicted_class_index = int(np.argmax(predictions[0]))
        confidence = float(predictions[0][predicted_class_index])
        
        predicted_class_name = CLASS_LABELS.get(predicted_class_index, "Unknown")
        waste_info = WASTE_INFO_DB.get(predicted_class_name, {})
        
        return jsonify({
            "class_name": predicted_class_name.title(), # Title case for UI
            "confidence": f"{confidence * 100:.1f}%",
            "waste_info": waste_info
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)
