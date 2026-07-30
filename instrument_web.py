import re

with open('web/script.js', 'r') as f:
    content = f.read()

checksum_func = """
    async function getChecksum(url) {
        const res = await fetch(url);
        const buffer = await res.arrayBuffer();
        const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }
"""

content = content.replace("async function initData() {", checksum_func + "\n    async function initData() {\n        console.log(`[PARITY] Stage 0 - Environment Verification (Web)`);\n        console.log(`[PARITY] config.json SHA-256: ${await getChecksum('../shared/config.json')}`);\n        console.log(`[PARITY] labels.json SHA-256: ${await getChecksum('../shared/labels.json')}`);\n        console.log(`[PARITY] waste_database.json SHA-256: ${await getChecksum('../shared/waste_database.json')}`);")
content = content.replace("console.log(\"Loading ONNX model...\");", "console.log(\"Loading ONNX model...\");\n            console.log(`[PARITY] ecovision_model.onnx SHA-256: ${await getChecksum('../shared/ecovision_model.onnx')}`);")

stage1 = """
            console.log(`[PARITY] Stage 1 - Image Loading`);
            const imgWidth = imagePreview.naturalWidth;
            const imgHeight = imagePreview.naturalHeight;
            console.log(`[PARITY] Original Width: ${imgWidth}`);
            console.log(`[PARITY] Original Height: ${imgHeight}`);
            console.log(`[PARITY] Orientation: Handled natively by browser <img> tag (EXIF applied)`);
"""
content = content.replace("let imgTensor = tf.browser.fromPixels(imagePreview);", stage1 + "\n            let imgTensor = tf.browser.fromPixels(imagePreview);")

stage2 = """
            console.log(`[PARITY] Stage 2 - Cropping`);
            console.log(`[PARITY] Crop Start X: ${startX}`);
            console.log(`[PARITY] Crop Start Y: ${startY}`);
            console.log(`[PARITY] Crop Width: ${minDim}`);
            console.log(`[PARITY] Crop Height: ${minDim}`);
            
            const cropCanvas = document.createElement('canvas');
            cropCanvas.width = minDim;
            cropCanvas.height = minDim;
            await tf.browser.toPixels(croppedTensor.asType('int32'), cropCanvas);
            const aCrop = document.createElement('a');
            aCrop.href = cropCanvas.toDataURL('image/png');
            aCrop.download = 'web_crop.png';
            aCrop.click();
"""
content = content.replace("let croppedTensor = tf.slice(imgTensor, [startY, startX, 0], [minDim, minDim, 3]);", "let croppedTensor = tf.slice(imgTensor, [startY, startX, 0], [minDim, minDim, 3]);\n" + stage2)

stage3 = """
            console.log(`[PARITY] Stage 3 - Resize`);
            const resizeCanvas = document.createElement('canvas');
            resizeCanvas.width = inputSize;
            resizeCanvas.height = inputSize;
            await tf.browser.toPixels(resizedTensor.asType('int32'), resizeCanvas);
            const aResize = document.createElement('a');
            aResize.href = resizeCanvas.toDataURL('image/png');
            aResize.download = 'web_resize.png';
            aResize.click();
"""
content = content.replace("let finalTensor = resizedTensor.expandDims(0);", stage3 + "\n            let finalTensor = resizedTensor.expandDims(0);")

stage4 = """
            console.log(`[PARITY] Stage 4 - Tensor Generation`);
            console.log(`[PARITY] Tensor Shape: [1, ${inputSize}, ${inputSize}, 3]`);
            console.log(`[PARITY] Tensor Length: ${float32Data.length}`);
            let min = Infinity, max = -Infinity, sum = 0;
            for(let i=0; i<float32Data.length; i++) {
                const v = float32Data[i];
                if (v < min) min = v;
                if (v > max) max = v;
                sum += v;
            }
            const mean = sum / float32Data.length;
            let sqSum = 0;
            for(let i=0; i<float32Data.length; i++) {
                sqSum += Math.pow(float32Data[i] - mean, 2);
            }
            const stdDev = Math.sqrt(sqSum / float32Data.length);
            console.log(`[PARITY] Min Value: ${min}`);
            console.log(`[PARITY] Max Value: ${max}`);
            console.log(`[PARITY] Mean: ${mean}`);
            console.log(`[PARITY] Std Dev: ${stdDev}`);
            console.log(`[PARITY] First 20 floats: [${Array.from(float32Data.slice(0, 20)).join(', ')}]`);
            console.log(`[PARITY] Middle 20 floats: [${Array.from(float32Data.slice(Math.floor(float32Data.length/2), Math.floor(float32Data.length/2)+20)).join(', ')}]`);
            console.log(`[PARITY] Last 20 floats: [${Array.from(float32Data.slice(-20)).join(', ')}]`);
            
            console.log(`[PARITY] Stage 5 - Model Input Metadata`);
            console.log(`[PARITY] Input Name: ${model.inputNames[0]}`);
            console.log(`[PARITY] Output Name: ${model.outputNames[0]}`);
            console.log(`[PARITY] Input Shape: Expected [1, ${inputSize}, ${inputSize}, 3]`);
            console.log(`[PARITY] Tensor Type: float32`);
"""
content = content.replace("const t0 = performance.now();", stage4 + "\n            const t0 = performance.now();")

stage6 = """
            console.log(`[PARITY] Stage 6 - Raw ONNX Output`);
            console.log(`[PARITY] Raw Output Vector: [${Array.from(probData).join(', ')}]`);
"""
content = content.replace("console.log(\"Raw predictions:\", Array.from(probData));", stage6)

stage6_argmax = """
            console.log(`[PARITY] Argmax Index: ${maxIdx}`);
"""
content = content.replace("const maxIndex = maxIdx;", stage6_argmax + "\n            const maxIndex = maxIdx;")

stage7 = """
            console.log(`[PARITY] Stage 7 - Label Mapping`);
            console.log(`[PARITY] Index: ${maxIndex} -> Label: ${predictedClassName} -> Category: ${info.Category || 'Unknown'} -> Confidence: ${confidence}% -> Threshold: ${threshold} -> Final Result: ${predictedClassName === 'Non_Waste' || confidence < threshold ? 'Uncertain / Non Waste' : predictedClassName}`);
"""
content = content.replace("if (predictedClassName === 'Non_Waste' || confidence < threshold) {", stage7 + "\n            if (predictedClassName === 'Non_Waste' || confidence < threshold) {")

with open('web/script.js', 'w') as f:
    f.write(content)

