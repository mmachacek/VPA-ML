//+------------------------------------------------------------------+
//|                                                  #DrawLines.mq4  |
//|                                  Copyright 2025, Michal Macháček |
//|                                     https://github.com/mmachacek |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Michal Macháček"
#property link      "https://github.com/mmachacek"
#property version   "1.00"
#property strict

input int numberOfLines = 50; // The number of lines to draw above and below the central line.
input color lineColor = Red; // The color of the main support/resistance lines.
input int lineStyle = 3; // The style of the main support/resistance lines (e.g., solid, dash, dot).
input int lineWidth = 1; // The width of the main support/resistance lines.
input string linePrefix = "HL"; // The prefix used to identify main support/resistance lines for deletion and creation.
input string lineZonePrefix = "Z"; // The prefix used to identify zones around support/resistance lines for deletion and creation.
input int ATRDivider = 16; // Divisor for Average True Range (ATR) to calculate the width of the support/resistance zones.
input int ATRPeriod = 100; // The period used for calculating the ATR.


double range = 0, lineValue = 0, upperLineValue = 0, lowerLineValue = 0, ATR;
string oldLines[1];
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
   // Calculate the ATR for the current symbol and timeframe.
   ATR = iATR(Symbol(), Period(), ATRPeriod, 1);
   
   // Delete any previously drawn lines and zones from the chart.
   deleteOldLines();
   
   // Attempt to find the initial range based on existing horizontal lines.
   if(findRange()) {
   
      // If a valid range is found, proceed to draw the new lines and zones.
      drawLines();
   }
   return;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Function to draw new support/resistance lines and their zones    |
//+------------------------------------------------------------------+
void drawLines() {
   // Initialize upper and lower line values based on the central line and calculated range.
   upperLineValue = lineValue + range;
   lowerLineValue = lineValue - range;

   // Create the central horizontal line.
   if(!ObjectCreate(linePrefix + "C", OBJ_HLINE, 0, 0, lineValue)) {
      Alert("Unable to create line " + linePrefix + "C");
   }
   else {
      // Set properties for the central line.
      ObjectSet(linePrefix + "C", OBJPROP_STYLE, lineStyle);
      ObjectSet(linePrefix + "C", OBJPROP_COLOR, lineColor);
      ObjectSet(linePrefix + "C", OBJPROP_WIDTH, lineWidth);

      // Create the upper zone line for the central line.
      if(!ObjectCreate(lineZonePrefix + "C" + "H", OBJ_HLINE, 0, 0, lineValue + ATR / ATRDivider)) {
         Alert("Unable to create line " + lineZonePrefix + "C" + "H");
      }
      else
      {
         // Set properties for the upper central zone line.
         ObjectSet(lineZonePrefix + "C" + "H", OBJPROP_STYLE, STYLE_DOT);
         ObjectSet(lineZonePrefix + "C" + "H", OBJPROP_COLOR, lineColor);
         ObjectSet(lineZonePrefix + "C" + "H", OBJPROP_WIDTH, lineWidth);
      }
      // Create the lower zone line for the central line.
      if(!ObjectCreate(lineZonePrefix + "C" + "L", OBJ_HLINE, 0, 0, lineValue - ATR / ATRDivider)) {
         Alert("Unable to create line " + lineZonePrefix + "C" + "L");
      }
      else
      {
         // Set properties for the lower central zone line.
         ObjectSet(lineZonePrefix + "C" + "L", OBJPROP_STYLE, STYLE_DOT);
         ObjectSet(lineZonePrefix + "C" + "L", OBJPROP_COLOR, lineColor);
         ObjectSet(lineZonePrefix + "C" + "L", OBJPROP_WIDTH, lineWidth);
      }

   }

   // Loop to draw lines and zones above the central line.
   for(int x = 0; x <= numberOfLines; x++) {
      // Create an upper horizontal line.
      if(!ObjectCreate(linePrefix + "H" + (string)x, OBJ_HLINE, 0, 0, upperLineValue)) {
         Alert("Unable to create line " + linePrefix + "H" + (string)x);
      }
      else {
         // Set properties for the upper line.
         ObjectSet(linePrefix + "H" + (string)x, OBJPROP_STYLE, lineStyle);
         ObjectSet(linePrefix + "H" + (string)x, OBJPROP_COLOR, lineColor);
         ObjectSet(linePrefix + "H" + (string)x, OBJPROP_WIDTH, lineWidth);

         // Create the upper zone line for the current upper line.
         if(!ObjectCreate(lineZonePrefix + "HH" + (string)x, OBJ_HLINE, 0, 0, upperLineValue + ATR / ATRDivider)) {
            Alert("Unable to create line " + lineZonePrefix + "HH" + (string)x);
         }
         else
         {
            // Set properties for the upper zone line.
            ObjectSet(lineZonePrefix + "HH" + (string)x, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(lineZonePrefix + "HH" + (string)x, OBJPROP_COLOR, lineColor);
            ObjectSet(lineZonePrefix + "HH" + (string)x, OBJPROP_WIDTH, lineWidth);
         }
         // Create the lower zone line for the current upper line.
         if(!ObjectCreate(lineZonePrefix + "LH" + (string)x, OBJ_HLINE, 0, 0, upperLineValue - ATR / ATRDivider)) {
            Alert("Unable to create line " + lineZonePrefix + "LH" + (string)x);
         }
         else
         {
            // Set properties for the lower zone line.
            ObjectSet(lineZonePrefix + "LH" + (string)x, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(lineZonePrefix + "LH" + (string)x, OBJPROP_COLOR, lineColor);
            ObjectSet(lineZonePrefix + "LH" + (string)x, OBJPROP_WIDTH, lineWidth);
         }

         // Increment the upper line value by the range for the next iteration.
         upperLineValue += range;
      }
   }

   // Loop to draw lines and zones below the central line.
   for(int y = 0; y <= numberOfLines; y++) {
      // Create a lower horizontal line.
      if(!ObjectCreate(linePrefix + "L" + (string)y, OBJ_HLINE, 0, 0, lowerLineValue)) {
         Alert("Unable to create line " + linePrefix + "L" + (string)y);
      }
      else {
         // Set properties for the lower line.
         ObjectSet(linePrefix + "L" + (string)y, OBJPROP_STYLE, lineStyle);
         ObjectSet(linePrefix + "L" + (string)y, OBJPROP_COLOR, lineColor);
         ObjectSet(linePrefix + "L" + (string)y, OBJPROP_WIDTH, lineWidth);

         // Create the upper zone line for the current lower line.
         if(!ObjectCreate(lineZonePrefix + "HL" + (string)y, OBJ_HLINE, 0, 0, lowerLineValue + ATR / ATRDivider)) {
            Alert("Unable to create line " + lineZonePrefix + "HL" + (string)y);
         }
         else
         {
            // Set properties for the upper zone line.
            ObjectSet(lineZonePrefix + "HL" + (string)y, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(lineZonePrefix + "HL" + (string)y, OBJPROP_COLOR, lineColor);
            ObjectSet(lineZonePrefix + "HL" + (string)y, OBJPROP_WIDTH, lineWidth);
         }
         // Create the lower zone line for the current lower line.
         if(!ObjectCreate(lineZonePrefix + "LL" + (string)y, OBJ_HLINE, 0, 0, lowerLineValue - ATR / ATRDivider)) {
            Alert("Unable to create line " + lineZonePrefix + "LL" + (string)y);
         }
         else
         {
            // Set properties for the lower zone line.
            ObjectSet(lineZonePrefix + "LL" + (string)y, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(lineZonePrefix + "LL" + (string)y, OBJPROP_COLOR, lineColor);
            ObjectSet(lineZonePrefix + "LL" + (string)y, OBJPROP_WIDTH, lineWidth);
         }

         // Decrement the lower line value by the range for the next iteration.
         lowerLineValue -= range;
      }
   }

   return;
}

//+------------------------------------------------------------------+
//| Function to delete previously drawn lines and zones              |
//+------------------------------------------------------------------+
void deleteOldLines() {
   // Iterate through all objects on the chart.
   for(int y = 0; y < ObjectsTotal(); y++) {
      // Check if the object is a horizontal line and its name starts with either linePrefix or lineZonePrefix.
      if(ObjectType(ObjectName(y)) == OBJ_HLINE && (StringFind(ObjectName(y), linePrefix) >= 0 || StringFind(ObjectName(y), lineZonePrefix) >= 0)) {
         // Add the name of the old line to the oldLines array for deletion.
         arrayPush(ObjectName(y), oldLines);
      }
   }
   // Iterate through the collected old line names (starting from index 1 as arrayPush adds to index 0 first).
   for(int x = 1; x < ArraySize(oldLines); x++) {
      // Attempt to delete the object.
      if(!ObjectDelete(oldLines[x])) {
         Alert("Unable to delete line " + oldLines[x]);
      }
   }
   return;
}

//+------------------------------------------------------------------+
//| Function to find the range between two initial horizontal lines  |
//+------------------------------------------------------------------+
bool findRange() {
   double firstValue = 0, secondValue = 0; // Variables to store price values of the two found lines.
   string firstLineName = "", secondLineName = ""; // Variables to store names of the two found lines.

   // Iterate through all objects on the chart to find two manually drawn horizontal lines.
   for(int x = 0; x < ObjectsTotal(); x++) {
      // Check if the object is a horizontal line and contains "Horizontal Line" in its name (default name for manually drawn lines).
      if(ObjectType(ObjectName(x)) == OBJ_HLINE && StringFind(ObjectName(x), "Horizontal Line") >= 0) {
         // If the first line is found and the second is not, store the current line as the second.
         if(firstValue != 0 && secondValue == 0) {
            secondValue = ObjectGetDouble(0, ObjectName(x), OBJPROP_PRICE); // Corrected: use ObjectGetDouble for price
            secondLineName = ObjectName(x);
            break; // Found both lines, exit loop.
         }

         // If neither line has been found yet, store the current line as the first.
         if(firstValue == 0 && secondValue == 0) {
            firstValue = ObjectGetDouble(0, ObjectName(x), OBJPROP_PRICE); // Corrected: use ObjectGetDouble for price
            firstLineName = ObjectName(x);
         }
      }
   }

   // Check if two horizontal lines were successfully found.
   if(firstValue != 0 && secondValue != 0) {
      // Determine which line has a higher value to establish the central line and range.
      if(firstValue > secondValue) {
         lineValue = firstValue; // Set the higher value as the central line.
         range = firstValue - secondValue; // Calculate the range.
         // Delete the two found manual lines after their values are used.
         if(!ObjectDelete(firstLineName)) {
            Alert("Unable to delete the first horizontal line");
         }
         if(!ObjectDelete(secondLineName)) {
            Alert("Unable to delete the second horizontal line");
         }
         return true; // Indicates successful range finding.
      }
      else if(secondValue > firstValue) {
         lineValue = secondValue; // Set the higher value as the central line.
         range = secondValue - firstValue; // Calculate the range.
         // Delete the two found manual lines after their values are used.
         if(!ObjectDelete(firstLineName)) {
            Alert("Unable to delete the first horizontal line");
         }
         if(!ObjectDelete(secondLineName)) {
            Alert("Unable to delete the second horizontal line");
         }
         return true; // Indicates successful range finding.
      }
      else {
         Alert("Horizontal lines have the same value, cannot determine range.");
         return false; // Lines are at the same price, invalid range.
      }
   }
   else {
      Alert("No two horizontal lines found for range calculation. Please draw two manual horizontal lines on the chart.");
      return false; // Not enough lines found.
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper function to push a string value into a dynamic array      |
//+------------------------------------------------------------------+
void arrayPush(string value, string & array[]) {
   // Resize the array to accommodate one more element.
   int count = ArrayResize(array, ArraySize(array) + 1);
   // Check if the array now has more than one element (meaning it's not the initial empty array).
   if(ArraySize(array) > 1) {
      // Assign the new value to the last element of the resized array.
      array[ArraySize(array) - 1] = value;
   }
   else {
      array[ArraySize(array) - 1] = value; // This line should ideally be consistent
   }
   return;
}