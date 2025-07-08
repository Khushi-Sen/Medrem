// backend/server.js
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();
// Ensure the cron job is initialized when the server starts
require('./utils/missedDoseChecker');

const app = express();
app.use(cors());
app.use(express.json()); // For parsing application/json

const PORT = process.env.PORT || 5000;
const URI = process.env.MONGODB_URI;

// Import Routes
const medicationRoutes = require('./routes/medicationRoutes');
const doseRoutes = require('./routes/doseRoutes'); // REMOVE OR COMMENT OUT THIS LINE

// Use Routes
app.use('/api/medications', medicationRoutes);
app.use('/api/doses', doseRoutes); // REMOVE OR COMMENT OUT THIS LINE

// Default Route
app.get('/', (req, res) => {
    res.send('✅ API is running!');
});

// Optional: A route to manually trigger the missed dose checker (for testing)
app.get('/api/check-missed', async (req, res) => {
    // Calling the require here will re-run the cron schedule setup,
    // but the actual cron job will run on its schedule.
    // For manual triggering, you'd need to expose the function directly.
    // However, if the job is already scheduled, it will run as per schedule.
    // For immediate testing, you could make the cron job's function exportable and call it here.
    // For now, this just confirms the module is loaded.
    require('./utils/missedDoseChecker');
    res.send('Missed dose checker module loaded. It runs on its own schedule.');
});

// Connect to MongoDB and Start Server
mongoose.connect(URI)
    .then(() => {
        console.log('✅ MongoDB connected successfully!');
        app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
    })
    .catch(err => {
        console.error('❌ MongoDB connection failed:', err.message);
        // Exit process with failure
        process.exit(1);
    });