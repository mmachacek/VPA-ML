const fs = require('fs');
const path = require('path');

// Configuration
const BASE_DIR = __dirname;
const CURRENCIES = ["AUDUSDM5", "EURUSDM5", "GBPUSDM5", "USDCHFM5", "USDJPYM5"]; // Array of currencies
const MODEL_DIRS = [
    '5 Bars', '10 Bars', '20 Bars',
    '30 Bars', '40 Bars', '50 Bars', '60 Bars'
];

// Read and parse JSON log file
function readPredictions(filePath) {
    if (!fs.existsSync(filePath)) {
        console.warn(`[Warning] Log file not found, skipping: ${filePath}`);
        return null;
    }
    try {
        const fileContent = fs.readFileSync(filePath, 'utf8');
        const parsedData = JSON.parse(fileContent);
        return Array.isArray(parsedData) ? parsedData : (parsedData.predictions || null);
    } catch (err) {
        console.error(`[Error] Failed to read or process file ${filePath}: ${err.message}`);
        return null;
    }
}

// Analyze all models for a single currency
async function analyzeModelsForCurrency(currency) {
    console.log(`\n--- Starting analysis for currency: ${currency} ---`);

    const allPredictionsByModel = {};
    let globalMinPred = 1.0;
    let globalMaxPred = 0.0;

    for (const dir of MODEL_DIRS) {
        const filePath = path.join(BASE_DIR, currency, dir, 'predictions_log.json');
        const predictions = readPredictions(filePath);
        if (predictions && predictions.length > 0) {
            allPredictionsByModel[dir] = predictions;
            for (const pred of predictions) {
                if (pred.predictionValue < globalMinPred) globalMinPred = pred.predictionValue;
                if (pred.predictionValue > globalMaxPred) globalMaxPred = pred.predictionValue;
            }
        }
    }

    if (Object.keys(allPredictionsByModel).length === 0) {
        console.log(`No valid prediction files found for ${currency}. Skipping.`);
        return;
    }

    console.log(`Global prediction range for ${currency}: ${globalMinPred.toFixed(4)} to ${globalMaxPred.toFixed(4)}`);

    const thresholdsToTest = [];
    const startThreshold = Math.floor(globalMinPred * 1000);
    const endThreshold = Math.ceil(globalMaxPred * 1000);
    for (let i = startThreshold; i <= endThreshold; i++) {
        thresholdsToTest.push(i / 1000);
    }

    console.log(`Testing ${thresholdsToTest.length} thresholds for ${currency}...`);

    const results = [];

    for (const modelName in allPredictionsByModel) {
        const predictions = allPredictionsByModel[modelName];
        const totalPredictions = predictions.length;

        let bestResult = {
            accuracy: 0,
            threshold: 0,
            correctCount: 0,
        };

        for (const threshold of thresholdsToTest) {
            let currentCorrectCount = 0;

            for (const pred of predictions) {
                const predictedClass = (pred.predictionValue >= threshold) ? 'SuccessfulPinBar' : 'FailedPinBar';
                if (predictedClass === pred.groundTruth) {
                    currentCorrectCount++;
                }
            }

            const currentAccuracy = (currentCorrectCount / totalPredictions) * 100;

            if (currentAccuracy > bestResult.accuracy) {
                bestResult = {
                    accuracy: currentAccuracy,
                    threshold: threshold,
                    correctCount: currentCorrectCount,
                };
            }
        }

        results.push({ modelName, totalPredictions, ...bestResult });
    }

    console.log(`\n--- Model Comparison Summary for ${currency} ---`);
    console.log('Model         | Optimal threshold | Best accuracy     | Correct          | Total');
    console.log('--------------|-------------------|-------------------|------------------|--------');

    for (const res of results) {
        const modelStr = res.modelName.padEnd(13);
        const thresholdStr = res.threshold.toFixed(4).padEnd(17);
        const accuracyStr = `${res.accuracy.toFixed(2)}%`.padEnd(17);
        const correctStr = `${res.correctCount}`.padEnd(16);
        const totalStr = `${res.totalPredictions}`;

        console.log(`${modelStr} | ${thresholdStr} | ${accuracyStr} | ${correctStr} | ${totalStr}`);
    }
}

// Main function to analyze all currencies sequentially
async function analyzeAllCurrencies() {
    for (const currency of CURRENCIES) {
        await analyzeModelsForCurrency(currency);
    }
    console.log('\nAll currency analyses completed.');
}

// Start analysis
analyzeAllCurrencies();
