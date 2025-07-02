const mongoose = require('mongoose');

const takenSchema = new mongoose.Schema({
  date: String,
  taken: Boolean
}, { _id: false });

const medicationSchema = new mongoose.Schema({
  userId: String,
  name: String,
  dose: String,
  time: String,
  startDate: Date,
  endDate: Date,
  remainingQuantity: Number,
  refillThreshold: Number,
  takenHistory: [
    {
      status: { type: String, enum: ['taken', 'missed'], required: true },
      timestamp: { type: Date, required: true },
    },
  ],
});

// ✅ Fix: Use mongoose.models to avoid OverwriteModelError
module.exports = mongoose.models.Medication || mongoose.model('Medication', medicationSchema);
