
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();
require('./utils/missedDoseChecker'); 

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5000;
const URI = process.env.MONGODB_URI;

// ✅ Import Routes
const medicationRoutes = require('./routes/medicationRoutes');
const doseRoutes = require('./routes/doseRoutes'); // ✅ NEW ROUTE

// ✅ Use Routes
app.use('/api/medications', medicationRoutes);
app.use('/api/doses', doseRoutes); // ✅ NEW ROUTE

// Default Route
app.get('/', (req, res) => {
  res.send('✅ API is running!');
});

app.get('/api/check-missed', async (req, res) => {
  require('./utils/missedDoseChecker');
  res.send('Missed dose check triggered');
});

// ✅ Connect to MongoDB and Start Server
mongoose.connect(URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
  })
  .catch(err => {
    console.error('❌ MongoDB connection failed:', err.message);
    process.exit(1);
  });
