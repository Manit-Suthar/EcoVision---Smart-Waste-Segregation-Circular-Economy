document.addEventListener('DOMContentLoaded', () => {
    // --- Views ---
    const views = {
        viewDashboard: document.getElementById('viewDashboard'),
        viewScan: document.getElementById('viewScan'),
        viewLearn: document.getElementById('viewLearn'),
        viewSearch: document.getElementById('viewSearch'),
        viewResult: document.getElementById('viewResult')
    };
    
    // Bottom Nav
    const navItems = document.querySelectorAll('.nav-item');

    // UI Elements
    const splashLoader = document.getElementById('splashLoader');
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
    const resultContentArea = document.getElementById('resultContentArea');
    const backFromResultBtn = document.getElementById('backFromResultBtn');

    // Search Elements
    const searchInput = document.getElementById('searchInput');
    const searchSuggestions = document.getElementById('searchSuggestions');
    const popularItems = document.querySelectorAll('.popular-item');
    const catPills = document.querySelectorAll('.cat-pill');

    let selectedFile = null;
    let currentDataURL = null; 
    let cameraStream = null;
    let model = null;
    let lastPredRawClass = null; 

    // --- State & Gamification ---
    let greenPoints = parseInt(localStorage.getItem('eco_points')) || 0;
    let carbonOffset = parseFloat(localStorage.getItem('eco_carbon')) || 0.0;
    let scanHistory = JSON.parse(localStorage.getItem('eco_history')) || [];
    let feedbackQueue = JSON.parse(localStorage.getItem('eco_feedback_queue')) || [];

    // --- Model & Database ---
    let CLASS_LABELS = [];
    let WASTE_INFO_DB = {};
    let CONFIG = {};

    window.onload = () => {
        setTimeout(() => {
            splashLoader.classList.add('fade-out');
            setTimeout(() => splashLoader.style.display = 'none', 500);
        }, 800);
    };

    function updateDashboardUI() {
        document.getElementById('dashScans').textContent = scanHistory.length;
        document.getElementById('dashPoints').textContent = greenPoints;
        document.getElementById('dashCO2').innerHTML = `${carbonOffset.toFixed(2)}<small>kg</small>`;
        
        let scrap = scanHistory.length * 5; // mockup value
        document.getElementById('dashScrap').textContent = `₹${scrap}`;
        
        const historyList = document.getElementById('historyList');
        if (scanHistory.length === 0) {
            historyList.innerHTML = '<p style="color: var(--text-secondary); text-align:center; padding:2rem;">No scans yet. Start recycling!</p>';
        } else {
            historyList.innerHTML = '';
            scanHistory.slice().reverse().slice(0, 5).forEach(scan => {
                historyList.innerHTML += `
                    <div class="history-item">
                        <div style="display:flex; align-items:center; gap:0.75rem;">
                            <div class="icon-circle gray-bg" style="width:40px;height:40px;"><i data-lucide="history" style="width:18px;height:18px;"></i></div>
                            <div>
                                <strong style="font-size:0.95rem;">${scan.category}</strong>
                                <div style="font-size: 0.8rem; color: var(--text-secondary);">${new Date(scan.date).toLocaleString()}</div>
                            </div>
                        </div>
                        <div style="color: var(--accent-color); font-weight: bold; font-size:0.9rem;">+10 pts</div>
                    </div>
                `;
            });
            lucide.createIcons();
        }
    }

    function populateLearnSection() {
        const learnList = document.getElementById('learnList');
        learnList.innerHTML = '';
        Object.keys(WASTE_INFO_DB).forEach(key => {
            const info = WASTE_INFO_DB[key];
            learnList.innerHTML += `
                <div class="history-item" style="align-items:flex-start; flex-direction:column; gap:0.5rem;" onclick="showResultScreen('${key}', 'Knowledge Base')">
                    <h3 style="font-size:1.1rem; color:var(--text-primary); cursor:pointer;">${key.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())}</h3>
                    <p style="font-size: 0.9rem; color: var(--text-secondary);"><strong>Bin:</strong> ${info['Dispose In'] || 'General'}</p>
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
        }
    }

    async function initModel() {
        try {
            model = await ort.InferenceSession.create('../shared/ecovision_model.onnx', { executionProviders: ['webgl', 'wasm'] });
        } catch (e) {
            console.error("Error loading model:", e);
        }
    }

    initData().then(() => initModel());

    // --- Navigation Logic ---
    function switchView(targetId) {
        navItems.forEach(n => n.classList.remove('active'));
        const targetNav = document.querySelector(`[data-target="${targetId}"]`);
        if(targetNav) targetNav.classList.add('active');
        
        Object.values(views).forEach(v => v.classList.add('hidden'));
        if(views[targetId]) views[targetId].classList.remove('hidden');
        
        if (targetId === 'viewDashboard') updateDashboardUI();
        if (targetId !== 'viewScan') stopCamera();
    }

    navItems.forEach(item => {
        item.addEventListener('click', () => switchView(item.getAttribute('data-target')));
    });

    backFromResultBtn.addEventListener('click', () => {
        switchView('viewSearch'); // or history.back() conceptually, but search is safe default
    });

    // --- Search Logic ---
    searchInput.addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase().trim();
        if (query.length < 2) {
            searchSuggestions.classList.add('hidden');
            return;
        }

        const matches = Object.keys(WASTE_INFO_DB).filter(k => k.toLowerCase().includes(query));
        
        if (matches.length > 0) {
            searchSuggestions.innerHTML = matches.slice(0, 5).map(m => `
                <div class="suggestion-item" data-key="${m}">
                    <i data-lucide="search" style="width:16px; height:16px; color:var(--text-secondary);"></i>
                    <span style="font-weight:500;">${m.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())}</span>
                </div>
            `).join('');
            searchSuggestions.classList.remove('hidden');
            lucide.createIcons();

            document.querySelectorAll('.suggestion-item').forEach(item => {
                item.addEventListener('click', () => {
                    const key = item.getAttribute('data-key');
                    searchInput.value = '';
                    searchSuggestions.classList.add('hidden');
                    showResultScreen(key, "Knowledge Base Search");
                });
            });
        } else {
            searchSuggestions.innerHTML = '<div class="suggestion-item"><span style="color:var(--text-secondary);">No matches found</span></div>';
            searchSuggestions.classList.remove('hidden');
        }
    });

    document.addEventListener('click', (e) => {
        if(!searchInput.contains(e.target) && !searchSuggestions.contains(e.target)) {
            searchSuggestions.classList.add('hidden');
        }
    });

    popularItems.forEach(item => {
        item.addEventListener('click', () => showResultScreen(item.getAttribute('data-query'), "Popular Selection"));
    });
    catPills.forEach(item => {
        item.addEventListener('click', () => {
            const cat = item.innerText.trim();
            // Just map to first matched for demo
            let key = Object.keys(WASTE_INFO_DB).find(k => k.toLowerCase().includes(cat.toLowerCase()));
            if(!key) key = "plastic waste"; 
            showResultScreen(key, "Category Selection");
        });
    });


    // --- Camera & Upload Logic ---
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

    uploadArea.addEventListener('click', () => fileInput.click());
    uploadArea.addEventListener('dragover', (e) => { e.preventDefault(); });
    uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) handleFile(e.dataTransfer.files[0]);
    });
    fileInput.addEventListener('change', (e) => {
        if (e.target.files && e.target.files.length > 0) handleFile(e.target.files[0]);
    });

    function handleFile(file) {
        if (!file.type.startsWith('image/')) return;
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
        errorMsg.classList.add('hidden');
    }

    async function startCamera() {
        try {
            cameraStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } });
            videoElement.srcObject = cameraStream;
        } catch (err) {
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
            handleFile(new File([blob], "camera_capture.jpg", { type: "image/jpeg" }));
            tabUpload.click();
        }, 'image/jpeg', 0.9);
    });

    // --- Inference ---
    predictBtn.addEventListener('click', async () => {
        if (!selectedFile || !model) return;
        loadingOverlay.classList.remove('hidden');
        errorMsg.classList.add('hidden');

        try {
            let imgTensor = tf.browser.fromPixels(imagePreview);
            const [h, w] = imgTensor.shape;
            const minDim = Math.min(h, w);
            const startY = Math.floor((h - minDim) / 2);
            const startX = Math.floor((w - minDim) / 2);
            let croppedTensor = tf.slice(imgTensor, [startY, startX, 0], [minDim, minDim, 3]);
            imgTensor.dispose(); 
            
            const inputSize = CONFIG.input_size || 224;
            let resizedTensor = tf.image.resizeBilinear(croppedTensor, [inputSize, inputSize]);
            croppedTensor.dispose(); 
            
            let finalTensor = resizedTensor.expandDims(0); 
            const float32Data = await finalTensor.data();
            finalTensor.dispose(); 

            const inputName = model.inputNames[0];
            const inputTensor = new ort.Tensor('float32', float32Data, [1, inputSize, inputSize, 3]);
            const output = await model.run({ [inputName]: inputTensor });
            const probData = output[model.outputNames[0]].data;

            let maxIdx = 0, maxProb = probData[0];
            for (let i = 1; i < probData.length; i++) {
                if (probData[i] > maxProb) { maxProb = probData[i]; maxIdx = i; }
            }

            const rawClassName = CLASS_LABELS[maxIdx];
            lastPredRawClass = rawClassName; 
            const confidenceStr = "AI Confidence: " + (maxProb * 100).toFixed(1) + '%';
            
            loadingOverlay.classList.add('hidden');
            showResultScreen(rawClassName, confidenceStr, currentDataURL);

        } catch (e) {
            console.error(e);
            errorText.textContent = "Error during AI analysis.";
            errorMsg.classList.remove('hidden');
            loadingOverlay.classList.add('hidden');
        }
    });

    // --- Premium Result Renderer ---
    window.showResultScreen = function(categoryKey, contextLabel = "Knowledge Base", imageUrl = null) {
        // Find DB entry
        const key = Object.keys(WASTE_INFO_DB).find(k => k.toLowerCase() === categoryKey.toLowerCase());
        const info = key ? WASTE_INFO_DB[key] : {
            'Dispose In': 'General Bin',
            'Environmental Impact': 'Unknown',
            'Recycling Process': 'N/A'
        };

        const title = (key || categoryKey).replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase());
        const bin = info['Dispose In'];
        
        let themeClass = 'general';
        let binIcon = 'trash-2';
        let binColor = 'var(--text-secondary)';

        if(bin.toLowerCase().includes('green') || bin.toLowerCase().includes('organic')) { themeClass = 'organic'; binIcon = 'leaf'; binColor = 'var(--accent-color)'; }
        if(bin.toLowerCase().includes('blue') || bin.toLowerCase().includes('recycle')) { themeClass = 'recyclable'; binIcon = 'recycle'; binColor = 'var(--info-color)'; }
        if(bin.toLowerCase().includes('red') || bin.toLowerCase().includes('hazard')) { themeClass = 'hazardous'; binIcon = 'alert-triangle'; binColor = 'var(--danger-color)'; }

        // Calculate Scrap
        let scrapVal = 'No significant scrap value';
        const lowerClass = (key || categoryKey).toLowerCase();
        if(lowerClass === 'metal waste') scrapVal = '₹20 - ₹200/kg';
        if(lowerClass === 'e-waste') scrapVal = '₹150 - ₹500/kg';
        if(lowerClass === 'plastic waste') scrapVal = '₹8 - ₹12/kg';
        if(lowerClass === 'paper waste') scrapVal = '₹10 - ₹15/kg';
        if(lowerClass === 'glass waste') scrapVal = '₹2 - ₹5/kg';

        // Map URL
        let q = "recycling";
        if (lowerClass.includes('e-waste')) q = "e-waste";
        if (lowerClass.includes('plastic')) q = "plastic recycling";
        if (lowerClass.includes('garbage')) q = "dumpster";
        if (lowerClass.includes('metal')) q = "scrap metal yard";
        if (lowerClass.includes('paper')) q = "paper recycling";
        const mapUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q + ' near me')}`;

        resultContentArea.innerHTML = `
            <div class="result-header">
                ${imageUrl ? `<img src="${imageUrl}" class="result-image">` : `<div class="icon-circle ${themeClass === 'organic'? 'green-bg' : themeClass === 'recyclable'? 'blue-bg' : themeClass==='hazardous'?'red-bg':'gray-bg'}" style="width:80px;height:80px;"><i data-lucide="${binIcon}" style="width:32px;height:32px;"></i></div>`}
                <div>
                    <div class="result-title">${title}</div>
                    <div class="result-category">
                        <i data-lucide="info" style="width:14px;height:14px;"></i> ${contextLabel}
                    </div>
                </div>
            </div>

            <!-- Disposal Card -->
            <div class="premium-card ${themeClass}">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 1rem;">
                    <div style="font-weight:700; font-size:1.1rem; color:${binColor};">Dispose In</div>
                    <i data-lucide="${binIcon}" style="color:${binColor};"></i>
                </div>
                <h3 style="font-size:1.8rem; margin-bottom: 0.5rem; color:var(--text-primary);">${bin}</h3>
                <p style="color:var(--text-secondary); font-size:0.9rem;">${info['Environmental Impact']}</p>
            </div>

            <!-- Gamification & Economics -->
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom:1rem;">
                <div class="premium-card" style="margin:0; padding:1rem; text-align:center;">
                    <i data-lucide="coins" style="color:#eab308; margin-bottom:0.5rem;"></i>
                    <div style="font-weight:800; font-size:1.1rem;">${scrapVal}</div>
                    <div style="font-size:0.8rem; color:var(--text-secondary);">Est. Scrap Value</div>
                </div>
                <div class="premium-card" style="margin:0; padding:1rem; text-align:center;">
                    <i data-lucide="star" style="color:#8b5cf6; margin-bottom:0.5rem;"></i>
                    <div style="font-weight:800; font-size:1.1rem;">+10 pts</div>
                    <div style="font-size:0.8rem; color:var(--text-secondary);">Green Reward</div>
                </div>
            </div>

            <!-- Process details -->
            <div class="premium-card">
                <h4 style="margin-bottom:0.5rem;"><i data-lucide="recycle" style="width:16px;height:16px; vertical-align:text-bottom;"></i> Recycling Process</h4>
                <p style="font-size:0.9rem; color:var(--text-secondary); line-height:1.5;">${info['Recycling Process']}</p>
            </div>

            <!-- Facility / Map -->
            <div class="premium-card" style="text-align:center;">
                <h4 style="margin-bottom:0.5rem;">Nearby Facilities</h4>
                <p style="font-size:0.9rem; color:var(--text-secondary); margin-bottom:1rem;">Find the closest recycling center for ${title.toLowerCase()}.</p>
                <a href="${mapUrl}" target="_blank" class="btn primary-btn" style="text-decoration:none; display:inline-flex; width:auto; padding: 0.75rem 1.5rem;">
                    <i data-lucide="map-pin"></i> Open Google Maps
                </a>
            </div>

            <!-- Mock Actions -->
            ${imageUrl ? `
            <button id="confirmScanBtn" class="btn primary-btn" style="margin-bottom:0.5rem;">
                <i data-lucide="check-circle"></i> Log Scan & Claim Points
            </button>
            ` : ''}
            
            <button id="reportBtn" class="btn action-btn" style="color:var(--danger-color); border-color:var(--danger-color);">
                <i data-lucide="alert-octagon"></i> Report Civic Issue
            </button>
        `;

        lucide.createIcons();
        switchView('viewResult');

        if(imageUrl) {
            document.getElementById('confirmScanBtn').addEventListener('click', (e) => {
                const btn = e.currentTarget;
                btn.innerHTML = '<i data-lucide="check"></i> Logged!';
                btn.style.background = 'var(--accent-color)';
                btn.disabled = true;
                
                greenPoints += 10;
                carbonOffset += 0.5;
                scanHistory.push({ category: title, date: new Date().toISOString() });
                localStorage.setItem('eco_points', greenPoints);
                localStorage.setItem('eco_carbon', carbonOffset);
                localStorage.setItem('eco_history', JSON.stringify(scanHistory));
                lucide.createIcons();
            });
        }

        document.getElementById('reportBtn').addEventListener('click', () => {
            const ticketId = '#EV-' + Math.floor(1000 + Math.random() * 9000);
            alert(`Civic complaint filed!\nTicket ID: ${ticketId}\nExpected Resolution: 48 hours\n\nThank you for keeping the city clean!`);
        });
    };
});
