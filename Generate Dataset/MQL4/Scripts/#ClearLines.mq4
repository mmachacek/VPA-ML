//+------------------------------------------------------------------+
//|                                                  #ClearLines.mq4 |
//|                                  Copyright 2025, Michal Macháček |
//|                                     https://github.com/mmachacek |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Michal Macháček"
#property link      "https://github.com/mmachacek"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
input string linePrefix = "HL"; // The prefix used to identify support/resistance lines for deletion.
input string lineZonePrefix = "Z"; // The prefix used to identify zones arround support/resistance lines for deletion.
void OnStart()
  {
   // Delete all objects on the current chart with the prefix 'linePrefix'
   ObjectsDeleteAll(0, linePrefix);
   
   // Delete all objects on the current chart with the prefix 'lineZonePrefix'
   ObjectsDeleteAll(0, lineZonePrefix);
  }
//+------------------------------------------------------------------+
