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
    const infoCategory = document.getElementById('infoCategory');
    const infoRecyclable = document.getElementById('infoRecyclable');
    const infoBin = document.getElementById('infoBin');
    
    const googleMapsBtn = document.getElementById('googleMapsBtn');

    let selectedFile = null;
    let cameraStream = null;

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
            // Allow clicking to change image
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
            imagePreview.classList.remove('hidden');
            uploadContent.classList.add('hidden');
            predictBtn.disabled = false;
        };
        reader.readAsDataURL(file);
        
        // Hide previous results
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
            tabUpload.click(); // fallback to upload
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
        
        // Set canvas dimensions to match video
        canvasElement.width = videoElement.videoWidth;
        canvasElement.height = videoElement.videoHeight;
        
        // Draw video frame to canvas
        const ctx = canvasElement.getContext('2d');
        ctx.drawImage(videoElement, 0, 0, canvasElement.width, canvasElement.height);
        
        // Convert canvas to blob/file
        canvasElement.toBlob((blob) => {
            const file = new File([blob], "camera_capture.jpg", { type: "image/jpeg" });
            handleFile(file);
            
            // Switch back to upload tab to show preview
            tabUpload.click();
        }, 'image/jpeg', 0.9);
    });

    function showError(msg) {
        errorText.textContent = msg;
        errorMsg.classList.remove('hidden');
        loadingOverlay.classList.add('hidden');
    }

    // --- Prediction Handler ---
    predictBtn.addEventListener('click', async () => {
        if (!selectedFile) return;

        // Show loading
        loadingOverlay.classList.remove('hidden');
        resultsSection.classList.add('hidden');
        errorMsg.classList.add('hidden');

        const formData = new FormData();
        formData.append('file', selectedFile);

        try {
            const response = await fetch('http://127.0.0.1:5000/predict', {
                method: 'POST',
                body: formData
            });

            if (!response.ok) {
                throw new Error("Server error analyzing image.");
            }

            const data = await response.json();
            if (data.error) throw new Error(data.error);

            // Populate Info
            predClass.textContent = data.class_name;
            predConf.textContent = data.confidence;
            
            const info = data.waste_info;
            infoCategory.textContent = info.Category || "Unknown";
            infoRecyclable.textContent = info.Recyclable || "Unknown";
            infoBin.textContent = info["Dispose In"] || "Unknown Bin";

            // Show results
            loadingOverlay.classList.add('hidden');
            resultsSection.classList.remove('hidden');

            // Setup Google Maps specific link
            setupGoogleMaps(info.google_query || "waste+disposal+facility");

        } catch (err) {
            console.error(err);
            showError("Failed to analyze image. Ensure backend is running.");
        }
    });

    // --- Location & Google Maps Integration ---
    function setupGoogleMaps(searchQuery) {
        // Default generic search URL if location fails
        let mapsUrl = `https://www.google.com/maps/search/${searchQuery}+near+me`;
        googleMapsBtn.href = mapsUrl;

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const lat = position.coords.latitude;
                    const lon = position.coords.longitude;
                    // Precise search using user coordinates
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
