const bodyParser = require("body-parser");
const express = require("express");
const fs = require("fs");
const app = express();
const port = process.env.PORT || 8078;
const server = app.listen(port, _ => console.log(`Server running on port ${port}`));

// Configuration flags and parameters
const binaryInput = true;
const negativeValues = false;
const sampleTo16Bit = false;
const generateRNNData = false;
const normalizeForNN = true; // Normalize data for neural network training
const saveMaxValueVolumeForDenormalization = true;
const dataAugmentationBuySell = false;
const dataAugmentationBinaryBuySell = false;
const dataMultiplication = false;
const dataMultiplier = 4;
const makeNumberOfFormationsEqual = true; // Balance classes in dataset
let dataAugmentationPercentage = 0.001;
const generateTestData = false; // Whether to generate separate test dataset
const testDataPercentage = 0.20; // Percentage of data reserved for testing
const shuffleData = false; // Shuffle data before saving
const filePrefix = "ICMarkets_Test"; // Prefix for output files
const outputPath = "./JSON"; // Directory to save output files

// State variables for data collection
let candleStream = false;
let symbol;
let timeframe;
let dateFrom;
let dateTo;
let maxInputLength = 0;
let maxValues = {};
let xsRaw = [];       // Feature arrays for training
let ysRaw = [];       // Label arrays for training
let xsRawTest = [];   // Feature arrays for testing
let ysRawTest = [];   // Label arrays for testing
let trainDataCounter;
let testDataCounter;

// Create output directory if it doesn't exist
fs.stat(outputPath, notFound => {
    if(notFound) {
        fs.mkdir(outputPath, err => {
            if(err) {
                console.log("Unable to create output folder");
            }
            else {
                console.log("Output folder not found, was created");
            }
        });
    }
});

// Shuffle training and test datasets in-place
function shuffle() {
    if (!xsRaw.length) return; // Prevent shuffle if array is empty
    
    let currentIndex = xsRaw.length;
    let tempValueXs, tempValueYs, randomIndex;

    while(0 !== currentIndex) {
        randomIndex = Math.floor(Math.random() * currentIndex);
        currentIndex -= 1;

        tempValueXs = xsRaw[currentIndex];
        tempValueYs = ysRaw[currentIndex];
        xsRaw[currentIndex] = xsRaw[randomIndex];
        ysRaw[currentIndex] = ysRaw[randomIndex];
        xsRaw[randomIndex] = tempValueXs;
        ysRaw[randomIndex] = tempValueYs;
    }
    
    if(generateTestData && xsRawTest.length) {
        currentIndex = xsRawTest.length;
        
        while(0 !== currentIndex) {
            randomIndex = Math.floor(Math.random() * currentIndex);
            currentIndex -= 1;
    
            tempValueXs = xsRawTest[currentIndex];
            tempValueYs = ysRawTest[currentIndex];
            xsRawTest[currentIndex] = xsRawTest[randomIndex];
            ysRawTest[currentIndex] = ysRawTest[randomIndex];
            xsRawTest[randomIndex] = tempValueXs;
            ysRawTest[randomIndex] = tempValueYs;
        }
    }
}

// Count number of samples per class (0 and 1) in labels array
function countData(inputYs) {
    if (!inputYs || !inputYs.length) {
        return { class0: 0, class1: 0 };
    }

    let counter = {
        class0: 0,
        class1: 0
    };

    inputYs.forEach(result => {
        if(result[0] === 0) {
            counter.class0++;
        } else {
            counter.class1++;
        }
    });

    return counter;
}

// Balance dataset so both classes have equal number of samples
function makeEqualData(inputXs, inputYs) {
    if(!inputXs || !inputXs.length || !inputYs || !inputYs.length) {
        return null;
    }

    if(makeNumberOfFormationsEqual) {
        let newData = {
            newXs: [],
            newYs: []
        };
        
        const labelsCounter = countData(inputYs);
        let newLabelsCounter = {
            class0: 0,
            class1: 0
        };
        
        const minimum = Math.min(labelsCounter.class0, labelsCounter.class1);
        
        for(let x = inputYs.length-1; x >= 0; x--) {
            if(inputYs[x][0] === 0 && newLabelsCounter.class0 < minimum) {
                newData.newXs.push(inputXs[x]);
                newData.newYs.push(inputYs[x]);
                newLabelsCounter.class0++;
            }
            else if(inputYs[x][0] === 1 && newLabelsCounter.class1 < minimum) {
                newData.newXs.push(inputXs[x]);
                newData.newYs.push(inputYs[x]);
                newLabelsCounter.class1++;
            }
        }
        
        return newData;
    }
    
    return null;
}

// Main function to generate data: normalize, balance, prepare RNN format, shuffle, and save
function generateData() {
    return new Promise((resolve, reject) => {
        // Check if data exists
        if (!xsRaw.length || !ysRaw.length) {
            resolve("No data to process. Check data format from MT4.");
            return;
        }
        
        if(generateTestData) {
            const XsSplitIndex = Math.floor(xsRaw.length * testDataPercentage);
            const YsSplitIndex = Math.floor(ysRaw.length * testDataPercentage);
            
            if (XsSplitIndex > 0 && YsSplitIndex > 0) {
                xsRawTest = xsRaw.splice(xsRaw.length - XsSplitIndex);
                ysRawTest = ysRaw.splice(ysRaw.length - YsSplitIndex);
                
                const equalData = makeEqualData(xsRawTest, ysRawTest);
                if(equalData && equalData.newXs && equalData.newXs.length) {
                    xsRawTest = equalData.newXs;
                    ysRawTest = equalData.newYs;
                }
            }
        }

        const equalData = makeEqualData(xsRaw, ysRaw);
        if(equalData && equalData.newXs && equalData.newXs.length) {
            xsRaw = equalData.newXs;
            ysRaw = equalData.newYs;
        }
        
        // Normalize data for neural network if enabled
        if(normalizeForNN) {
            // Normalize training data
            for(let x=0; x < xsRaw.length; x++) {
                const sample = xsRaw[x];
                const valuesPerCandle = 2; // Close and Volume
                
                const closeValues = [];
                const volumeValues = [];
                
                for(let i = 0; i < sample.length; i += valuesPerCandle) {
                    closeValues.push(sample[i]);
                    volumeValues.push(sample[i + 1]);
                }
                
                const maxClose = Math.max(...closeValues);
                const maxVolume = Math.max(...volumeValues);
                
                for(let i = 0; i < sample.length; i += valuesPerCandle) {
                    if(maxClose > 0) sample[i] = sample[i] / maxClose;
                    if(maxVolume > 0) sample[i + 1] = sample[i + 1] / maxVolume;
                }
            }
            
            // Normalize test data if applicable
            if(generateTestData && xsRawTest.length) {
                for(let x=0; x < xsRawTest.length; x++) {
                    const sample = xsRawTest[x];
                    const valuesPerCandle = 2;
                    
                    const closeValues = [];
                    const volumeValues = [];
                    
                    for(let i = 0; i < sample.length; i += valuesPerCandle) {
                        closeValues.push(sample[i]);
                        volumeValues.push(sample[i + 1]);
                    }
                    
                    const maxClose = Math.max(...closeValues);
                    const maxVolume = Math.max(...volumeValues);
                    
                    for(let i = 0; i < sample.length; i += valuesPerCandle) {
                        if(maxClose > 0) sample[i] = sample[i] / maxClose;
                        if(maxVolume > 0) sample[i + 1] = sample[i + 1] / maxVolume;
                    }
                }
            }
        }

        // Optional: reshape data for RNN format
        if(generateRNNData && xsRaw.length) {
            let xsRawRNN = [];
            for(let x=0; x < xsRaw.length; x++) {
                let candle = [];
                for(let y=0; y < xsRaw[x].length; y+=maxValues.valuesPerCandle) {
                    candle.push(xsRaw[x].slice(y, y+maxValues.valuesPerCandle));
                }
                xsRawRNN.push(candle);
            }
            xsRaw = xsRawRNN;

            if(generateTestData && xsRawTest.length) {
                let xsRawTestRNN = [];
                for(let x=0; x < xsRawTest.length; x++) {
                    let candle = [];
                    for(let y=0; y < xsRawTest[x].length; y+=maxValues.valuesPerCandle) {
                        candle.push(xsRawTest[x].slice(y, y+maxValues.valuesPerCandle));
                    }
                    xsRawTestRNN.push(candle);
                }
                xsRawTest = xsRawTestRNN;
            }
        }

        // Shuffle data if enabled
        if(shuffleData) shuffle();
        
        // Capture max input length and metadata
        if (xsRaw && xsRaw.length && xsRaw[0]) {
            maxInputLength = xsRaw[0].length;
            maxValues = {...maxValues, maxInputLength, symbol, timeframe};
        } else {
            console.log("Warning: xsRaw is empty or invalid format, unable to determine maxInputLength");
        }

        // Save data to JSON files
        saveJSON();

        // Count and resolve with summary message
        if(generateTestData) {
            trainDataCounter = countData(ysRaw);
            testDataCounter = countData(ysRawTest);
            resolve(`Done generating learning data with Class 0: ${trainDataCounter.class0}, Class 1: ${trainDataCounter.class1}, test data with Class 0: ${testDataCounter.class0}, Class 1: ${testDataCounter.class1} at ${new Date().toLocaleString()}`);
        }
        else {
            trainDataCounter = countData(ysRaw);
            resolve(`Done generating learning data with Class 0: ${trainDataCounter.class0}, Class 1: ${trainDataCounter.class1} at ${new Date().toLocaleString()}`);
        }
    });
}

// Save training and test data as JSON files instead of JS files
function saveJSON() {
    try {
        // Save xsRaw.json
        const xsFile = `${outputPath}/xsRaw.json`;
        fs.writeFileSync(xsFile, JSON.stringify(xsRaw, null, 2));
        console.log(`Created ${xsFile} with ${xsRaw.length} samples`);

        // Save ysRaw.json
        const ysFile = `${outputPath}/ysRaw.json`;
        fs.writeFileSync(ysFile, JSON.stringify(ysRaw, null, 2));
        console.log(`Created ${ysFile} with ${ysRaw.length} samples`);

        // Save max values for denormalization if enabled
        if(saveMaxValueVolumeForDenormalization && symbol && timeframe) {
            const filename = `${outputPath}/${filePrefix}-${dateFrom || "unknown"}-${dateTo || "unknown"}-${symbol}-${timeframe}_maxValueVolume.json`;
            fs.writeFileSync(filename, JSON.stringify(maxValues, null, 2));
            console.log("Created max values file:", filename);
        }

        // Save test data files if applicable
        if(generateTestData && xsRawTest.length) {
            const xsTestFile = `${outputPath}/xsRawTest.json`;
            fs.writeFileSync(xsTestFile, JSON.stringify(xsRawTest, null, 2));
            const ysTestFile = `${outputPath}/ysRawTest.json`;
            fs.writeFileSync(ysTestFile, JSON.stringify(ysRawTest, null, 2));
            console.log(`Created test data files with ${xsRawTest.length} samples`);
        }
    } catch (error) {
        console.error("Error saving JSON files:", error);
    }
}

// Middleware to parse URL-encoded bodies with large size limit
app.use(bodyParser.urlencoded({extended:true, limit: "500mb"}));

// Main POST route to receive data from MT4 or other clients
app.route("/")
    .post((req, res) => {
        try {
            const inputData = Object.keys(req.body).toString();
            
            // Log first 100 characters of raw data for debugging
            console.log("Raw data received:", inputData.substring(0, 100) + (inputData.length > 100 ? "..." : ""));
            
            // Handle "End" signal to stop data collection and generate dataset
            if(inputData.indexOf("End") !== -1 && inputData.indexOf(symbol) !== -1 && inputData.indexOf(timeframe) !== -1) {
                candleStream = false;
                console.log("Generating learning data at " + new Date().toLocaleString());
                console.log(`Data collected: xsRaw: ${xsRaw.length}, ysRaw: ${ysRaw.length}`);
                
                generateData().then(msg => {
                    console.log(msg);
                    // Reset all data and metadata after generation
                    xsRaw = [];
                    ysRaw = [];
                    xsRawTest = [];
                    ysRawTest = [];
                    maxValues = {};
                    maxInputLength = 0;
                    symbol = undefined;
                    timeframe = undefined;
                    dateFrom = undefined;
                    dateTo = undefined;
                });
                
                res.send("Done");
                return;
            }
            
            // Handle MaxValues signal to receive max values for normalization
            if(inputData.indexOf("MaxValues") !== -1) {
                let values = inputData.split("-");
                values.pop(); // Remove MaxValues tag
                const valuesPerCandle = parseInt(values[values.length-1]);
                values.pop(); // Remove valuesPerCandle
                
                // Convert values to appropriate types (float for Close, int for Volume)
                values = values.map((value, index) => index === 0 ? parseFloat(value) : parseInt(value));
                
                maxValues = {
                    maxValues: values,
                    valuesPerCandle
                };
                
                console.log("Received max values:", maxValues);
                res.sendStatus(200);
                return;
            }
            
            // Handle Start signal to begin data collection
            if(inputData.indexOf("Start") !== -1) {
                const pairtfdate = inputData.split("-");
                symbol = pairtfdate[0];
                timeframe = pairtfdate[1];
                if (pairtfdate.length > 2) dateFrom = pairtfdate[2];
                if (pairtfdate.length > 3) dateTo = pairtfdate[3];
                candleStream = true;
                console.log(`Starting data collection for ${symbol}, timeframe ${timeframe}`);
                res.sendStatus(200);
                return;
            }
            
            // Handle formation data during active data collection
            if(candleStream && inputData.indexOf("End") === -1 && inputData.indexOf("Start") === -1 && inputData.indexOf("MaxValues") === -1) {
                try {
                    // Split input into class and chart data parts
                    const parts = inputData.split(";");
                    console.log("Parts after splitting:", parts.length);
                    
                    if (parts.length >= 2) {
                        const classStr = parts[0].trim();
                        const classValue = parseInt(classStr);
                        console.log("Class value:", classValue);
                        
                        let chartData = parts[1].split("-");
                        chartData = chartData.filter(item => item.trim() !== "");
                        console.log("Chart data count:", chartData.length);
                        
                        if (!isNaN(classValue) && chartData.length > 0) {
                            // Convert chart data strings to numbers
                            const numericData = chartData.map(val => {
                                const num = parseFloat(val);
                                return isNaN(num) ? 0 : num;
                            });
                            
                            // Append to datasets
                            ysRaw.push([classValue]);
                            xsRaw.push(numericData);
                            
                            console.log(`Successfully processed class ${classValue} sample with ${numericData.length} features`);
                        } else {
                            console.log("Invalid data format - class or chart data invalid:", classStr, chartData.length);
                        }
                    } else {
                        console.log("Invalid data format - missing semicolon separator:", inputData);
                    }
                } catch (error) {
                    console.error("Error processing data:", error);
                }
                
                res.sendStatus(200);
                return;
            }
            
            res.sendStatus(200);
        } catch (error) {
            console.error("Error processing request:", error);
            res.sendStatus(500);
        }
    });
