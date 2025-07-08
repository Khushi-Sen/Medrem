// backend/routes/medicationRoutes.js
const express = require('express');
const router = express.Router();
const Medication = require('../models/Medication');

// Add new medication
router.post('/add', async (req, res) => {
    try {
        // Ensure new fields are properly initialized when a medication is added.
        const newMedData = {
            ...req.body,
            // currentTabs should be initialized from totalTabs if not provided
            currentTabs: req.body.currentTabs !== undefined ? req.body.currentTabs : (req.body.totalTabs || 0),
            // Ensure doseTimes is an array. If 'time' was still sent by an older client, convert it.
            doseTimes: Array.isArray(req.body.doseTimes) ? req.body.doseTimes : (req.body.time ? [req.body.time] : []),
            // 'dose' field is expected in req.body because it's in the schema as required.
        };
        const newMed = new Medication(newMedData); // Mongoose will now validate 'dose'
        await newMed.save();
        res.status(201).json({ message: 'Medication saved successfully', medication: newMed });
    } catch (err) {
        console.error('Error adding medication:', err);
        res.status(500).json({ error: 'Failed to save medication', details: err.message });
    }
});

// Update medication by ID
router.put('/:id', async (req, res) => {
    try {
        const updateData = { ...req.body };
        // Ensure doseTimes is correctly formatted as an array on update
        if (updateData.doseTimes && !Array.isArray(updateData.doseTimes)) {
            updateData.doseTimes = [updateData.doseTimes];
        } else if (!updateData.doseTimes && updateData.time) {
            updateData.doseTimes = [updateData.time];
            delete updateData.time;
        }
        // 'dose' field should be present in updateData if it's being updated.

        const updatedMed = await Medication.findByIdAndUpdate(req.params.id, updateData, { new: true, runValidators: true });
        if (!updatedMed) {
            return res.status(404).json({ error: 'Medication not found' });
        }
        res.status(200).json(updatedMed);
    } catch (err) {
        console.error('Error updating medication:', err);
        res.status(500).json({ error: 'Failed to update medication', details: err.message });
    }
});

// POST /api/medications/:id/logDose
router.post('/:id/logDose', async (req, res) => {
  const { id } = req.params;
  const { status, timestamp, dose } = req.body; // 'dose' will now be like "2" or "2 tablets"

  try {
    const medication = await Medication.findById(id);

    if (!medication) {
      return res.status(404).json({ message: 'Medication not found' });
    }

    // 1. Determine the quantity to subtract
    let quantityToSubtract = 1; // Default to 1 if parsing fails or dose is not numeric

    if (dose) {
      // Attempt to extract a number from the 'dose' string
      const numericPart = dose.match(/\d+(\.\d+)?/); // Matches integers or decimals
      if (numericPart && numericPart[0]) {
        quantityToSubtract = parseFloat(numericPart[0]);
      }
    }
    
    // Ensure quantityToSubtract is a positive number, default to 1 if it's 0 or invalid after parsing
    if (isNaN(quantityToSubtract) || quantityToSubtract <= 0) {
        quantityToSubtract = 1;
    }

    // 2. Decrement currentTabs by the determined quantity
    if (medication.currentTabs !== undefined && medication.currentTabs !== null) {
      medication.currentTabs -= quantityToSubtract;

      // Optional: Prevent currentTabs from going below zero
      if (medication.currentTabs < 0) {
        medication.currentTabs = 0;
      }
    } else {
      // Handle case where currentTabs might be undefined/null (shouldn't happen if schema is good)
      console.warn(`Medication ${id} has undefined/null currentTabs. Skipping decrement.`);
    }

    // 3. Add to takenHistory (assuming your schema includes 'dose' here)
    medication.takenHistory.push({ status, timestamp, dose });

    // Optional: Check for refill threshold
    if (medication.currentTabs <= medication.refillThreshold) {
      // You can add logic here to send a notification for refill, etc.
      console.log(`Medication ${medication.name} is low on tabs! Current: ${medication.currentTabs}`);
    }

    await medication.save();

    res.status(200).json({ message: 'Dose logged successfully', medication });

  } catch (error) {
    console.error('Error logging dose:', error);
    // More detailed error for validation
    if (error.name === 'ValidationError') {
      return res.status(400).json({ message: error.message, errors: error.errors });
    }
    res.status(500).json({ message: 'Server error during dose logging' });
  }
});


// Delete medication by ID
router.delete('/:id', async (req, res) => {
    try {
        const deletedMed = await Medication.findByIdAndDelete(req.params.id);
        if (!deletedMed) {
            return res.status(404).json({ error: 'Medication not found' });
        }
        res.status(200).json({ message: 'Medication deleted successfully' });
    } catch (err) {
        console.error('Error deleting medication:', err);
        res.status(500).json({ error: 'Failed to delete medication', details: err.message });
    }
});

router.post('/:id/refill', async (req, res) => {
  const { id } = req.params;
  const { quantityToAdd } = req.body;

  if (typeof quantityToAdd !== 'number' || quantityToAdd <= 0) {
    return res.status(400).json({ message: 'quantityToAdd must be a positive number' });
  }

  try {
    const medication = await Medication.findById(id);

    if (!medication) {
      return res.status(404).json({ message: 'Medication not found' });
    }

    // Increase the currentTabs by the quantityToAdd
    medication.currentTabs += quantityToAdd;

    // ADD THIS LINE: Increase totalTabs by the quantityToAdd as well
    medication.totalTabs += quantityToAdd;

    await medication.save();

    res.status(200).json({ message: 'Medication refilled successfully', medication });

  } catch (error) {
    console.error('Error refilling medication:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get all medications for a user
router.get('/', async (req, res) => {
    const { userId } = req.query;

    if (!userId) {
        return res.status(400).json({ error: 'userId query parameter is required' });
    }

    try {
        const meds = await Medication.find({ userId });
        // The retrieved 'meds' will now have the correct fields (doseTimes, mealRelation, currentTabs, totalTabs)
        // because we updated the schema in models/Medication.js.
        res.status(200).json(meds);
    } catch (err) {
        console.error('Error fetching medications:', err);
        res.status(500).json({ error: 'Failed to fetch medications', details: err.message });
    }
});

// GET /api/medications/low-stock?userId=123
router.get('/low-stock', async (req, res) => {
    const { userId } = req.query;

    if (!userId) {
        return res.status(400).json({ error: 'userId query parameter is required' });
    }

    try {
        // Use 'currentTabs' for checking low stock
        const lowStockMeds = await Medication.find({
            userId,
            $expr: { $lte: ["$currentTabs", "$refillThreshold"] }
        });

        res.status(200).json(lowStockMeds);
    } catch (err) {
        console.error('Error fetching low stock medications:', err);
        res.status(500).json({ error: 'Failed to fetch low stock medications', details: err.message });
    }
});

// NEW: POST /api/medications/:id/logDose
// This is the endpoint your Flutter app now calls when 'Taken' or 'Missed' is pressed.
router.post('/:id/logDose', async (req, res) => {
    const { status, timestamp } = req.body; // Expects status ('taken' or 'missed') and timestamp

    try {
        const medication = await Medication.findById(req.params.id);

        if (!medication) {
            return res.status(404).json({ message: 'Medication not found' });
        }

        // Add the dose event to the takenHistory array
        medication.takenHistory.push({
            status,
            timestamp: new Date(timestamp), // Ensure timestamp is a Date object
        });

        // If the dose is marked as 'taken', decrement the currentTabs
        if (status === 'taken') {
            if (medication.currentTabs > 0) {
                medication.currentTabs -= 1;
            } else {
                console.warn(`Attempted to mark taken for ${medication.name} (ID: ${req.params.id}) but currentTabs is already 0. No decrement applied.`);
                // You might choose to send a different status code or message here
                // if marking taken when out of stock is considered an error.
            }
        }

        await medication.save();

        res.status(200).json({ message: `Dose marked as ${status} successfully`, medication }); // Return updated medication
    } catch (error) {
        console.error('Error logging dose:', error);
        res.status(500).json({ error: 'Failed to log dose', details: error.message });
    }
});

// Existing /api/medications/dose-history routes (keep these)
router.post('/dose-history', async (req, res) => {
    const { userId, medication, status, timestamp } = req.body; // Note: this uses 'medication' (name) not ID

    try {
        const med = await Medication.findOne({ userId, name: medication });

        if (!med) {
            return res.status(404).json({ message: 'Medication not found' });
        }

        med.takenHistory.push({
            status,
            timestamp: new Date(timestamp),
        });

        // No quantity decrement here, as this route seems to be for historical logging
        // rather than live dose taking affecting current stock.
        // The /:id/logDose route handles that.

        await med.save();

        res.status(200).json({ message: 'Dose history updated successfully' });
    } catch (error) {
        console.error('Error recording dose (old route):', error);
        res.status(500).json({ error: 'Failed to record dose' });
    }
});

// Get all dose history for a user
router.get('/dose-history', async (req, res) => {
    const { userId } = req.query;

    if (!userId) {
        return res.status(400).json({ error: 'userId query parameter is required' });
    }

    try {
        const meds = await Medication.find({ userId });

        const history = meds.flatMap(med =>
            med.takenHistory.map(entry => ({
                medication: med.name, // Use medication name
                status: entry.status,
                timestamp: entry.timestamp,
            }))
        );

        // Sort history by timestamp, newest first
        history.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

        res.status(200).json(history);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch dose history' });
    }
});

// Clear all dose history for a user
router.delete('/dose-history/clear', async (req, res) => {
    const { userId } = req.body;

    if (!userId) {
        return res.status(400).json({ error: 'userId is required in body' });
    }

    try {
        const result = await Medication.updateMany(
            { userId },
            { $set: { takenHistory: [] } }
        );

        res.status(200).json({
            message: 'Dose history cleared',
            modified: result.modifiedCount,
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to clear dose history' });
    }
});

module.exports = router;

