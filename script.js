document.addEventListener('DOMContentLoaded', () => {
    // UI Elements
    const tabUpload = document.getElementById('tabUpload');
    const tabCamera = document.getElementById('tabCamera');
    const uploadArea = document.getElementById('uploadArea');
    const cameraArea = document.getElementById('cameraArea');

    const uploadContent = document.getElementById('uploadContent');
    const fileInput = document.getElementById('fileInput');
    const imagePreview = document.getElementById('imagePreview');
    const predictBtn = document.getElementById('predictBtn');

    const videoElement = document.getElementById('videoElement');
    const canvasElement = document.getElementById('canvasElement');
    const captureBtn = document.getElementById('captureBtn');

    const loadingOverlay = document.getElementById('loadingOverlay');
    const errorMsg = document.getElementById('errorMsg');
    const errorText = document.getElementById('errorText');
    const resultsSection = document.getElementById('resultsSection');

    // Result fields
    const predClass = document.getElementById('predClass');
    const predConf = document.getElementById('predConf');
    const predTime = document.getElementById('predTime');
    const infoCategory = document.getElementById('infoCategory');
    const infoRecyclable = document.getElementById('infoRecyclable');
    const infoBin = document.getElementById('infoBin');

    const googleMapsBtn = document.getElementById('googleMapsBtn');

    let selectedFile = null;
    let cameraStream = null;
    let model = null;

    // --- Model & Database ---
    const CLASS_LABELS = [
        'E-waste', 'automobile wastes', 'battery waste',
        'glass waste', 'light bulbs', 'metal waste',
        'organic waste', 'paper waste', 'plastic waste'
    ];

    const WASTE_INFO_DB = {
        "E-waste": { "Category": "E-Waste", "Recyclable": "Yes", "Dispose In": "E-Waste Drop-off", "google_query": "e-waste+recycling+facility" },
        "automobile wastes": { "Category": "Automotive Waste", "Recyclable": "Yes", "Dispose In": "Hazardous Waste Facility", "google_query": "automotive+waste+disposal+facility" },
        "battery waste": { "Category": "Hazardous Waste", "Recyclable": "Yes", "Dispose In": "Battery Drop-off", "google_query": "battery+recycling+drop-off" },
        "glass waste": { "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Green/Glass Bin", "google_query": "glass+recycling+center" },
        "light bulbs": { "Category": "Hazardous Waste", "Recyclable": "Yes", "Dispose In": "Special Drop-off", "google_query": "light+bulb+recycling" },
        "metal waste": { "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Blue Bin", "google_query": "scrap+metal+recycling" },
        "organic waste": { "Category": "Wet Waste", "Recyclable": "No (Compostable)", "Dispose In": "Green/Compost Bin", "google_query": "compost+facility" },
        "paper waste": { "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Blue Bin", "google_query": "paper+recycling+center" },
        "plastic waste": { "Category": "Dry Waste", "Recyclable": "Yes", "Dispose In": "Blue Bin", "google_query": "plastic+recycling+center" }
    };

    async function initModel() {
        try {
            console.log("Loading TensorFlow.js model...");
            model = await tf.loadGraphModel('./tfjs_model_final/model.json');
            console.log("Model loaded successfully!");
        } catch (e) {
            console.error("Error loading model:", e);
            showError("Failed to load AI model. Ensure tfjs_model_final folder is present.");
        }
    }

    // Start model loading in background
    initModel();

    // --- Tabs Logic ---
    tabUpload.addEventListener('click', () => {
        tabUpload.classList.add('active');
        tabCamera.classList.remove('active');
        uploadArea.classList.remove('hidden');
        cameraArea.classList.add('hidden');
        stopCamera();
    });

    tabCamera.addEventListener('click', () => {
        tabCamera.classList.add('active');
        tabUpload.classList.remove('active');
        cameraArea.classList.remove('hidden');
        uploadArea.classList.add('hidden');
        startCamera();
    });

    // --- Upload Handlers ---
    uploadArea.addEventListener('click', () => {
        if (!imagePreview.src || imagePreview.classList.contains('hidden')) {
            fileInput.click();
        } else {
            fileInput.click();
        }
    });

    uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('dragover');
    });

    uploadArea.addEventListener('dragleave', () => {
        uploadArea.classList.remove('dragover');
    });

    uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            handleFile(e.dataTransfer.files[0]);
        }
    });

    fileInput.addEventListener('change', (e) => {
        if (e.target.files && e.target.files.length > 0) {
            handleFile(e.target.files[0]);
        }
    });

    function handleFile(file) {
        if (!file.type.startsWith('image/')) {
            showError("Please upload a valid image file.");
            return;
        }

        selectedFile = file;
        const reader = new FileReader();
        reader.onload = (e) => {
            imagePreview.src = e.target.result;
            imagePreview.onload = () => {
                imagePreview.classList.remove('hidden');
                uploadContent.classList.add('hidden');
                predictBtn.disabled = false;
            };
        };
        reader.readAsDataURL(file);

        resultsSection.classList.add('hidden');
        errorMsg.classList.add('hidden');
    }

    // --- Camera Handlers ---
    async function startCamera() {
        try {
            cameraStream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: "environment" }
            });
            videoElement.srcObject = cameraStream;
        } catch (err) {
            console.error("Camera error:", err);
            showError("Camera access denied or unavailable.");
            tabUpload.click(); // fallback
        }
    }

    function stopCamera() {
        if (cameraStream) {
            cameraStream.getTracks().forEach(track => track.stop());
            cameraStream = null;
        }
    }

    captureBtn.addEventListener('click', () => {
        if (!cameraStream) return;

        canvasElement.width = videoElement.videoWidth;
        canvasElement.height = videoElement.videoHeight;

        const ctx = canvasElement.getContext('2d');
        ctx.drawImage(videoElement, 0, 0, canvasElement.width, canvasElement.height);

        canvasElement.toBlob((blob) => {
            const file = new File([blob], "camera_capture.jpg", { type: "image/jpeg" });
            handleFile(file);
            tabUpload.click();
        }, 'image/jpeg', 0.9);
    });

    function showError(msg) {
        errorText.textContent = msg;
        errorMsg.classList.remove('hidden');
        loadingOverlay.classList.add('hidden');
    }

    // --- Offline AI Prediction ---
    predictBtn.addEventListener('click', async () => {
        if (!selectedFile) return;

        if (!model) {
            showError("AI Model is still loading or failed to load. Please wait.");
            return;
        }

        loadingOverlay.classList.remove('hidden');
        resultsSection.classList.add('hidden');
        errorMsg.classList.add('hidden');

        try {
            // Preprocess image outside tidy first
            let imgTensor = tf.browser.fromPixels(imagePreview);
            imgTensor = tf.image.resizeBilinear(imgTensor, [224, 224]);
            imgTensor = imgTensor.div(255.0);
            imgTensor = imgTensor.expandDims(0);

            // Run inference - graph models may return a NamedTensorMap or a Tensor
            const t0 = performance.now();
            let outputTensor = model.predict(imgTensor);

            // If it's a NamedTensorMap (object), extract the first value
            if (outputTensor && typeof outputTensor === 'object' && !outputTensor.shape) {
                outputTensor = Object.values(outputTensor)[0];
            }

            // Get raw probabilities array
            const probData = await outputTensor.data();
            const t1 = performance.now();
            const inferenceTimeMs = t1 - t0;

            // Cleanup tensors
            imgTensor.dispose();
            outputTensor.dispose();

            console.log("Raw predictions:", Array.from(probData));

            // Find argmax
            let maxIdx = 0;
            let maxProb = probData[0];
            for (let i = 1; i < probData.length; i++) {
                if (probData[i] > maxProb) {
                    maxProb = probData[i];
                    maxIdx = i;
                }
            }
            const maxIndex = maxIdx;

            // Extract results
            const predictedClassName = CLASS_LABELS[maxIndex];
            const confidence = maxProb * 100;
            const info = WASTE_INFO_DB[predictedClassName] || {};

            // Title Case Formatting for UI
            const titleClassName = predictedClassName.replace(/\w\S*/g, (txt) => {
                return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
            });

            // Populate UI
            predClass.textContent = titleClassName;
            predConf.textContent = confidence.toFixed(1) + "%";
            predTime.textContent = inferenceTimeMs.toFixed(1) + " ms";

            // Populate all predictions dropdown
            const allPredictionsList = document.getElementById('allPredictionsList');
            allPredictionsList.innerHTML = '';

            const preds = Array.from(probData).map((prob, i) => ({
                className: CLASS_LABELS[i].replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()),
                probability: prob * 100
            })).sort((a, b) => b.probability - a.probability);

            preds.forEach(p => {
                const item = document.createElement('div');
                item.style.display = 'flex';
                item.style.justifyContent = 'space-between';
                item.style.alignItems = 'center';
                item.style.background = 'rgba(255, 255, 255, 0.05)';
                item.style.padding = '0.5rem';
                item.style.borderRadius = '0.5rem';

                const nameSpan = document.createElement('span');
                nameSpan.textContent = p.className;

                const probSpan = document.createElement('span');
                probSpan.textContent = p.probability.toFixed(1) + '%';
                probSpan.style.color = 'var(--accent-color)';
                probSpan.style.fontWeight = 'bold';

                item.appendChild(nameSpan);
                item.appendChild(probSpan);
                allPredictionsList.appendChild(item);
            });

            infoCategory.textContent = info.Category || "Unknown";
            infoRecyclable.textContent = info.Recyclable || "Unknown";
            infoBin.textContent = info["Dispose In"] || "Unknown Bin";

            loadingOverlay.classList.add('hidden');
            resultsSection.classList.remove('hidden');

            setupGoogleMaps(info.google_query || "waste+disposal+facility");

        } catch (err) {
            console.error("Prediction error:", err);
            showError("Failed to analyze image using local AI.");
        }
    });

    // --- Google Maps Integration ---
    function setupGoogleMaps(searchQuery) {
        let mapsUrl = `https://www.google.com/maps/search/${searchQuery}+near+me`;
        googleMapsBtn.href = mapsUrl;

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const lat = position.coords.latitude;
                    const lon = position.coords.longitude;
                    mapsUrl = `https://www.google.com/maps/search/${searchQuery}/@${lat},${lon},14z`;
                    googleMapsBtn.href = mapsUrl;
                },
                (err) => {
                    console.warn("Location access denied, falling back to general search.", err);
                }
            );
        }
    }
});
