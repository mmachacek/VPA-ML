const express = require('express');
const tf = require('@tensorflow/tfjs-node');
const fs = require('fs');
const path = require('path');

const DEBUG = false;

// Custom attention layer for TensorFlow models
class AttentionLayer extends tf.layers.Layer {
    constructor(config) { super(config); this.supportsMasking = true; }
    call(inputs) {
        return tf.tidy(() => {
            const input = Array.isArray(inputs) ? inputs[0] : inputs;
            const energy = tf.layers.dense({ units: 1, activation: 'tanh' }).apply(input);
            const energySqueezed = tf.squeeze(energy, [-1]);
            const attentionWeights = tf.softmax(energySqueezed);
            const attentionWeightsExpanded = tf.expandDims(attentionWeights, -1);
            return tf.mul(input, attentionWeightsExpanded);
        });
    }
    computeOutputShape(inputShape) { return inputShape; }
    static get className() { return 'AttentionLayer'; }
}
tf.serialization.registerClass(AttentionLayer);

const app = express();
const PORT = 8078;
app.use(express.text({ type: '*/*', limit: '10mb' }));

// Active trading sessions and loaded models caches
const activeSessions = new Map();
const loadedModels = new Map();

// Trading session class to track session state
class TradingSession {
    constructor(symbol, timeframe) {
        this.symbol = symbol;
        this.timeframe = timeframe;
        this.logsResetFor = new Set();
        this.startTime = new Date();
    }
}

// Evaluate accuracy from a predictions log file and append summary
function evaluateAndLogAccuracy(logFilePath) {
    if (!fs.existsSync(logFilePath)) return;
    try {
        const fileContent = fs.readFileSync(logFilePath, 'utf8');
        let predictions = JSON.parse(fileContent);
        if (!Array.isArray(predictions) && predictions.predictions) {
            predictions = predictions.predictions;
        }
        const totalPredictions = predictions.length;
        if (totalPredictions === 0) {
            console.log(`[Info] Log file at ${logFilePath} contains no predictions to evaluate.`);
            return;
        }
        const correctPredictions = predictions.filter(p => p.isCorrect).length;
        const accuracy = (correctPredictions / totalPredictions) * 100;
        const summary = {
            totalPredictions: totalPredictions,
            correctPredictions: correctPredictions,
            incorrectPredictions: totalPredictions - correctPredictions,
            accuracy: `${accuracy.toFixed(2)}%`
        };
        const finalLogObject = {
            summary: summary,
            predictions: predictions
        };
        fs.writeFileSync(logFilePath, JSON.stringify(finalLogObject, null, 2), 'utf8');
        console.log(`\n--- Model Evaluation Summary ---`);
        console.log(`  File: ${path.basename(path.dirname(logFilePath))}/${path.basename(logFilePath)}`);
        console.log(`  Total Predictions: ${summary.totalPredictions}`);
        console.log(`  Correct: ${summary.correctPredictions}`);
        console.log(`  Accuracy: ${summary.accuracy}`);
        console.log(`----------------------------------\n`);
    } catch (err) {
        console.error(`[Error] Failed to evaluate log file ${logFilePath}:`, err.message);
    }
}

// Main POST endpoint for session control and prediction
app.post('/', async (req, res) => {
    try {
        const requestData = req.body.toString();
        if (!requestData) {
            return res.status(400).send('Bad Request: Empty body.');
        }

        // Handle session start
        if (requestData.includes('-Start')) {
            const [symbol, timeframeStr] = requestData.split('-');
            const timeframe = timeframeStr.replace('M', '');
            const sessionKey = `${symbol}-${timeframe}`;
            const session = new TradingSession(symbol, timeframe);
            activeSessions.set(sessionKey, session);
            console.log(`[Info] Session started for ${sessionKey}.`);
            return res.send('Session started');
        }

        // Handle session end and evaluate model accuracy
        if (requestData.includes('-End')) {
            const [symbol, timeframeStr] = requestData.split('-');
            const timeframe = timeframeStr.replace('M', '');
            const sessionKey = `${symbol}-${timeframe}`;
            const activeSession = activeSessions.get(sessionKey);

            if (activeSession) {
                console.log(`[Info] Session ending for ${sessionKey}. Evaluating model performance...`);
                for (const barCount of activeSession.logsResetFor) {
                    const logFilePath = path.join(__dirname, `${symbol}M${timeframe}`, `${barCount} Bars`, 'predictions_log.json');
                    evaluateAndLogAccuracy(logFilePath);
                }
                activeSessions.delete(sessionKey);
            }
            return res.send('Session ended and performance evaluated.');
        }

        // Handle prediction requests and log results
        if (requestData.includes(';')) {
            const sessionKey = Array.from(activeSessions.keys())[0];
            const activeSession = activeSessions.get(sessionKey);
            if (!activeSession) return res.status(400).send('No active session.');

            const [objectName, dataStr] = requestData.split(';');
            const featureData = [];
            dataStr.split('-').forEach(pair => {
                const values = pair.split(',');
                if (values.length === 2) {
                    featureData.push(parseInt(values[0]));
                    featureData.push(parseFloat(values[1]));
                }
            });
            if (featureData.length === 0) return res.status(400).send('Bad Request: Invalid feature data format.');

            const barCount = detectBarCount(featureData.length);
            const logFilePath = path.join(__dirname, `${activeSession.symbol}M${activeSession.timeframe}`, `${barCount} Bars`, 'predictions_log.json');

            if (!activeSession.logsResetFor.has(barCount)) {
                if (fs.existsSync(logFilePath)) {
                    try {
                        fs.unlinkSync(logFilePath);
                    } catch (err) {
                        console.error(`[Error] Could not delete log file: ${err.message}`);
                    }
                }
                activeSession.logsResetFor.add(barCount);
            }

            const result = await makePrediction(activeSession, featureData);
            const groundTruth = objectName.includes('SuccessfulPinBar') ? 'SuccessfulPinBar' : 'FailedPinBar';
            const logEntry = {
                barTimestamp: objectName.split('_').pop() || 'UnknownTime',
                groundTruth: groundTruth,
                prediction: result.classification,
                predictionValue: result.value,
                isCorrect: groundTruth === result.classification
            };
            logPredictionResult(logEntry, logFilePath);
            const response = `${activeSession.symbol},M${activeSession.timeframe},${result.classification},${result.value.toFixed(6)}`;
            console.log(`Logged prediction to ${path.basename(path.dirname(logFilePath))}/${path.basename(logFilePath)}`);
            return res.send(response);
        }
        
        return res.status(400).send('Unknown or unused message format');

    } catch (error) {
        console.error('Request handling error:', error.message);
        res.status(500).send(`Server error: ${error.message}`);
    }
});

app.listen(PORT, () => {
    console.log(`Node.js Forex NN Server listening on port ${PORT}`);
});

// Append prediction result to log file (creates or updates predictions_log.json)
function logPredictionResult(logEntry, logFilePath) {
    let logs = [];
    try {
        if (fs.existsSync(logFilePath)) {
            const data = fs.readFileSync(logFilePath, 'utf8');
            if (data) {
                const parsedData = JSON.parse(data);
                logs = Array.isArray(parsedData) ? parsedData : parsedData.predictions || [];
            }
        }
    } catch (err) {
        logs = [];
    }
    logs.push(logEntry);
    fs.writeFileSync(logFilePath, JSON.stringify(logs, null, 2), 'utf8');
}

// Detect bar count from feature vector length (2 values per bar: volume, close)
function detectBarCount(featureLength) {
    const barCount = Math.floor(featureLength / 2);
    const supportedCounts = [5, 10, 20, 30, 40, 50, 60];
    return supportedCounts.reduce((prev, curr) => 
        (Math.abs(curr - barCount) < Math.abs(prev - barCount) ? curr : prev)
    );
}

// Run prediction using the loaded model and normalized input data
async function makePrediction(session, featureData) {
    const barCount = detectBarCount(featureData.length);
    const modelConfig = await loadModelForConfig(session.symbol, session.timeframe, barCount);
    if (!modelConfig) {
        throw new Error(`Model configuration not available for ${session.symbol}-M${session.timeframe} with ${barCount} bars.`);
    }
    const normalizedData = normalizeData(featureData, modelConfig.maxValues[0], modelConfig.maxValues[1]);
    const expectedLength = modelConfig.inputLength;
    if (normalizedData.length !== expectedLength) {
        while (normalizedData.length < expectedLength) normalizedData.push(0);
        if (normalizedData.length > expectedLength) normalizedData.length = expectedLength;
    }
    const inputTensor = tf.tensor2d([normalizedData], [1, expectedLength]);
    const prediction = modelConfig.model.predict(inputTensor);
    const predictionValue = await prediction.data();
    tf.dispose([inputTensor, prediction]);
    return {
        classification: predictionValue[0] >= 0.5 ? 'SuccessfulPinBar' : 'FailedPinBar',
        value: predictionValue[0],
    };
}

// Load TensorFlow model and max value config for a given symbol, timeframe, and bar count
async function loadModelForConfig(symbol, timeframe, barCount) {
    const configKey = `${symbol}-${timeframe}-${barCount}`;
    if (loadedModels.has(configKey)) {
        return loadedModels.get(configKey);
    }
    const basePath = path.join(__dirname, `${symbol}M${timeframe}`, `${barCount} Bars`);
    if (!fs.existsSync(basePath)) {
        console.error(`[Error] Directory not found: ${basePath}`);
        return null;
    }
    const filesInDir = fs.readdirSync(basePath);
    const configFileName = filesInDir.find(file => file.endsWith('_maxValueVolume.json'));
    if (!configFileName) {
        console.error(`[Error] No '*_maxValueVolume.json' file found in: ${basePath}`);
        return null;
    }
    const maxValuesPath = path.join(basePath, configFileName);
    const modelPath = path.join(basePath, 'volume-nn-model.json');
    if (!fs.existsSync(modelPath) || !fs.existsSync(maxValuesPath)) {
         console.error(`[Error] Model or config file is missing in path: ${basePath}`);
         return null;
    }
    const maxValuesData = JSON.parse(fs.readFileSync(maxValuesPath, 'utf8'));
    const model = await tf.loadLayersModel(`file://${modelPath}`);
    const config = { model, maxValues: maxValuesData.maxValues, inputLength: maxValuesData.maxInputLength };
    loadedModels.set(configKey, config);
    console.log(`[Success] Loaded model and config for ${configKey}`);
    return config;
}

// Normalize input data using maxClose and maxVolume values
function normalizeData(featureData, maxClose, maxVolume) {
    const normalized = [];
    const safeMaxVolume = maxVolume > 0 ? maxVolume : 1;
    const safeMaxClose = maxClose > 0 ? maxClose : 1;
    for (let i = 0; i < featureData.length; i += 2) {
        const volume = featureData[i];
        const close = featureData[i + 1];
        if (typeof volume !== 'undefined' && typeof close !== 'undefined') {
            normalized.push(close / safeMaxClose);
            normalized.push(volume / safeMaxVolume);
        }
    }
    return normalized;
}
