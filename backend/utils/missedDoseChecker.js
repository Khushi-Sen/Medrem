// backend/utils/missedDoseChecker.js
const cron = require('node-cron');
const Medication = require('../models/Medication'); // Ensure casing matches: Medication.js
const mongoose = require('mongoose'); // Already imported, good

// Runs every 10 minutes
cron.schedule('*/10 * * * *', async () => {
    console.log(`⏱️ Running missed dose checker at ${new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' })}...`); // Added local time zone for clarity

    const now = new Date();

    try {
        const medications = await Medication.find({}); // Fetch all medications

        for (const med of medications) {
            // Check if doseTimes exist and is an array
            if (!med.doseTimes || !Array.isArray(med.doseTimes) || med.doseTimes.length === 0) {
                continue; // Skip if no scheduled times
            }

            for (const scheduledTimeStr of med.doseTimes) { // Iterate through doseTimes array
                // Parse the scheduled time string (e.g., "08:00")
                const [hour, minute] = scheduledTimeStr.split(':').map(Number);

                // Create a scheduled Date object for *today* at the scheduled time
                const scheduledDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0);

                // Define grace period for "taken" before considering it "missed"
                const gracePeriodMillis = 30 * 60 * 1000; // 30 minutes
                const considerationWindowEndMillis = 120 * 60 * 1000; // Consider up to 2 hours after scheduled time for marking missed (adjust as needed)

                const missedWindowStart = new Date(scheduledDate.getTime() + gracePeriodMillis);
                const missedWindowEnd = new Date(scheduledDate.getTime() + considerationWindowEndMillis);

                // Check if this specific dose for this scheduled time on this day has *already been logged*
                const alreadyLogged = med.takenHistory.some(entry => {
                    const entryTimestamp = new Date(entry.timestamp);
                    // Check if the log entry falls within a reasonable window around the scheduled time for *today*
                    // This prevents re-logging a dose if it was taken/missed slightly before/after the exact schedule
                    const twentyFourHoursAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000));
                    return entryTimestamp > twentyFourHoursAgo && // Only check within the last 24 hours
                           entryTimestamp.getFullYear() === scheduledDate.getFullYear() &&
                           entryTimestamp.getMonth() === scheduledDate.getMonth() &&
                           entryTimestamp.getDate() === scheduledDate.getDate() &&
                           Math.abs(entryTimestamp.getTime() - scheduledDate.getTime()) < gracePeriodMillis; // Within grace period of scheduled time
                });


                // If the current time is past the grace period, and within the missed window,
                // and the dose hasn't been logged yet for today's scheduled time, mark as missed.
                if (now > missedWindowStart && now < missedWindowEnd && !alreadyLogged) {
                    med.takenHistory.push({
                        status: 'missed',
                        timestamp: scheduledDate, // Log the scheduled time as the missed time
                    });
                    await med.save();
                    console.log(`❌ Marked ${med.name} (ID: ${med._id}) as missed for ${scheduledTimeStr} on ${scheduledDate.toLocaleDateString()} at ${new Date().toLocaleTimeString('en-US', { timeZone: 'Asia/Kolkata' })}`);
                }
            }
        }
    } catch (error) {
        console.error('Error in missed dose checker:', error);
    }
});