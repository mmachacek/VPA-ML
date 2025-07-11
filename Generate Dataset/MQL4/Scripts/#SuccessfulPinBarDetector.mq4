//+------------------------------------------------------------------+
//|                                    #SuccessfulPinBarDetector.mq4 |
//|                                  Copyright 2025, Michal Macháček |
//|                                     https://github.com/mmachacek |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Michal Macháček"
#property link      "https://github.com/mmachacek"
#property version   "1.00"
#property strict

extern int    VolumeSMA_Period = 21;         // Period for calculating the Simple Moving Average of Volume
extern double WickBodyRatio    = 2.0;        // Minimum ratio of wick length to body size for a pin bar
extern int    LookbackBars     = 5;          // Number of previous bars to check for "sticking out"
extern int    ConfirmBars      = 3;          // Number of bars ahead to check for confirmation
extern color  LineColor        = RoyalBlue;  // Color of vertical lines drawn for successful pin bars
extern int    LineWidth        = 5;          // Width of the vertical line (maximum)
extern string StartDate        = "1999.01.01"; // Start date for analysis (YYYY.MM.DD)
extern string EndDate          = "2024.01.01"; // End date for analysis (YYYY.MM.DD)
extern bool   ShowAlert        = true;       // Show alert with the count of detected pin bars

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Delete old successful pin bar lines and clear any chart comment
   ObjectsDeleteAll(0, "SuccessfulPinBar_");
   ChartSetString(0, CHART_COMMENT, "");

   int pinBarCount = 0; // Counter for detected pin bars

   // Convert input string dates to datetime
   datetime startDateTime = StringToTime(StartDate);
   datetime endDateTime = StringToTime(EndDate);

   // Check if there are enough bars to perform the analysis
   if(Bars < VolumeSMA_Period + LookbackBars + ConfirmBars)
   {
      Alert("Not enough bars for calculation");
      return;
   }

   // Scan all bars except the most recent ones needed for confirmation
   for(int i = Bars - VolumeSMA_Period - 1; i >= ConfirmBars; i--)
   {
      // Only analyze bars within the specified date range
      if(Time[i] < startDateTime || Time[i] > endDateTime)
         continue;

      // Calculate the SMA of volume for the current bar
      long sumVolume = 0;
      for(int j = 0; j < VolumeSMA_Period; j++)
      {
         sumVolume += Volume[i+j];
      }
      long volumeSMA = sumVolume / VolumeSMA_Period;

      // Only consider bars with above-average volume
      if(Volume[i] <= volumeSMA) continue;

      // Calculate body and wick sizes
      double bodySize = MathAbs(Close[i] - Open[i]);
      double upperWick = High[i] - MathMax(Open[i], Close[i]);
      double lowerWick = MathMin(Open[i], Close[i]) - Low[i];

      // Skip bars without a significant wick
      if(MathMax(upperWick, lowerWick) <= bodySize * WickBodyRatio) continue;

      // Determine pin bar type
      bool isBullishPin = (lowerWick > WickBodyRatio * bodySize) && (lowerWick > upperWick);
      bool isBearishPin = (upperWick > WickBodyRatio * bodySize) && (upperWick > lowerWick);

      if(!isBullishPin && !isBearishPin) continue;

      // Check if the pin bar "sticks out" from previous bars
      bool isStickingOut = false;
      double prevHigh = 0;
      double prevLow = 1000000;

      for(int j = i + 1; j <= i + LookbackBars; j++)
      {
         if(j >= Bars) continue;
         prevHigh = MathMax(prevHigh, High[j]);
         prevLow = MathMin(prevLow, Low[j]);
      }

      if((isBullishPin && Low[i] < prevLow) || (isBearishPin && High[i] > prevHigh))
      {
         isStickingOut = true;
      }

      if(!isStickingOut) continue;

      // Check if price action after the pin bar confirms the signal
      bool signalConfirmed = false;

      if(isBullishPin)
      {
         // For bullish pin, check if price moves up after the bar
         for(int j = 1; j <= ConfirmBars; j++)
         {
            if(i-j < 0) break;
            if(Close[i-j] > High[i])
            {
               signalConfirmed = true;
               break;
            }
         }
      }
      else if(isBearishPin)
      {
         // For bearish pin, check if price moves down after the bar
         for(int j = 1; j <= ConfirmBars; j++)
         {
            if(i-j < 0) break;
            if(Close[i-j] < Low[i])
            {
               signalConfirmed = true;
               break;
            }
         }
      }

      // Only draw lines for successful (confirmed) pin bars
      if(signalConfirmed)
      {
         string lineName = "SuccessfulPinBar_" + TimeToStr(Time[i]);
         ObjectCreate(lineName, OBJ_VLINE, 0, Time[i], 0);
         ObjectSet(lineName, OBJPROP_COLOR, LineColor);
         ObjectSet(lineName, OBJPROP_WIDTH, LineWidth);
         ObjectSet(lineName, OBJPROP_BACK, true); // Draw in background

         pinBarCount++; // Increment detected pin bar count
      }
   }

   // Optionally show an alert with the total count of successful pin bars
   if(ShowAlert)
   {
      Alert("Successful Pin Bar Detector: " + IntegerToString(pinBarCount) + " pin bars identified");
   }
}