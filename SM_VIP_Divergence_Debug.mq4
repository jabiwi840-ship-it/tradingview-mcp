//+------------------------------------------------------------------+
//|                    SM_VIP_Divergence_Debug.mq4                   |
//|                    Visual divergence helper for SM_VIP_Replica   |
//+------------------------------------------------------------------+
#property strict
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_color1 Lime
#property indicator_color2 Magenta
#property indicator_width1 2
#property indicator_width2 2

input string SMIndicatorName = "SM_VIP_Replica";
input int    SM_RsiLength = 5;
input int    SM_RsiPrice = PRICE_CLOSE;
input int    SM_HalfLength = 5;
input int    SM_DevPeriod = 100;
input double SM_Deviations = 0.7;
input int    SM_SignalCooldownBars = 8;
input bool   SM_ConfirmTurn = true;

input int    LookbackBars = 500;
input int    SwingStrength = 2;
input int    DivergenceLookback = 40;
input double PriceTolerancePips = 3.0;
input double MinSMDelta = 2.0;
input bool   RequireBandTouch = false;
input int    BandTouchRadius = 3;
input bool   DrawDivergenceLines = true;
input bool   DrawPriceMarks = true;
input bool   DrawTextLabels = true;
input color  BullishColor = Lime;
input color  BearishColor = Magenta;

double BullishMarks[];
double BearishMarks[];

string objectPrefix = "SMVIP_DIV_DEBUG_";

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorShortName("SM VIP Divergence Debug");

   SetIndexBuffer(0, BullishMarks);
   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 2, BullishColor);
   SetIndexArrow(0, 233);
   SetIndexLabel(0, "Bullish divergence");
   SetIndexEmptyValue(0, EMPTY_VALUE);

   SetIndexBuffer(1, BearishMarks);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 2, BearishColor);
   SetIndexArrow(1, 234);
   SetIndexLabel(1, "Bearish divergence");
   SetIndexEmptyValue(1, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDebugObjects();
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total <= SwingStrength * 2 + 10)
      return(0);

   DeleteDebugObjects();

   int maxBars = MathMin(LookbackBars, rates_total - SwingStrength - 2);

   for(int bar = maxBars; bar >= 0; bar--)
   {
      BullishMarks[bar] = EMPTY_VALUE;
      BearishMarks[bar] = EMPTY_VALUE;
   }

   for(int bar = maxBars - DivergenceLookback; bar >= SwingStrength; bar--)
   {
      if(IsPriceSwingLow(bar, low) && HasBullishDivergence(bar, low))
      {
         double sm = GetSMValue(0, bar);
         BullishMarks[bar] = sm;
         DrawDivergence(bar, time, low, high, true);
      }

      if(IsPriceSwingHigh(bar, high) && HasBearishDivergence(bar, high))
      {
         double sm = GetSMValue(0, bar);
         BearishMarks[bar] = sm;
         DrawDivergence(bar, time, low, high, false);
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
bool HasBullishDivergence(int currentShift, const double &low[])
{
   int previousShift = FindPreviousSwingLow(currentShift, low);

   if(previousShift < 0)
      return(false);

   double currentSM = GetSMValue(0, currentShift);
   double previousSM = GetSMValue(0, previousShift);

   if(currentSM == EMPTY_VALUE || previousSM == EMPTY_VALUE)
      return(false);

   double tolerance = MathMax(0.0, PriceTolerancePips) * PipSize();
   bool priceLower = low[currentShift] <= low[previousShift] + tolerance;
   bool smHigher = currentSM >= previousSM + MathMax(0.0, MinSMDelta);

   if(!priceLower || !smHigher)
      return(false);

   return(!RequireBandTouch || HasLowerBandTouchNear(currentShift));
}

//+------------------------------------------------------------------+
bool HasBearishDivergence(int currentShift, const double &high[])
{
   int previousShift = FindPreviousSwingHigh(currentShift, high);

   if(previousShift < 0)
      return(false);

   double currentSM = GetSMValue(0, currentShift);
   double previousSM = GetSMValue(0, previousShift);

   if(currentSM == EMPTY_VALUE || previousSM == EMPTY_VALUE)
      return(false);

   double tolerance = MathMax(0.0, PriceTolerancePips) * PipSize();
   bool priceHigher = high[currentShift] >= high[previousShift] - tolerance;
   bool smLower = currentSM <= previousSM - MathMax(0.0, MinSMDelta);

   if(!priceHigher || !smLower)
      return(false);

   return(!RequireBandTouch || HasUpperBandTouchNear(currentShift));
}

//+------------------------------------------------------------------+
bool IsPriceSwingLow(int shift, const double &low[])
{
   for(int i = 1; i <= SwingStrength; i++)
   {
      if(low[shift] > low[shift - i] || low[shift] >= low[shift + i])
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
bool IsPriceSwingHigh(int shift, const double &high[])
{
   for(int i = 1; i <= SwingStrength; i++)
   {
      if(high[shift] < high[shift - i] || high[shift] <= high[shift + i])
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
int FindPreviousSwingLow(int currentShift, const double &low[])
{
   int lastShift = MathMin(Bars - SwingStrength - 1, currentShift + MathMax(SwingStrength + 2, DivergenceLookback));

   for(int shift = currentShift + SwingStrength + 1; shift <= lastShift; shift++)
   {
      if(IsPriceSwingLow(shift, low))
         return(shift);
   }

   return(-1);
}

//+------------------------------------------------------------------+
int FindPreviousSwingHigh(int currentShift, const double &high[])
{
   int lastShift = MathMin(Bars - SwingStrength - 1, currentShift + MathMax(SwingStrength + 2, DivergenceLookback));

   for(int shift = currentShift + SwingStrength + 1; shift <= lastShift; shift++)
   {
      if(IsPriceSwingHigh(shift, high))
         return(shift);
   }

   return(-1);
}

//+------------------------------------------------------------------+
bool HasLowerBandTouchNear(int centerShift)
{
   int radius = MathMax(0, BandTouchRadius);

   for(int offset = -radius; offset <= radius; offset++)
   {
      int shift = centerShift + offset;

      if(shift < 0 || shift >= Bars)
         continue;

      double sm = GetSMValue(0, shift);
      double lower = GetSMValue(3, shift);

      if(sm != EMPTY_VALUE && lower != EMPTY_VALUE && sm <= lower)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool HasUpperBandTouchNear(int centerShift)
{
   int radius = MathMax(0, BandTouchRadius);

   for(int offset = -radius; offset <= radius; offset++)
   {
      int shift = centerShift + offset;

      if(shift < 0 || shift >= Bars)
         continue;

      double sm = GetSMValue(0, shift);
      double upper = GetSMValue(2, shift);

      if(sm != EMPTY_VALUE && upper != EMPTY_VALUE && sm >= upper)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
void DrawDivergence(int currentShift,
                    const datetime &time[],
                    const double &low[],
                    const double &high[],
                    bool bullish)
{
   int previousShift = bullish ? FindPreviousSwingLow(currentShift, low)
                               : FindPreviousSwingHigh(currentShift, high);

   if(previousShift < 0)
      return;

   color lineColor = bullish ? BullishColor : BearishColor;
   double currentSM = GetSMValue(0, currentShift);
   double previousSM = GetSMValue(0, previousShift);
   string side = bullish ? "BULL" : "BEAR";

   if(DrawDivergenceLines)
   {
      string smLine = objectPrefix + side + "_SM_" + IntegerToString(currentShift);
      ObjectCreate(0, smLine, OBJ_TREND, WindowFind("SM VIP Divergence Debug"), time[previousShift], previousSM, time[currentShift], currentSM);
      ObjectSetInteger(0, smLine, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, smLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, smLine, OBJPROP_RAY, false);
      ObjectSetInteger(0, smLine, OBJPROP_HIDDEN, true);

      if(DrawPriceMarks)
      {
         string priceLine = objectPrefix + side + "_PRICE_" + IntegerToString(currentShift);
         double previousPrice = bullish ? low[previousShift] : high[previousShift];
         double currentPrice = bullish ? low[currentShift] : high[currentShift];
         ObjectCreate(0, priceLine, OBJ_TREND, 0, time[previousShift], previousPrice, time[currentShift], currentPrice);
         ObjectSetInteger(0, priceLine, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, priceLine, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, priceLine, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, priceLine, OBJPROP_RAY, false);
         ObjectSetInteger(0, priceLine, OBJPROP_HIDDEN, true);
      }
   }

   if(DrawTextLabels)
   {
      string label = objectPrefix + side + "_LABEL_" + IntegerToString(currentShift);
      ObjectCreate(0, label, OBJ_TEXT, WindowFind("SM VIP Divergence Debug"), time[currentShift], currentSM);
      ObjectSetString(0, label, OBJPROP_TEXT, bullish ? "Bull div" : "Bear div");
      ObjectSetString(0, label, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, label, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, label, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
void DeleteDebugObjects()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, objectPrefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
double GetSMValue(int buffer, int shift)
{
   return(iCustom(NULL, 0, SMIndicatorName,
                  SM_RsiLength,
                  SM_RsiPrice,
                  SM_HalfLength,
                  SM_DevPeriod,
                  SM_Deviations,
                  true,
                  0,
                  1,
                  Lime,
                  Magenta,
                  false,
                  false,
                  false,
                  false,
                  1,
                  true,
                  3000,
                  SM_SignalCooldownBars,
                  SM_ConfirmTurn,
                  buffer,
                  shift));
}

//+------------------------------------------------------------------+
double PipSize()
{
   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
}
//+------------------------------------------------------------------+
