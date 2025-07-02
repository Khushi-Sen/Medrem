const mongoose = require('mongoose');

const doseSchema = new mongoose.Schema({
  userId: { type: String, required: true },
  medicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Medication', required: true },
  date: { type: String, required: true }, // e.g., "2025-06-24"
  status: { type: String, enum: ['taken', 'missed'], required: true },
});

module.exports = mongoose.model('Dose', doseSchema);
