//+------------------------------------------------------------------+
//|                                           #NN_VPA_Evaluation.mq4 |
//|                                  Copyright 2025, Michal Macháček |
//|                                     https://github.com/mmachacek |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Michal Macháček"
#property link      "https://github.com/mmachacek"
#property version   "1.00"
#property strict

#include <mq4-http.mqh>

// Input parameters
input int barsInHistory = 100;       // Number of historical bars to analyze when a vertical line is detected.
input string serverIP = "localhost"; // IP address of the external server to which data is sent and from which predictions are received.
input int serverPort = 8078;         // Port number of the external server.
input bool enableTrading = false;    // Enables or disables automated trading based on server predictions.
input double lotSize = 0.1;          // The fixed lot size to use for placing trades if enableTrading is true.
input int slippage = 3;              // Maximum allowed slippage in points for trade execution.

// Global variables
MqlNet INet;                      // Instance of the MqlNet class for network communication.
datetime lastCheckedTime = 0;     // Stores the time of the last processed bar to avoid duplicate processing on the same tick.
bool sessionStarted = false;      // Flag to ensure server session start/end messages are sent only once.

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check for necessary terminal permissions (DLL import, automated trading).
   checkPermissions();
   
   // Start session with the server if it hasn't been started yet.
   if(!sessionStarted)
   {
      // Send a "Start" message to the server, including symbol and timeframe.
      string startMessage = StringConcatenate(Symbol(), "-", IntegerToString(Period()), "-", "Start");
      sendDataToServer(startMessage);
      sessionStarted = true; // Set flag to true to prevent re-sending start message.
      
      // Calculate and send the maximum volume value from the historical bars for normalization.
      long maxVolume = findMaxVolume(0, barsInHistory);
      // Format: maxVolume-1-MaxValues (1 indicates 1 type of max value sent: Volume).
      string maxValueMessage = StringConcatenate(IntegerToString(maxVolume), "-", "1", "-", "MaxValues");
      sendDataToServer(maxValueMessage);
      
      Print("Session started with server, max volume: ", maxVolume);
   }
   
   return(INIT_SUCCEEDED); // Indicate successful initialization.
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // End session with the server if it was started.
   if(sessionStarted)
   {
      // Send an "End" message to the server, including symbol and timeframe.
      string endMessage = StringConcatenate(Symbol(), "-", IntegerToString(Period()), "-", "End");
      sendDataToServer(endMessage);
      sessionStarted = false; // Reset flag.
      Print("Session ended with server");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//| Called on every new tick.                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process once per new bar to avoid redundant calculations.
   datetime currentTime = Time[0]; // Get the open time of the current (0-indexed) bar.
   if(currentTime == lastCheckedTime) return; // If it's the same bar as last check, do nothing.
   
   // Check for a vertical line on the current bar.
   checkCurrentBarForVerticalLine();
   
   // Update the time of the last checked bar.
   lastCheckedTime = currentTime;
}

//+------------------------------------------------------------------+
//| Check if current bar has a vertical line                         |
//| Iterates through all chart objects to find vertical lines at the |
//| current bar's time and processes them if they are PinBar related.|
//+------------------------------------------------------------------+
void checkCurrentBarForVerticalLine()
{
   datetime currentBarTime = Time[0]; // Get the time of the current bar.
   int totalObjects = ObjectsTotal(); // Get total number of objects on the chart.
   
   for(int i = 0; i < totalObjects; i++)
   {
      string objName = ObjectName(i); // Get the name of the object.
      
      // Check if the object is a vertical line.
      if(ObjectType(objName) == OBJ_VLINE)
      {
         // Get the time of the vertical line.
         datetime lineTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         
         // If the vertical line's time matches the current bar's time.
         if(lineTime == currentBarTime)
         {
            Print("Found vertical line at current bar: ", objName);
            
            // Only process lines that are named with "PinBar" (e.g., "SuccessfulPinBar", "FailedPinBar").
            if(StringFind(objName, "PinBar") != -1)
            {
               // Process the detected vertical line.
               processVerticalLine(lineTime, objName);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process a vertical line by collecting bar data and sending it    |
//| to the server for prediction.                                    |
//+------------------------------------------------------------------+
void processVerticalLine(datetime lineTime, string objectName)
{
   // Start the data payload with the object's full name (e.g., "SuccessfulPinBar_2024.01.05 07:50;").
   string outputData = StringConcatenate(objectName, ";");
   string formation = "";
   
   // Get the bar shift (index) of the vertical line.
   int shiftOfVerticalLine = iBarShift(Symbol(), Period(), lineTime);
   
   // Collect Volume and Close price data for 'barsInHistory' bars starting from the vertical line.
   for(int shift = shiftOfVerticalLine; shift < shiftOfVerticalLine + barsInHistory && shift < Bars; shift++)
   {
      // Format each bar's data as "Volume,Close".
      string pair = StringConcatenate(IntegerToString(Volume[shift]), ",", DoubleToString(Close[shift], _Digits));
      formation = StringConcatenate(formation, pair, "-"); // Append with a dash separator.
   }
   
   // Remove the trailing dash if any data was added.
   if(StringLen(formation) > 0)
   {
      formation = StringSubstr(formation, 0, StringLen(formation)-1);
   }
   
   // Concatenate the object name and the bar formation data.
   outputData = StringConcatenate(outputData, formation);
   Print("Sending data: ", StringSubstr(outputData, 0, 100), "..."); // Print a snippet for debugging.
   
   // Send the collected data to the server and get the response.
   string response = sendDataToServer(outputData);
   // Handle the server's prediction response.
   handleServerResponse(response);
}


//+------------------------------------------------------------------+
//| Send data to the server and return the raw response string.      |
//+------------------------------------------------------------------+
string sendDataToServer(string dataToServer)
{
   string response = ""; // Initialize empty response string.
   
   // Attempt to open a connection to the server.
   if(!INet.Open(serverIP, serverPort))
   {
      Print("Failed to connect to server: ", serverIP, ":", serverPort);
      return response; // Return empty string on connection failure.
   }
   
   // Send a POST request to the server with the data.
   if(!INet.Request("POST", "/", response, false, true, dataToServer, false))
   {
      Print("-Err download "); // Print error if request fails.
      return response; // Return empty string on request failure.
   }
   else
   {
      Print("Server response: ", response); // Print the server's successful response.
   }
   
   return response; // Return the full server response.
}

//+------------------------------------------------------------------+
//| Handle the prediction response received from the server.         |
//| Parses the response and potentially places a trade if trading is |
//| enabled and prediction meets criteria.                           |
//+------------------------------------------------------------------+
void handleServerResponse(string response)
{
   if(StringLen(response) <= 0) return; // Do nothing if response is empty.
   
   // Parse the response string, assuming format: symbol,timeframe,classification,prediction_value
   string parts[10]; // Array to hold split parts of the string.
   int count = StringSplit(response, ',', parts); // Split by comma.
   
   if(count >= 4) // Ensure all expected parts are present.
   {
      string symbol = parts[0];
      string timeframe = parts[1];
      string classification = parts[2];     // e.g., "SuccessfulPinBar" or "FailedPinBar"
      double predictionValue = StringToDouble(parts[3]); // The model's prediction score.
      
      Print("Prediction: ", classification, " with value ", predictionValue);
      
      // If automated trading is enabled and the prediction is for the current symbol.
      if(enableTrading && StringCompare(symbol, Symbol()) == 0)
      {
         // If classification is "SuccessfulPinBar" and prediction score is high (>=0.5).
         if(StringCompare(classification, "SuccessfulPinBar") == 0 && predictionValue >= 0.5)
         {
            // Place a BUY order.
            int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, slippage, 0, 0, "PinBar EA", 0, 0, Green);
            if(ticket < 0)
               Print("OrderSend error: ", GetLastError());
            else
               Print("Buy order placed, ticket: ", ticket);
         }
         // If classification is "FailedPinBar" and prediction score is low (<0.5).
         else if(StringCompare(classification, "FailedPinBar") == 0 && predictionValue < 0.5)
         {
            // Place a SELL order.
            int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, slippage, 0, 0, "PinBar EA", 0, 0, Red);
            if(ticket < 0)
               Print("OrderSend error: ", GetLastError());
            else
               Print("Sell order placed, ticket: ", ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if we have necessary permissions to run the EA.            |
//+------------------------------------------------------------------+
void checkPermissions()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      Alert("Automated trading is not allowed"); // Alert if automated trading is disabled in terminal settings.
   if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED))
      Alert("DLL import is not allowed"); // Alert if DLL imports are disabled (needed for MqlNet).
   return;
}

//+------------------------------------------------------------------+
//| Find the maximum volume in a specified range of historical bars. |
//+------------------------------------------------------------------+
long findMaxVolume(int fromShift, int toShift)
{
   long maxVolume = Volume[fromShift]; // Initialize max volume with the volume of the starting bar.
   
   // Loop through the specified range.
   for(int i = fromShift; i < toShift && i < Bars; i++)
   {
      // Update maxVolume if a higher volume is found.
      if(maxVolume < Volume[i])
      {
         maxVolume = Volume[i];
      }
   }
      
   return maxVolume; // Return the highest volume found.
}

//+------------------------------------------------------------------+
//| Extract class (0 for FailedPinBar, 1 for SuccessfulPinBar) from |
//| the vertical line's object name.                                 |
//+------------------------------------------------------------------+
int getClassFromName(string objectName)
{
   if(StringFind(objectName, "FailedPinBar") != -1)
   {
      Print("Found Failed Pin Bar pattern in name: ", objectName);
      return 0; // Return 0 for FailedPinBar.
   }
   else if(StringFind(objectName, "SuccessfulPinBar") != -1)
   {
      Print("Found Successful Pin Bar pattern in name: ", objectName);
      return 1; // Return 1 for SuccessfulPinBar.
   }
   // If neither pattern is found, print a message and return -1.
   Print("No recognized PinBar pattern found in name: ", objectName);
   return -1;
}