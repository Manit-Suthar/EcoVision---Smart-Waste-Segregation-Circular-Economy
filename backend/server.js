require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'EcoVision backend is running' });
});

// Analytics endpoint (Phase 2 stub)
app.post('/api/analytics', (req, res) => {
    const { category, timestamp, city } = req.body;
    
    // In Phase 2, we just log this to the console.
    // In Phase 5, this will be saved to a database.
    console.log(`[Analytics] Scan recorded: ${category || 'Unknown'} at ${timestamp || new Date().toISOString()}`);
    
    res.json({ success: true, message: 'Analytics event recorded' });
});

app.listen(PORT, () => {
    console.log(`Server is listening on port ${PORT}`);
});
