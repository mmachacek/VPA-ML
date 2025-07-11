//+------------------------------------------------------------------+
//|                             #nodeJS_SendHistory_Close_Volume.mq4 |
//|                                  Copyright 2025, Michal Macháček |
//|                                     https://github.com/mmachacek |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Michal Macháček"
#property link      "https://github.com/mmachacek"
#property version   "1.00"
#property strict
#include <mq4-http.mqh>

input int barsInHistory = 5; // Number of bars to analyze after each highlighted sample (as a vertical line).
input string serverIP = "localhost"; // IP address of the server to send data.
input int serverPort = 8078; // Port number of the server.

// Instance of MqlNet class for network communication.
MqlNet INet;

// 2D array to store datetime and index of vertical line objects found on chart.
datetime objectArray[][2];

double digits = MarketInfo(NULL, MODE_DIGITS);

// String to hold max values for normalization (Close and Volume).
string maxValues;

//+------------------------------------------------------------------+
//| Check if automated trading and DLL imports are allowed          |
//+------------------------------------------------------------------+
void checkPermissions() {
  if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    Alert("Automated trading is not allowed");
  if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED))
    Alert("DLL import is not allowed");
  return;
}

//+------------------------------------------------------------------+
//| Send data string to the server via HTTP POST                     |
//+------------------------------------------------------------------+
int sendDataToServer(string dataToServer) {
  if(!INet.Open(serverIP, serverPort)) {
    Print("Failed to connect to server: ", serverIP, ":", serverPort);
    return(0);
  }
  
  string response;
  
  if(!INet.Request("POST", "/", response, false, true, dataToServer, false)) {
    Print("-Err download ");
    return(0);
  }
  else {
    if(StringFind(response, "Done") != -1) {
      Print("Server received data");
    }
  }
  
  return(1);
}

//+------------------------------------------------------------------+
//| Extract class from vertical line NAME (not description)          |
//| Returns 0 for FailedPinBar, 1 for SuccessfulPinBar, -1 otherwise |
//+------------------------------------------------------------------+
int getClassFromName(string objectName) {
  if(StringFind(objectName, "FailedPinBar") != -1) {
    Print("Found Failed Pin Bar pattern in name: ", objectName);
    return 0;
  } 
  else if(StringFind(objectName, "SuccessfulPinBar") != -1) {
    Print("Found Successful Pin Bar pattern in name: ", objectName);
    return 1;
  }
  // Default return value if no match
  Print("No valid pattern found in name: ", objectName);
  return -1;
}

//+------------------------------------------------------------------+
//| Analyze formations around vertical lines and send data to server |
//+------------------------------------------------------------------+
void findFormations() {
  int maxValuesShiftFrom = iBarShift(Symbol(), Period(), objectArray[0][0]);
  int maxValuesShiftTo = iBarShift(Symbol(), Period(), objectArray[ArrayRange(objectArray,0)-1][0]);

  // Calculate maximum Close and Volume values between the two vertical lines.
  double maxClose = findMaxClose(maxValuesShiftFrom, maxValuesShiftTo);
  int maxVolume = findMaxVolume(maxValuesShiftFrom, maxValuesShiftTo);
  
  // Format max values string: maxClose-maxVolume-2-MaxValues
  // "2" indicates two values per candle (Close and Volume).
  maxValues = DoubleToString(maxClose, digits) + "-" + IntegerToString(maxVolume) + "-2-MaxValues";

  // Loop through all vertical lines except the last.
  for(int i=0; i < ArrayRange(objectArray,0)-1; i++) {
    string objectName = ObjectName(objectArray[i][1]);
    Print("Processing line with name: ", objectName);
    
    int classValue = getClassFromName(objectName);
    
    // Skip lines with invalid class.
    if(classValue == -1) {
      Print("Skipping line with invalid class: ", objectName);
      continue;
    }
    
    Print("Processing object with class value: ", classValue);
    string outputData = StringConcatenate(IntegerToString(classValue), ";"); // Class value: 0 or 1
    string formation = "";
    
    datetime timeOfVerticalLine = objectArray[i][0];
    int shiftOfVerticalLine = iBarShift(Symbol(), Period(), timeOfVerticalLine);
    int endShift = shiftOfVerticalLine + barsInHistory;
    
    // Ensure not to exceed available bars.
    if(endShift > Bars) endShift = Bars;
    
    // Collect Close and Volume data for specified bars.
    for(int shift = shiftOfVerticalLine; shift < endShift; shift++) {
      formation = StringConcatenate(formation, 
                    DoubleToString(Close[shift], digits), "-",
                    IntegerToString(Volume[shift]), "-");
    }
    
    // Remove trailing dash if present.
    if(StringSubstr(formation, StringLen(formation)-1, 1) == "-") {
      formation = StringSubstr(formation, 0, StringLen(formation)-1);
    }
    
    outputData = StringConcatenate(outputData, formation);
    Print("Sending data: ", StringSubstr(outputData, 0, 50), "...");
    sendDataToServer(outputData);
  }
  
  // Send max values for normalization.
  sendDataToServer(maxValues);
}

//+------------------------------------------------------------------+
//| Find maximum Volume between two shifts                           |
//+------------------------------------------------------------------+
int findMaxVolume(int fromShift, int toShift) {
  int maxVolume = Volume[fromShift];
  
  while(fromShift < toShift) {
    if(maxVolume < Volume[fromShift]) {
      maxVolume = Volume[fromShift];
    }
    fromShift++;
  }
    
  return maxVolume;
}

//+------------------------------------------------------------------+
//| Find maximum Close price between two shifts                      |
//+------------------------------------------------------------------+
double findMaxClose(int fromShift, int toShift) {
  double maxClose = Close[fromShift];
  
  while(fromShift < toShift) {
    if(maxClose < Close[fromShift]) {
      maxClose = Close[fromShift];
    }
    fromShift++;
  }
  
  return maxClose;
}

//+------------------------------------------------------------------+
//| Return number of values per candle (Close and Volume)            |
//+------------------------------------------------------------------+
string getValuesPerCandle() {
  return "2"; // 2 values per candle: Close and Volume
}

//+------------------------------------------------------------------+
//| Return formatted time range string based on vertical lines       |
//+------------------------------------------------------------------+
string getTimeRange() {
  string timeRange;
  datetime datetimeFrom = objectArray[ArrayRange(objectArray,0)-1][0];
  datetime datetimeTo = objectArray[0][0];
  int dayFrom = TimeDay(datetimeFrom);
  int dayTo = TimeDay(datetimeTo);
  int monthFrom = TimeMonth(datetimeFrom);
  int monthTo = TimeMonth(datetimeTo);
  int yearFrom = TimeYear(datetimeFrom);
  int yearTo = TimeYear(datetimeTo);
  
  timeRange = StringConcatenate(
    IntegerToString(dayFrom), "_", IntegerToString(monthFrom), "_", IntegerToString(yearFrom), "-",
    IntegerToString(dayTo), "_", IntegerToString(monthTo), "_", IntegerToString(yearTo)
  );
  
  return timeRange;
}

//+------------------------------------------------------------------+
//| Populate objectArray with vertical line datetimes and indexes    |
//+------------------------------------------------------------------+
void createObjectArray() {
  int total = ObjectsTotal();
  Print("Total objects on chart: ", total);
  
  int counter = 0;
  if(total > 1) {
    ArrayResize(objectArray, total);
    for(int i = 0; i < total; i++) {
      string objName = ObjectName(i);
      Print("Found object: ", objName, " Type: ", ObjectType(objName));
      
      if(ObjectType(objName) == 0) { // Vertical line object type is 0
        objectArray[counter][0] = ObjectGetInteger(0, objName, OBJPROP_TIME1);
        objectArray[counter][1] = i;
        Print("Added vertical line: ", objName, " Description: ", ObjectDescription(objName));
        counter++;
      }
    }
    Print("Found ", counter, " vertical lines");
    ArraySort(objectArray, WHOLE_ARRAY, 0, MODE_DESCEND);
    ArrayResize(objectArray, counter);
  }
  
  return;
}

//+------------------------------------------------------------------+
//| Script entry point                                               |
//+------------------------------------------------------------------+
void OnStart() {
  checkPermissions();
  createObjectArray();
  
  if(ArrayRange(objectArray, 0)) { 
    // Notify server of start of data sending.
    sendDataToServer(StringConcatenate(Symbol(), "-", IntegerToString(Period()), "-", getTimeRange(), "-", "Start"));
    
    findFormations();
    
    // Notify server of end of data sending.
    sendDataToServer(StringConcatenate(Symbol(), "-", IntegerToString(Period()), "-", "End"));
  }
  else {
    Alert("Entry vertical lines were not found on the chart");
  }
  return;
}