const express = require('express');
const router = express.Router();
const Medication = require('../models/Medication');


//  Add new medication
router.post('/add', async (req, res) => {
  try {
    const newMed = new Medication(req.body);
    await newMed.save();
    res.status(200).json({ message: 'Medication saved successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to save medication', details: err });
  }
});

//  Update medication by ID
router.put('/:id', async (req, res) => {
  try {
    const updatedMed = await Medication.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!updatedMed) {
      return res.status(404).json({ error: 'Medication not found' });
    }
    res.status(200).json(updatedMed);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update medication', details: err });
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
    res.status(500).json({ error: 'Failed to delete medication', details: err });
  }
});

// ✅ POST /api/medications/:id/refill
router.post('/:id/refill', async (req, res) => {
  try {
    const med = await Medication.findById(req.params.id);
    if (!med) return res.status(404).json({ error: 'Medication not found' });

    med.remainingPills = med.totalPills;
    await med.save();

    res.status(200).json({ message: 'Medication refilled successfully', medication: med });
  } catch (err) {
    res.status(500).json({ error: 'Failed to refill medication', details: err });
  }
});


//  Get all medications for a user
router.get('/', async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId query parameter is required' });
  }

  try {
    const meds = await Medication.find({ userId });
    res.status(200).json(meds);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch medications', details: err });
  }
});

// ✅ GET /api/medications/low-stock?userId=123
router.get('/low-stock', async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId query parameter is required' });
  }

  try {
    const lowStockMeds = await Medication.find({
      userId,
      $expr: { $lte: ["$remainingPills", "$refillThreshold"] }
    });

    res.status(200).json(lowStockMeds);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch low stock medications', details: err });
  }
});

// ✅ POST /api/medications/dose-history
router.post('/dose-history', async (req, res) => {
  const { userId, medication, status, timestamp } = req.body;

  try {
    const med = await Medication.findOne({ userId, name: medication });

    if (!med) {
      return res.status(404).json({ message: 'Medication not found' });
    }

    med.takenHistory.push({
      status,
      timestamp: new Date(timestamp),
    });

    await med.save();

    res.status(200).json({ message: 'Dose history updated successfully' });
  } catch (error) {
    console.error('Error recording dose:', error);
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
        medication: med.name,
        status: entry.status,
        timestamp: entry.timestamp,
      }))
    );

    res.status(200).json(history);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch dose history' });
  }
});

// ✅ Clear all dose history for a user
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
