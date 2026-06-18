//+------------------------------------------------------------------+
//|                         SM_VIP_Replica.mq4                       |
//|                         Editable MT4 indicator replica           |
//+------------------------------------------------------------------+
#property strict
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_color1 DeepSkyBlue
#property indicator_color2 DimGray
#property indicator_color3 Orange
#property indicator_color4 Lime
#property indicator_color5 Lime
#property indicator_color6 Magenta
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 1
#property indicator_width4 1
#property indicator_width5 1
#property indicator_width6 1
#property indicator_style2 STYLE_DOT
#property indicator_style3 STYLE_DOT
#property indicator_style4 STYLE_DOT

input int    RsiLength     = 5;
input int    RsiPrice      = PRICE_CLOSE;
input int    HalfLength    = 5;
input int    DevPeriod     = 100;
input double Deviations    = 0.7;
input bool   NoDellArr     = true;
input int    Arr_otstup    = 0;
input int    Arr_width     = 1;
input color  Arr_Up        = Lime;
input color  Arr_Dn        = Magenta;
input bool   AlertsMessage = false;
input bool   AlertsSound   = false;
input bool   AlertsEmail   = false;
input bool   AlertsMobile  = false;
input int    SignalBar     = 1;
input bool   ShowArrBuf    = true;
input int    History       = 3000;
input int    SignalCooldownBars = 8;
input bool   ConfirmTurn    = true;
input bool   ShowDivergence = true;
input int    DivergenceLookback = 40;
input int    DivergenceSwingStrength = 2;
input double DivergencePriceTolerancePips = 3.0;
input double DivergenceMinRsiDelta = 2.0;
input bool   DivergenceRequireBandTouch = false;
input int    DivergenceBandTouchRadius = 3;
input bool   RequireFirstDivergencePointExtreme = true;
input bool   UseBandForFirstExtreme = true;
input double FirstExtremeBandTolerance = 2.0;
input bool   UseLevelForFirstExtreme = true;
input double FirstExtremeLowLevel = 25.0;
input double FirstExtremeHighLevel = 75.0;
input bool   DrawDivergenceTextLabels = true;
input color  BullishDivergenceColor = Lime;
input color  BearishDivergenceColor = Magenta;

double RsiLine[];
double MiddleBand[];
double UpperBand[];
double LowerBand[];
double BuyArrows[];
double SellArrows[];

datetime lastAlertTime = 0;
string divergencePrefix = "SM_VIP_REPLICA_DIV_";

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorShortName("SM_VIP Replica");

   SetIndexBuffer(0, RsiLine);
   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 1);
   SetIndexLabel(0, "RSI");
   SetIndexEmptyValue(0, EMPTY_VALUE);

   SetIndexBuffer(1, MiddleBand);
   SetIndexStyle(1, DRAW_LINE, STYLE_DOT, 1);
   SetIndexLabel(1, "Middle");
   SetIndexEmptyValue(1, EMPTY_VALUE);

   SetIndexBuffer(2, UpperBand);
   SetIndexStyle(2, DRAW_LINE, STYLE_DOT, 1);
   SetIndexLabel(2, "Upper band");
   SetIndexEmptyValue(2, EMPTY_VALUE);

   SetIndexBuffer(3, LowerBand);
   SetIndexStyle(3, DRAW_LINE, STYLE_DOT, 1);
   SetIndexLabel(3, "Lower band");
   SetIndexEmptyValue(3, EMPTY_VALUE);

   SetIndexBuffer(4, BuyArrows);
   SetIndexStyle(4, DRAW_ARROW, STYLE_SOLID, Arr_width, Arr_Up);
   SetIndexArrow(4, 233);
   SetIndexLabel(4, "Buy arrow");
   SetIndexEmptyValue(4, EMPTY_VALUE);

   SetIndexBuffer(5, SellArrows);
   SetIndexStyle(5, DRAW_ARROW, STYLE_SOLID, Arr_width, Arr_Dn);
   SetIndexArrow(5, 234);
   SetIndexLabel(5, "Sell arrow");
   SetIndexEmptyValue(5, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDivergenceObjects();
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
   int smoothPeriod = MathMax(1, HalfLength * 2 + 1);
   int devPeriod = MathMax(2, DevPeriod);
   int neededBars = MathMax(smoothPeriod, devPeriod) + 2;

   if(rates_total <= neededBars)
      return(0);

   int maxBars = MathMin(History, rates_total - neededBars);

   for(int bar = maxBars; bar >= 0; bar--)
   {
      RsiLine[bar] = iRSI(NULL, 0, RsiLength, RsiPrice, bar);
      MiddleBand[bar] = RsiAverage(bar, smoothPeriod);
      double deviation = RsiDeviation(bar, devPeriod, MiddleBand[bar]);

      UpperBand[bar] = MiddleBand[bar] + deviation * Deviations;
      LowerBand[bar] = MiddleBand[bar] - deviation * Deviations;
      BuyArrows[bar] = EMPTY_VALUE;
      SellArrows[bar] = EMPTY_VALUE;

      if(!ShowArrBuf)
         continue;

      bool buySignal = RsiLine[bar] <= LowerBand[bar] && RsiLine[bar + 1] > LowerBand[bar + 1];
      bool sellSignal = RsiLine[bar] >= UpperBand[bar] && RsiLine[bar + 1] < UpperBand[bar + 1];

      if(ConfirmTurn)
      {
         buySignal = buySignal && RsiLine[bar] > RsiLine[bar + 1];
         sellSignal = sellSignal && RsiLine[bar] < RsiLine[bar + 1];
      }

      buySignal = buySignal && !HasRecentSignal(BuyArrows, bar);
      sellSignal = sellSignal && !HasRecentSignal(SellArrows, bar);

      if(buySignal)
         BuyArrows[bar] = MathMax(0, LowerBand[bar] - Arr_otstup);

      if(sellSignal)
         SellArrows[bar] = MathMin(100, UpperBand[bar] + Arr_otstup);
   }

   int alertBar = MathMax(0, SignalBar);
   if(alertBar <= maxBars)
      CheckAlert(alertBar, time[alertBar]);

   DrawDivergences(maxBars, time, high, low);

   return(rates_total);
}

//+------------------------------------------------------------------+
bool HasRecentSignal(double &signalBuffer[], int bar)
{
   int bars = MathMax(0, SignalCooldownBars);

   for(int i = 1; i <= bars; i++)
   {
      int shift = bar + i;
      if(shift >= Bars)
         continue;

      if(signalBuffer[shift] != EMPTY_VALUE)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
double RsiAverage(int bar, int period)
{
   double sum = 0.0;
   int count = 0;

   for(int i = 0; i < period; i++)
   {
      sum += iRSI(NULL, 0, RsiLength, RsiPrice, bar + i);
      count++;
   }

   if(count == 0)
      return(EMPTY_VALUE);

   return(sum / count);
}

//+------------------------------------------------------------------+
double RsiDeviation(int bar, int period, double center)
{
   double sum = 0.0;
   int count = 0;

   for(int i = 0; i < period; i++)
   {
      double value = iRSI(NULL, 0, RsiLength, RsiPrice, bar + i);
      sum += MathPow(value - center, 2);
      count++;
   }

   if(count <= 1)
      return(0.0);

   return(MathSqrt(sum / count));
}

//+------------------------------------------------------------------+
void CheckAlert(int bar, datetime signalTime)
{
   if(signalTime == lastAlertTime)
      return;

   string direction = "";

   if(BuyArrows[bar] != EMPTY_VALUE)
      direction = "BUY";

   if(SellArrows[bar] != EMPTY_VALUE)
      direction = "SELL";

   if(direction == "")
      return;

   lastAlertTime = signalTime;

   string message = Symbol() + " " + IntegerToString(Period()) + " SM_VIP Replica " + direction;

   if(AlertsMessage)
      Alert(message);

   if(AlertsSound)
      PlaySound("alert.wav");

   if(AlertsEmail)
      SendMail("SM_VIP Replica", message);

   if(AlertsMobile)
      SendNotification(message);
}

//+------------------------------------------------------------------+
void DrawDivergences(int maxBars,
                     const datetime &time[],
                     const double &high[],
                     const double &low[])
{
   if(!ShowDivergence)
   {
      DeleteDivergenceObjects();
      return;
   }

   DeleteDivergenceObjects();

   int strength = MathMax(1, DivergenceSwingStrength);
   int start = MathMax(strength, maxBars - MathMax(strength + 2, DivergenceLookback));

   for(int bar = start; bar >= strength; bar--)
   {
      if(IsPriceSwingLow(bar, low, strength) && HasBullishDivergence(bar, low, strength))
         DrawDivergence(bar, FindPreviousSwingLow(bar, low, strength), time, low, true);

      if(IsPriceSwingHigh(bar, high, strength) && HasBearishDivergence(bar, high, strength))
         DrawDivergence(bar, FindPreviousSwingHigh(bar, high, strength), time, high, false);
   }
}

//+------------------------------------------------------------------+
bool HasBullishDivergence(int currentShift, const double &low[], int strength)
{
   int previousShift = FindPreviousSwingLow(currentShift, low, strength);

   if(previousShift < 0)
      return(false);

   if(!IsFirstPointExtreme(previousShift, true))
      return(false);

   double tolerance = MathMax(0.0, DivergencePriceTolerancePips) * PipSize();
   bool priceLower = low[currentShift] <= low[previousShift] + tolerance;
   bool rsiHigher = RsiLine[currentShift] >= RsiLine[previousShift] + MathMax(0.0, DivergenceMinRsiDelta);

   if(!priceLower || !rsiHigher)
      return(false);

   return(!DivergenceRequireBandTouch || HasLowerBandTouchNear(currentShift));
}

//+------------------------------------------------------------------+
bool HasBearishDivergence(int currentShift, const double &high[], int strength)
{
   int previousShift = FindPreviousSwingHigh(currentShift, high, strength);

   if(previousShift < 0)
      return(false);

   if(!IsFirstPointExtreme(previousShift, false))
      return(false);

   double tolerance = MathMax(0.0, DivergencePriceTolerancePips) * PipSize();
   bool priceHigher = high[currentShift] >= high[previousShift] - tolerance;
   bool rsiLower = RsiLine[currentShift] <= RsiLine[previousShift] - MathMax(0.0, DivergenceMinRsiDelta);

   if(!priceHigher || !rsiLower)
      return(false);

   return(!DivergenceRequireBandTouch || HasUpperBandTouchNear(currentShift));
}

//+------------------------------------------------------------------+
bool IsPriceSwingLow(int shift, const double &low[], int strength)
{
   for(int i = 1; i <= strength; i++)
   {
      if(low[shift] > low[shift - i] || low[shift] >= low[shift + i])
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
bool IsPriceSwingHigh(int shift, const double &high[], int strength)
{
   for(int i = 1; i <= strength; i++)
   {
      if(high[shift] < high[shift - i] || high[shift] <= high[shift + i])
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
int FindPreviousSwingLow(int currentShift, const double &low[], int strength)
{
   int lastShift = MathMin(Bars - strength - 1, currentShift + MathMax(strength + 2, DivergenceLookback));

   for(int shift = currentShift + strength + 1; shift <= lastShift; shift++)
   {
      if(IsPriceSwingLow(shift, low, strength))
         return(shift);
   }

   return(-1);
}

//+------------------------------------------------------------------+
int FindPreviousSwingHigh(int currentShift, const double &high[], int strength)
{
   int lastShift = MathMin(Bars - strength - 1, currentShift + MathMax(strength + 2, DivergenceLookback));

   for(int shift = currentShift + strength + 1; shift <= lastShift; shift++)
   {
      if(IsPriceSwingHigh(shift, high, strength))
         return(shift);
   }

   return(-1);
}

//+------------------------------------------------------------------+
bool HasLowerBandTouchNear(int centerShift)
{
   int radius = MathMax(0, DivergenceBandTouchRadius);

   for(int offset = -radius; offset <= radius; offset++)
   {
      int shift = centerShift + offset;

      if(shift < 0 || shift >= Bars)
         continue;

      if(RsiLine[shift] != EMPTY_VALUE && LowerBand[shift] != EMPTY_VALUE && RsiLine[shift] <= LowerBand[shift])
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool HasUpperBandTouchNear(int centerShift)
{
   int radius = MathMax(0, DivergenceBandTouchRadius);

   for(int offset = -radius; offset <= radius; offset++)
   {
      int shift = centerShift + offset;

      if(shift < 0 || shift >= Bars)
         continue;

      if(RsiLine[shift] != EMPTY_VALUE && UpperBand[shift] != EMPTY_VALUE && RsiLine[shift] >= UpperBand[shift])
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool IsFirstPointExtreme(int shift, bool bullish)
{
   if(!RequireFirstDivergencePointExtreme)
      return(true);

   bool bandExtreme = false;
   bool levelExtreme = false;

   if(UseBandForFirstExtreme)
   {
      double tolerance = MathMax(0.0, FirstExtremeBandTolerance);

      if(bullish)
         bandExtreme = RsiLine[shift] <= LowerBand[shift] + tolerance;
      else
         bandExtreme = RsiLine[shift] >= UpperBand[shift] - tolerance;
   }

   if(UseLevelForFirstExtreme)
   {
      if(bullish)
         levelExtreme = RsiLine[shift] <= FirstExtremeLowLevel;
      else
         levelExtreme = RsiLine[shift] >= FirstExtremeHighLevel;
   }

   if(UseBandForFirstExtreme && UseLevelForFirstExtreme)
      return(bandExtreme || levelExtreme);

   if(UseBandForFirstExtreme)
      return(bandExtreme);

   if(UseLevelForFirstExtreme)
      return(levelExtreme);

   return(true);
}

//+------------------------------------------------------------------+
void DrawDivergence(int currentShift,
                    int previousShift,
                    const datetime &time[],
                    const double &price[],
                    bool bullish)
{
   if(previousShift < 0)
      return;

   int window = WindowFind("SM_VIP Replica");
   if(window < 0)
      window = WindowFind("SM VIP Replica");
   if(window < 0)
      window = 1;

   string side = bullish ? "BULL" : "BEAR";
   color lineColor = bullish ? BullishDivergenceColor : BearishDivergenceColor;

   string smLine = divergencePrefix + side + "_SM_" + IntegerToString(currentShift);
   ObjectCreate(0, smLine, OBJ_TREND, window, time[previousShift], RsiLine[previousShift], time[currentShift], RsiLine[currentShift]);
   ObjectSetInteger(0, smLine, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, smLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, smLine, OBJPROP_RAY, false);
   ObjectSetInteger(0, smLine, OBJPROP_HIDDEN, true);

   string priceLine = divergencePrefix + side + "_PRICE_" + IntegerToString(currentShift);
   ObjectCreate(0, priceLine, OBJ_TREND, 0, time[previousShift], price[previousShift], time[currentShift], price[currentShift]);
   ObjectSetInteger(0, priceLine, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, priceLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, priceLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, priceLine, OBJPROP_RAY, false);
   ObjectSetInteger(0, priceLine, OBJPROP_HIDDEN, true);

   if(DrawDivergenceTextLabels)
   {
      string label = divergencePrefix + side + "_LABEL_" + IntegerToString(currentShift);
      ObjectCreate(0, label, OBJ_TEXT, window, time[currentShift], RsiLine[currentShift]);
      ObjectSetString(0, label, OBJPROP_TEXT, bullish ? "Bull div" : "Bear div");
      ObjectSetString(0, label, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, label, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, label, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
void DeleteDivergenceObjects()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, divergencePrefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
double PipSize()
{
   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
}
//+------------------------------------------------------------------+
