// backend/models/Medication.js
const mongoose = require('mongoose');

// The 'takenSchema' is not directly used in your main medicationSchema
// for the takenHistory array. The structure is defined inline.
// So, you can safely remove this 'takenSchema' if you wish, or just leave it commented.
// const takenSchema = new mongoose.Schema({
//     date: String,
//     taken: Boolean
// }, { _id: false });

const medicationSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    name: { type: String, required: true },
    dose: { type: String, required: true },

    // Changed 'time' to 'doseTimes' and made it an array of strings
    // This will hold times like ['08:00', '14:00', '20:00']
    doseTimes: { type: [String], default: [] },

    // New field: relation to meal
    mealRelation: {
        type: String,
        enum: ['Before Meal', 'After Meal', 'Anytime', 'With Food'], // Example enums, adjust as needed
        default: 'Anytime'
    },

    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },

    // New field: Total quantity of the medication in the package/bottle
    totalTabs: { type: Number, required: true, default: 0 },

    // Renamed from 'remainingQuantity' to 'currentTabs' for consistency with Flutter
    currentTabs: { type: Number, required: true, default: 0 },

    // `refillThreshold` in backend corresponds to `reorderPoint` in frontend
    refillThreshold: { type: Number, default: 5 }, // Default threshold for low stock

    // History of taken/missed doses
    takenHistory: [
        {
            status: { type: String, enum: ['taken', 'missed'], required: true },
            timestamp: { type: Date, required: true },
        },
    ],
}, { timestamps: true }); // Added timestamps for createdAt, updatedAt

// Fix: Use mongoose.models to avoid OverwriteModelError in hot-reloading environments
module.exports = mongoose.models.Medication || mongoose.model('Medication', medicationSchema);