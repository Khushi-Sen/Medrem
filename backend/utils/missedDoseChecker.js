const cron = require('node-cron');
const Medication = require('../models/medication');
const mongoose = require('mongoose');

// Runs every 10 minutes
cron.schedule('*/10 * * * *', async () => {
  console.log('⏱️ Running missed dose checker...');

  const now = new Date();

  const medications = await Medication.find();

  for (const med of medications) {
    if (!med.times || med.times.length === 0) continue;

    for (const scheduledTime of med.times) {
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const [hour, minute] = scheduledTime.split(':').map(Number);
      const scheduledDate = new Date(today);
      scheduledDate.setHours(hour);
      scheduledDate.setMinutes(minute);
      scheduledDate.setSeconds(0);

      const gracePeriod = 30 * 60 * 1000; // 30 mins
      const missedWindowStart = new Date(scheduledDate.getTime() + gracePeriod);
      const missedWindowEnd = new Date(scheduledDate.getTime() + 90 * 60 * 1000); // cap range

      // Check if time has passed and not already marked as taken or missed
      const alreadyLogged = med.takenHistory.some(entry =>
        Math.abs(new Date(entry.timestamp) - scheduledDate) < 30 * 60 * 1000
      );

      if (now > missedWindowStart && now < missedWindowEnd && !alreadyLogged) {
        med.takenHistory.push({
          status: 'missed',
          timestamp: scheduledDate,
        });
        await med.save();
        console.log(`❌ Marked ${med.name} as missed at ${scheduledDate}`);
      }
    }
  }
});
