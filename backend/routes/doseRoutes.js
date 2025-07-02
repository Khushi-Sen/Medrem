const express = require('express');
const router = express.Router();
const Dose = require('../models/dose');
const Medication = require('../models/medication');

router.post('/update', async (req, res) => {
  const { userId, medicationId, date, status } = req.body;

  try {
    const formattedDate = new Date(date).toISOString().split('T')[0];

    let dose = await Dose.findOne({ userId, medicationId, date: formattedDate });

    if (dose) {
      dose.status = status;
      await dose.save();
    } else {
      dose = new Dose({ userId, medicationId, date: formattedDate, status });
      await dose.save();
    }

    // ✅ Decrease remaining pills if dose marked as taken
    if (status === 'taken') {
      await Medication.findByIdAndUpdate(medicationId, {
        $inc: { remainingPills: -1 }
      });
    }

    res.status(200).json({ message: 'Dose updated', dose });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update dose' });
  }
});


module.exports = router;
