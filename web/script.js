document.addEventListener('DOMContentLoaded', () => {
    // Top-level View Elements
    const views = {
        viewDashboard: document.getElementById('viewDashboard'),
        viewScan: document.getElementById('viewScan'),
        viewLearn: document.getElementById('viewLearn')
    };
    
    // Bottom Nav
    const navItems = document.querySelectorAll('.nav-item');

    // UI Elements (Scan)
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
    
    const infoBin = document.getElementById('infoBin');
    const infoImpact = document.getElementById('infoImpact');
    const infoProcess = document.getElementById('infoProcess');
    
    const manualCategory = document.getElementById('manualCategory');
    
    // Add event listener to update UI when dropdown changes
    manualCategory.addEventListener('change', () => {
        updateResultDetails(manualCategory.value);
    });
    const logScanBtn = document.getElementById('logScanBtn');
    const scrapValueText = document.getElementById('scrapValueText');

    let selectedFile = null;
    let currentDataURL = null; // for training queue
    let cameraStream = null;
    let model = null;
    let lastPredRawClass = null; // store original prediction for feedback

    // --- Gamification State ---
    let greenPoints = parseInt(localStorage.getItem('eco_points')) || 0;
    let carbonOffset = parseFloat(localStorage.getItem('eco_carbon')) || 0.0;
    let scanHistory = JSON.parse(localStorage.getItem('eco_history')) || [];
    let feedbackQueue = JSON.parse(localStorage.getItem('eco_feedback_queue')) || [];

    // --- Model & Database ---
    let CLASS_LABELS = [];
    let WASTE_INFO_DB = {};
    let CONFIG = {};

    function updateDashboardUI() {
        document.getElementById('dashboardPoints').textContent = greenPoints;
        document.getElementById('dashboardCO2').textContent = carbonOffset.toFixed(2);
        
        const historyList = document.getElementById('historyList');
        if (scanHistory.length === 0) {
            historyList.innerHTML = '<p style="color: var(--text-secondary);">No scans yet.</p>';
        } else {
            historyList.innerHTML = '';
            scanHistory.slice().reverse().forEach(scan => {
                historyList.innerHTML += `
                    <div class="history-item">
                        <div>
                            <strong>${scan.category}</strong>
                            <div style="font-size: 0.8rem; color: var(--text-secondary);">${new Date(scan.date).toLocaleString()}</div>
                        </div>
                        <div style="color: var(--accent-color); font-weight: bold;">+10 pts</div>
                    </div>
                `;
            });
        }
    }

    function populateLearnSection() {
        const learnList = document.getElementById('learnList');
        learnList.innerHTML = '';
        Object.keys(WASTE_INFO_DB).forEach(key => {
            const info = WASTE_INFO_DB[key];
            learnList.innerHTML += `
                <div class="learn-item">
                    <h3>${key.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())}</h3>
                    <p style="font-size: 0.9rem; color: #cbd5e1; margin-bottom: 0.5rem;"><strong>Bin:</strong> ${info['Dispose In'] || 'General'}</p>
                    <p style="font-size: 0.85rem; color: var(--text-secondary);">${info['Recycling Process'] || ''}</p>
                </div>
            `;
        });
    }

    async function initData() {
        try {
            const configRes = await fetch('../shared/config.json');
            CONFIG = await configRes.json();
            const labelsRes = await fetch('../shared/labels.json');
            CLASS_LABELS = await labelsRes.json();
            const dbRes = await fetch('../shared/waste_database.json');
            WASTE_INFO_DB = await dbRes.json();
            
            updateDashboardUI();
            populateLearnSection();
        } catch (e) {
            console.error("Error loading shared data:", e);
            showError("Failed to load knowledge base.");
        }
    }

    async function initModel() {
        try {
            console.log("Loading ONNX model...");
            model = await ort.InferenceSession.create('../shared/ecovision_model.onnx', {
                executionProviders: ['webgl', 'wasm']
            });
            console.log("Model loaded successfully!");
        } catch (e) {
            console.error("Error loading model:", e);
            showError("Failed to load AI model.");
        }
    }

    initData().then(() => initModel());

    // --- Navigation Logic ---
    navItems.forEach(item => {
        item.addEventListener('click', () => {
            navItems.forEach(n => n.classList.remove('active'));
            item.classList.add('active');
            
            Object.values(views).forEach(v => v.classList.add('hidden'));
            const targetId = item.getAttribute('data-target');
            views[targetId].classList.remove('hidden');
            
            if (targetId === 'viewDashboard') updateDashboardUI();
            if (targetId !== 'viewScan') stopCamera();
        });
    });

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
    uploadArea.addEventListener('click', () => fileInput.click());
    uploadArea.addEventListener('dragover', (e) => { e.preventDefault(); uploadArea.classList.add('dragover'); });
    uploadArea.addEventListener('dragleave', () => uploadArea.classList.remove('dragover'));
    uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) handleFile(e.dataTransfer.files[0]);
    });
    fileInput.addEventListener('change', (e) => {
        if (e.target.files && e.target.files.length > 0) handleFile(e.target.files[0]);
    });

    function handleFile(file) {
        if (!file.type.startsWith('image/')) {
            showError("Please upload a valid image file.");
            return;
        }
        selectedFile = file;
        const reader = new FileReader();
        reader.onload = (e) => {
            currentDataURL = e.target.result;
            imagePreview.src = currentDataURL;
            imagePreview.onload = () => {
                imagePreview.classList.remove('hidden');
                uploadContent.classList.add('hidden');
                predictBtn.disabled = false;
            };
        };
        reader.readAsDataURL(file);
        resultsSection.classList.add('hidden');
        errorMsg.classList.add('hidden');
        logScanBtn.disabled = false;
        logScanBtn.textContent = 'Confirm & Log Scan';
        logScanBtn.style.background = '';
    }

    // --- Camera Handlers ---
    async function startCamera() {
        try {
            cameraStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } });
            videoElement.srcObject = cameraStream;
        } catch (err) {
            console.error("Camera error:", err);
            showError("Camera access denied or unavailable.");
            tabUpload.click();
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
        
        currentDataURL = canvasElement.toDataURL('image/jpeg', 0.9);
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
        if (!model) { showError("AI Model is still loading or failed to load."); return; }

        loadingOverlay.classList.remove('hidden');
        resultsSection.classList.add('hidden');
        errorMsg.classList.add('hidden');

        try {
            let imgTensor = tf.browser.fromPixels(imagePreview);
            
            // Center crop
            const [h, w] = imgTensor.shape;
            const minDim = Math.min(h, w);
            const startY = Math.floor((h - minDim) / 2);
            const startX = Math.floor((w - minDim) / 2);
            let croppedTensor = tf.slice(imgTensor, [startY, startX, 0], [minDim, minDim, 3]);
            imgTensor.dispose(); 
            
            // Resize
            const inputSize = CONFIG.input_size || 224;
            let resizedTensor = tf.image.resizeBilinear(croppedTensor, [inputSize, inputSize]);
            croppedTensor.dispose(); 
            
            let finalTensor = resizedTensor.expandDims(0); 
            const float32Data = await finalTensor.data();
            finalTensor.dispose(); 

            // Run inference
            const t0 = performance.now();
            const inputName = model.inputNames[0];
            const inputTensor = new ort.Tensor('float32', float32Data, [1, inputSize, inputSize, 3]);
            const output = await model.run({ [inputName]: inputTensor });
            const probData = output[model.outputNames[0]].data;
            const inferenceTimeMs = performance.now() - t0;

            // Argmax
            let maxIdx = 0, maxProb = probData[0];
            for (let i = 1; i < probData.length; i++) {
                if (probData[i] > maxProb) { maxProb = probData[i]; maxIdx = i; }
            }

            const rawClassName = CLASS_LABELS[maxIdx];
            lastPredRawClass = rawClassName; // Store for feedback
            const confidence = maxProb * 100;
            
            // Format Title
            const titleClassName = rawClassName.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase());

            // Populate AI confidence UI
            predClass.textContent = titleClassName;
            predConf.textContent = confidence.toFixed(1) + '%';
            predTime.textContent = inferenceTimeMs.toFixed(0) + 'ms';
            
            // Pre-select manual dropdown
            Array.from(manualCategory.options).forEach(opt => {
                if(opt.value.toLowerCase() === rawClassName.toLowerCase()) opt.selected = true;
            });
            if(manualCategory.selectedIndex === -1) manualCategory.value = 'Non_Waste';

            // Populate all other UI elements based on selected category
            updateResultDetails(manualCategory.value);



            // Populate all predictions
            const allList = document.getElementById('allPredictionsList');
            allList.innerHTML = '';
            Array.from(probData).map((prob, i) => ({
                name: CLASS_LABELS[i].replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()),
                prob: prob * 100
            })).sort((a,b) => b.prob - a.prob).forEach(p => {
                allList.innerHTML += `<div style="display:flex; justify-content:space-between;">
                    <span>${p.name}</span><span>${p.prob.toFixed(1)}%</span>
                </div>`;
            });

            loadingOverlay.classList.add('hidden');
            resultsSection.classList.remove('hidden');

        } catch (e) {
            console.error(e);
            showError("An error occurred during AI analysis.");
        }
    });

    function updateResultDetails(categoryName) {
        if (categoryName === 'Non_Waste') {
            infoBin.textContent = 'General Waste';
            infoImpact.textContent = '-';
            infoProcess.textContent = '-';
            scrapValueText.textContent = '$0.00';
            renderMap('garbage');
            return;
        }

        // The dropdown values might differ in case (e.g. "e-waste" vs "E-waste")
        const key = Object.keys(WASTE_INFO_DB).find(k => k.toLowerCase() === categoryName.toLowerCase());
        const info = key ? WASTE_INFO_DB[key] : {};
        infoBin.textContent = info['Dispose In'] || 'General Bin';
        infoImpact.textContent = info['Environmental Impact'] || '-';
        infoProcess.textContent = info['Recycling Process'] || '-';
        
        let scrapVal = 'No significant scrap value';
        const lowerClass = categoryName.toLowerCase();
        if(lowerClass === 'metal waste') scrapVal = '₹20 - ₹200/kg';
        if(lowerClass === 'e-waste') scrapVal = '₹150 - ₹500/kg';
        if(lowerClass === 'plastic waste') scrapVal = '₹8 - ₹12/kg';
        if(lowerClass === 'paper waste') scrapVal = '₹10 - ₹15/kg';
        if(lowerClass === 'glass waste') scrapVal = '₹2 - ₹5/kg';
        if(lowerClass === 'automobile wastes') scrapVal = 'Variable by part';
        scrapValueText.textContent = scrapVal;

        renderMap(lowerClass);
    }

    function renderMap(category) {
        const mapContainer = document.getElementById('mapContainer');
        if (!mapContainer) return;
        
        let q = "recycling";
        if (category.includes('e-waste')) q = "e-waste";
        if (category.includes('plastic')) q = "plastic recycling";
        if (category.includes('garbage')) q = "dumpster";
        if (category.includes('metal')) q = "scrap metal yard";
        if (category.includes('paper')) q = "paper recycling";

        const googleMapsSearchUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q + ' Ahmedabad')}`;
        
        const hardcodedPlaces = [
            { name: "Ahmedabad Kabaadi Market", address: "Gheekanta, Ahmedabad", distance: "~2.1 km" },
            { name: "EcoRecycle Center", address: "Navrangpura, Ahmedabad", distance: "~3.5 km" },
            { name: "Green Waste Solutions", address: "SG Highway, Ahmedabad", distance: "~5.0 km" }
        ];

        let cardsHtml = '';
        hardcodedPlaces.forEach(place => {
            cardsHtml += `
                <div style="background: rgba(0,0,0,0.02); padding: 0.75rem; border-radius: 8px; border: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
                    <div>
                        <h4 style="margin: 0; font-size: 0.95rem; color: var(--accent-color);">${place.name}</h4>
                        <p style="margin: 0.25rem 0 0 0; font-size: 0.8rem; color: var(--text-secondary);">${place.address}</p>
                    </div>
                    <div style="font-size: 0.8rem; font-weight: bold; color: var(--text-primary);">
                        ${place.distance}
                    </div>
                </div>
            `;
        });

        mapContainer.innerHTML = `
            <div style="margin-top: 1rem;">
                ${cardsHtml}
                <div style="text-align: center; margin-top: 1rem;">
                    <a href="${googleMapsSearchUrl}" target="_blank" class="btn primary-btn" style="display: inline-block; text-decoration: none; width: auto; padding: 0.5rem 1rem;">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: middle; margin-right: 4px;"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                        Search on Google Maps
                    </a>
                </div>
            </div>
        `;
    }

    const reportIssueBtn = document.getElementById('reportIssueBtn');
    if (reportIssueBtn) {
        reportIssueBtn.addEventListener('click', () => {
            alert("Thank you! Your civic complaint has been drafted. A simulated ticket ID will be generated.");
        });
    }

    // --- Log Scan & Gamification ---
    logScanBtn.addEventListener('click', () => {
        if(logScanBtn.disabled) return;
        
        const selCat = manualCategory.value;
        
        // Feedback Loop Local Storage
        if(selCat !== lastPredRawClass && selCat !== 'Non_Waste') {
            feedbackQueue.push({
                image: currentDataURL.substring(0, 100) + '... (truncated for local demo)', // Don't bloat local storage in demo
                original: lastPredRawClass,
                corrected: selCat,
                time: new Date().toISOString()
            });
            if(feedbackQueue.length > 50) feedbackQueue.shift();
            localStorage.setItem('eco_feedback_queue', JSON.stringify(feedbackQueue));
        }

        if(selCat !== 'Non_Waste') {
            greenPoints += 10;
            let offset = 0.5;
            if (selCat === 'e-waste') offset = 5.0;
            if (selCat === 'metal waste') offset = 3.0;
            if (selCat === 'plastic waste') offset = 1.5;
            carbonOffset += offset;
            
            scanHistory.push({
                category: selCat.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()),
                date: new Date().toISOString()
            });
            
            localStorage.setItem('eco_points', greenPoints);
            localStorage.setItem('eco_carbon', carbonOffset);
            localStorage.setItem('eco_history', JSON.stringify(scanHistory));
            
            logScanBtn.textContent = 'Logged (+10 Points)';
            logScanBtn.style.background = '#10b981';
            logScanBtn.style.color = '#000';
            logScanBtn.disabled = true;
            
            updateDashboardUI();
        } else {
            logScanBtn.textContent = 'Marked as Non-Waste';
            logScanBtn.style.background = '#475569';
            logScanBtn.disabled = true;
        }
    });

});
