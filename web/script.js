document.addEventListener('DOMContentLoaded', () => {
    // --- Views ---
    const views = {
        viewDashboard: document.getElementById('viewDashboard'),
        viewScan: document.getElementById('viewScan'),
        viewLearn: document.getElementById('viewLearn'),
        viewSearch: document.getElementById('viewSearch'),
        viewResult: document.getElementById('viewResult'),
        viewCivic: document.getElementById('viewCivic')
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
        const hour = new Date().getHours();
        let msg = "Good Morning";
        if (hour >= 12 && hour < 17) msg = "Good Afternoon";
        else if (hour >= 17) msg = "Good Evening";
        document.getElementById('welcomeMsg').innerHTML = `${msg} 🌿`;

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
                <div class="history-item" style="width: 100%; box-sizing: border-box; align-items:flex-start; flex-direction:column; gap:0.25rem; padding: 1rem; margin-bottom: 0.5rem; background: var(--bg-color); border: 1px solid var(--border-color); border-radius: 0.75rem;" onclick="showResultScreen('${key}', 'Knowledge Base')">
                    <h3 style="font-size:1.1rem; font-weight: 700; color:var(--text-primary); cursor:pointer;">${key.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())}</h3>
                    <p style="font-size: 0.9rem; color: var(--text-secondary);"><strong>Bin:</strong> ${info['Dispose In'] || 'General'}</p>
                    <p style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 0.25rem;">${info['Recycling Process'] || ''}</p>
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
        switchView('viewDashboard'); 
    });

    // --- Search Logic ---
    let currentFocus = -1;

    searchInput.addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase().trim();
        currentFocus = -1;
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

    searchInput.addEventListener('keydown', (e) => {
        let items = searchSuggestions.querySelectorAll('.suggestion-item');
        if (items.length === 0) return;
        
        if (e.key === 'ArrowDown') {
            currentFocus++;
            addActive(items);
        } else if (e.key === 'ArrowUp') {
            currentFocus--;
            addActive(items);
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (currentFocus > -1) {
                if (items[currentFocus]) items[currentFocus].click();
            }
        }
    });

    function addActive(items) {
        if (!items) return false;
        removeActive(items);
        if (currentFocus >= items.length) currentFocus = 0;
        if (currentFocus < 0) currentFocus = (items.length - 1);
        items[currentFocus].classList.add('suggestion-active');
        items[currentFocus].style.backgroundColor = 'var(--surface-color)';
    }

    function removeActive(items) {
        for (let i = 0; i < items.length; i++) {
            items[i].classList.remove('suggestion-active');
            items[i].style.backgroundColor = '';
        }
    }

    document.addEventListener('click', (e) => {
        if(!searchInput.contains(e.target) && !searchSuggestions.contains(e.target)) {
            searchSuggestions.classList.add('hidden');
        }
    });

    popularItems.forEach(item => {
        item.addEventListener('click', () => showResultScreen(item.getAttribute('data-query'), "Category Selection"));
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
        const cameraPreview = document.getElementById('cameraPreview');
        cameraPreview.src = currentDataURL;
        cameraPreview.classList.remove('hidden');
        
        canvasElement.toBlob((blob) => {
            selectedFile = new File([blob], "camera_capture.jpg", { type: "image/jpeg" });
            predictBtn.disabled = false;
        }, 'image/jpeg', 0.9);
    });

    // Reset camera preview when switching tabs
    tabCamera.addEventListener('click', () => {
        document.getElementById('cameraPreview').classList.add('hidden');
        tabCamera.classList.add('active');
    });

    // --- Inference ---
    predictBtn.addEventListener('click', async () => {
        if (!currentDataURL || !model) return;
        loadingOverlay.classList.remove('hidden');
        errorMsg.classList.add('hidden');

        try {
            const tempImg = new Image();
            tempImg.src = currentDataURL;
            await new Promise(resolve => tempImg.onload = resolve);

            let imgTensor = tf.browser.fromPixels(tempImg);
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

            let maxIdx = 0, maxProb = 0;
            for(let i = 0; i < probData.length; i++) {
                if(probData[i] > maxProb) {
                    maxProb = probData[i];
                    maxIdx = i;
                }
            }

            let rawClassName = CLASS_LABELS[maxIdx];
            
            const threshold = CONFIG.confidence_threshold || 65.0;
            if (maxProb * 100 < threshold || rawClassName === 'Non_Waste') {
                rawClassName = 'Non_Waste';
            }
            
            lastPredRawClass = rawClassName; 
            const confidenceStr = "AI Confidence: " + (maxProb * 100).toFixed(1) + '%';
            
            loadingOverlay.classList.add('hidden');
            showResultScreen(rawClassName, confidenceStr, currentDataURL, probData);

        } catch (e) {
            console.error(e);
            errorText.textContent = "Error during AI analysis.";
            errorMsg.classList.remove('hidden');
            loadingOverlay.classList.add('hidden');
        }
    });

    // --- Premium Result Renderer ---
        window.showResultScreen = function(categoryKey, contextLabel = "Knowledge Base", imageUrl = null, probData = null) {
        const key = Object.keys(WASTE_INFO_DB).find(k => k.toLowerCase() === categoryKey.toLowerCase());
        const info = key ? WASTE_INFO_DB[key] : {
            'Dispose In': 'General Bin',
            'Environmental Impact': 'Unknown',
            'Recycling Process': 'N/A'
        };

        const title = (key || categoryKey).replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase());
        const bin = info['Dispose In'];
        
        let scrapVal = 'No significant scrap value';
        const lowerClass = ((info['Category'] || '') + " " + (key || categoryKey)).toLowerCase();
        if(lowerClass.includes('metal')) scrapVal = '₹20 - ₹200/kg';
        if(lowerClass.includes('e-waste') || lowerClass.includes('smartphone')) scrapVal = '₹150 - ₹500/kg';
        if(lowerClass.includes('plastic')) scrapVal = '₹8 - ₹12/kg';
        if(lowerClass.includes('paper') || lowerClass.includes('cardboard')) scrapVal = '₹10 - ₹15/kg';
        if(lowerClass.includes('glass')) scrapVal = '₹2 - ₹5/kg';

        let q = "recycling";
        if (lowerClass.includes('e-waste')) q = "e-waste";
        if (lowerClass.includes('plastic')) q = "plastic recycling";
        if (lowerClass.includes('garbage')) q = "dumpster";
        if (lowerClass.includes('metal')) q = "scrap metal yard";
        if (lowerClass.includes('paper')) q = "paper recycling";
        const mapUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`;

        let probHtml = '';
        if (probData) {
            const sorted = Array.from(probData).map((prob, i) => ({
                name: CLASS_LABELS[i].replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()),
                prob: prob * 100
            })).sort((a,b) => b.prob - a.prob).filter(p => p.prob > 0.5);

            probHtml = `
            <details style="margin-top: 1rem;">
                <summary style="color: var(--accent-color); font-weight: 600; cursor: pointer; font-size: 0.9rem;">▶ View All Predictions</summary>
                <div style="margin-top: 0.5rem; padding: 0.5rem; background: var(--bg-color); border-radius: 0.5rem;">
                ${sorted.map(p => `
                    <div style="margin-bottom: 0.5rem; font-size: 0.85rem;">
                        <div style="display:flex; justify-content:space-between;">
                            <span>${p.name}</span><span>${p.prob.toFixed(1)}%</span>
                        </div>
                        <div class="probability-bar-container" style="height: 4px; background: #cbd5e1;">
                            <div class="probability-bar-fill" style="width: ${p.prob}%; background: var(--accent-color); height: 100%;"></div>
                        </div>
                    </div>
                `).join('')}
                </div>
            </details>`;
        }

        let confirmHtml = '';
        if (imageUrl) {
            confirmHtml = `
            <div style="margin-top: 1.5rem;">
                <p style="font-size: 0.9rem; font-weight: 600; margin-bottom: 0.5rem;">Confirm Category to Earn Points:</p>
                <select id="manualCategory" class="btn action-btn" style="width: 100%; margin-bottom: 0.5rem; appearance: auto; background: var(--bg-color); border: 1px solid var(--accent-color); text-align: left; font-size: 0.95rem;">
                    ${CLASS_LABELS.map(label => `<option value="${label}" ${label.toLowerCase() === categoryKey.toLowerCase() ? 'selected' : ''}>${label.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())}</option>`).join('')}
                </select>
                <button id="confirmScanBtn" class="btn primary-btn" style="border-radius: 0.5rem;">
                    Confirm & Log Scan
                </button>
            </div>
            ${probHtml}
            `;
        }

        let colorCode = '#16a34a'; // default green
        if(bin.includes('Blue')) colorCode = '#3b82f6';
        if(bin.includes('Red')) colorCode = '#ef4444';
        if(bin.includes('Black')) colorCode = '#1e293b';

        resultContentArea.innerHTML = `
            <div class="premium-card" style="padding: 1.5rem;">
                <h3 style="font-size: 1.1rem; font-weight: 700; margin-bottom: 1rem; color: var(--text-primary); border-bottom: 1px solid var(--border-color); padding-bottom: 0.5rem;">
                    ${imageUrl ? 'AI Detection' : 'Search Result'}
                </h3>
                
                <h1 style="font-size: 1.8rem; font-weight: 800; color: ${colorCode}; margin-bottom: 0.5rem;">${title}</h1>
                
                ${imageUrl ? `
                <img src="${imageUrl}" onclick="document.getElementById('imageInput').click()" style="width: 100%; height: 200px; object-fit: cover; border-radius: 1rem; margin-bottom: 1rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); cursor: pointer;" title="Click to retake" alt="Scanned item" />
                <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem;">
                    <span style="background: #dcfce7; color: #16a34a; padding: 0.25rem 0.75rem; border-radius: 1rem; font-size: 0.8rem; font-weight: 600;">${contextLabel}</span>
                    <span style="background: #dcfce7; color: #16a34a; padding: 0.25rem 0.75rem; border-radius: 1rem; font-size: 0.8rem; font-weight: 600;">Time: 120ms</span>
                </div>
                ` : ''}
                
                ${confirmHtml}
            </div>

            <!-- Est Scrap Value -->
            <div class="premium-card" style="padding: 1.5rem; text-align: center;">
                <h3 style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem; text-align: left; border-bottom: 1px solid var(--border-color); padding-bottom: 0.5rem;">Est. Scrap Value</h3>
                <h2 style="font-size: 2rem; font-weight: 800; color: #16a34a; margin-top: 1rem;">${scrapVal}</h2>
                <p style="font-size: 0.75rem; color: var(--text-secondary);">Values are estimates only</p>
            </div>

            <!-- Handling & Impact -->
            <div class="premium-card" style="padding: 1.5rem;">
                <h3 style="font-size: 1.1rem; font-weight: 700; margin-bottom: 1rem; border-bottom: 1px solid var(--border-color); padding-bottom: 0.5rem;">Handling & Impact</h3>
                
                <div style="margin-bottom: 1rem;">
                    <div style="font-weight: 700; color: ${colorCode}; margin-bottom: 0.25rem;">Dispose In:</div>
                    <div style="font-size: 0.95rem;">${bin}</div>
                </div>
                <div style="margin-bottom: 1rem;">
                    <div style="font-weight: 700; color: #16a34a; margin-bottom: 0.25rem;">Environmental Impact:</div>
                    <div style="font-size: 0.95rem;">${info['Environmental Impact']}</div>
                </div>
                <div>
                    <div style="font-weight: 700; color: #8b5cf6; margin-bottom: 0.25rem;">Recycling Process:</div>
                    <div style="font-size: 0.95rem;">${info['Recycling Process']}</div>
                </div>
            </div>

            <!-- Nearby Facilities -->
            <div class="premium-card" style="padding: 1.5rem;">
                <h3 style="font-size: 1.1rem; font-weight: 700; margin-bottom: 1rem; border-bottom: 1px solid var(--border-color); padding-bottom: 0.5rem;">Nearby Facilities</h3>
                
                <div style="display: flex; justify-content: space-between; margin-bottom: 0.75rem; background: var(--bg-color); padding: 0.75rem; border-radius: 0.5rem; border: 1px solid var(--border-color);">
                    <div>
                        <div style="font-weight: 700; color: #16a34a; font-size: 0.9rem;">Ahmedabad Kabaadi Market</div>
                        <div style="font-size: 0.75rem; color: var(--text-secondary);">Gheekanta, Ahmedabad</div>
                    </div>
                    <div style="font-weight: 600; font-size: 0.8rem;">~2.1 km</div>
                </div>
                <div style="display: flex; justify-content: space-between; margin-bottom: 0.75rem; background: var(--bg-color); padding: 0.75rem; border-radius: 0.5rem; border: 1px solid var(--border-color);">
                    <div>
                        <div style="font-weight: 700; color: #16a34a; font-size: 0.9rem;">EcoRecycle Center</div>
                        <div style="font-size: 0.75rem; color: var(--text-secondary);">Navrangpura, Ahmedabad</div>
                    </div>
                    <div style="font-weight: 600; font-size: 0.8rem;">~3.5 km</div>
                </div>
                <div style="display: flex; justify-content: space-between; margin-bottom: 1rem; background: var(--bg-color); padding: 0.75rem; border-radius: 0.5rem; border: 1px solid var(--border-color);">
                    <div>
                        <div style="font-weight: 700; color: #16a34a; font-size: 0.9rem;">Green Waste Solutions</div>
                        <div style="font-size: 0.75rem; color: var(--text-secondary);">SG Highway, Ahmedabad</div>
                    </div>
                    <div style="font-weight: 600; font-size: 0.8rem;">~5.0 km</div>
                </div>

                <a href="${mapUrl}" target="_blank" onclick="interceptMapClick(event, this, '${q}')" class="btn primary-btn" style="background: #16a34a; color: white; text-decoration: none; border-radius: 0.5rem;">
                    <i data-lucide="map-pin"></i> Search on Google Maps
                </a>
            </div>

            <button onclick="document.querySelector('[data-target=viewCivic]').click()" class="btn" style="border: 1px solid #f59e0b; color: #d97706; background: #fef3c7; border-radius: 0.5rem; font-weight: 700; margin-bottom: 2rem;">
                Report Unmanaged Waste
            </button>
        `;

        lucide.createIcons();
        switchView('viewResult');

        if(imageUrl) {
            const manualDropdown = document.getElementById('manualCategory');
            manualDropdown.addEventListener('change', (e) => {
                showResultScreen(e.target.value, "Manual Correction", imageUrl, probData);
            });
            
            document.getElementById('confirmScanBtn').addEventListener('click', (e) => {
                const btn = e.currentTarget;
                if(btn.disabled) return;
                
                const selCat = manualDropdown.value;
                if (selCat !== 'Non_Waste') {
                    btn.innerHTML = 'Logged!';
                    btn.style.background = 'var(--text-secondary)';
                    
                    greenPoints += 10;
                    carbonOffset += 0.5;
                    scanHistory.push({ category: selCat.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()), date: new Date().toISOString() });
                    localStorage.setItem('eco_points', greenPoints);
                    localStorage.setItem('eco_carbon', carbonOffset);
                    localStorage.setItem('eco_history', JSON.stringify(scanHistory));
                } else {
                    btn.innerHTML = 'Ignored (Non-Waste)';
                    btn.style.background = 'var(--text-secondary)';
                }
                btn.disabled = true;
                lucide.createIcons();
            });
        }
    };

    window.interceptMapClick = function(e, element, query) {
        e.preventDefault();
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    const lat = pos.coords.latitude;
                    const lon = pos.coords.longitude;
                    const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}&query_place_id=${lat},${lon}`;
                    window.open(url, '_blank');
                },
                (err) => {
                    console.warn("Geolocation failed or denied, using default search.", err);
                    const fallbackUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query + ' near me')}`;
                    window.open(fallbackUrl, '_blank');
                }
            );
        } else {
            window.open(element.href + ' near me', '_blank');
        }
    }
    
    window.fetchCivicLocation = function(btn) {
        if (navigator.geolocation) {
            btn.innerHTML = '<i data-lucide="loader"></i> Locating...';
            lucide.createIcons();
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    const lat = pos.coords.latitude.toFixed(4);
                    const lon = pos.coords.longitude.toFixed(4);
                    btn.innerHTML = `<i data-lucide="check"></i> Lat: ${lat}, Lng: ${lon}`;
                    btn.style.color = '#16a34a';
                    btn.style.borderColor = '#16a34a';
                    btn.style.background = '#dcfce7';
                    lucide.createIcons();
                },
                (err) => {
                    console.warn("Geolocation failed", err);
                    btn.style.display = 'none';
                    const input = document.getElementById('civicLocInput');
                    input.classList.remove('hidden');
                    input.focus();
                }
            );
        } else {
            btn.style.display = 'none';
            const input = document.getElementById('civicLocInput');
            input.classList.remove('hidden');
            input.focus();
        }
    }
    
    window.searchFor = function(query) {
        showResultScreen(query, null, `100.0`, "Database Match");
    }

    window.showGovtBinInfo = function(color) {
        const modal = document.getElementById('govtBinModal');
        const title = document.getElementById('govtBinTitle');
        const desc = document.getElementById('govtBinDesc');
        const examples = document.getElementById('govtBinExamples');
        const dest = document.getElementById('govtBinDest');

        modal.classList.remove('hidden');

        if (color === 'green') {
            title.innerHTML = '<i data-lucide="trash-2" style="color: #22c55e;"></i> Green Bin: Wet Waste';
            desc.textContent = 'For organic and biodegradable waste.';
            examples.innerHTML = '<li>Kitchen scraps</li><li>Vegetable/fruit peels</li><li>Tea bags</li><li>Garden leaves</li>';
            dest.textContent = 'Sent directly to composting or bio-methanation facilities.';
        } else if (color === 'blue') {
            title.innerHTML = '<i data-lucide="trash-2" style="color: #3b82f6;"></i> Blue Bin: Dry Waste';
            desc.textContent = 'For non-biodegradable, recyclable materials.';
            examples.innerHTML = '<li>Plastics</li><li>Paper & Cardboard</li><li>Glass bottles</li><li>Metals</li>';
            dest.textContent = 'Transported to Material Recovery Facilities (MRFs) for sorting and recycling.';
        } else if (color === 'red') {
            title.innerHTML = '<i data-lucide="trash-2" style="color: #ef4444;"></i> Red Bin: Sanitary Waste';
            desc.textContent = 'A new category introduced to isolate highly personal and potentially infectious hygiene products.';
            examples.innerHTML = '<li>Used diapers</li><li>Sanitary pads</li><li>Bandages</li>';
            dest.textContent = 'Safely incinerated or deep-buried in secure landfills.';
        } else if (color === 'black') {
            title.innerHTML = '<i data-lucide="trash-2" style="color: #1e293b;"></i> Black Bin: Hazardous';
            desc.textContent = 'For domestic hazardous materials and e-waste.';
            examples.innerHTML = '<li>E-waste (batteries, bulbs)</li><li>Paint cans</li><li>Chemicals</li>';
            dest.textContent = 'Handled by specialized hazardous waste processing facilities.';
        }
        lucide.createIcons();
    }
});