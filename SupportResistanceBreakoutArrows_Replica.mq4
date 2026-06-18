//+------------------------------------------------------------------+
//|              SupportResistanceBreakoutArrows_Replica.mq4         |
//|              Editable MT4 indicator replica                      |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_color1 Red
#property indicator_color2 Blue
#property indicator_color3 Magenta
#property indicator_color4 Blue
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 2
#property indicator_width4 2

input bool   RSICCI_Filter = false;
input double RSIPeriod     = 14.0;
input double RSIOverbought = 75.0;
input double RSIOversold   = 25.0;
input double CCIPeriod     = 14.0;
input double CCIBuyLevel   = 50.0;
input double CCISellLevel  = -50.0;
input bool   HighLow       = false;
input int    SignalDots    = 3;
input int    ConfirmationBars = 1;
input bool   ShowConfluenceSignals = true;
input int    ConfluenceBars = 5;
input int    SignalCooldownBars = 8;
input bool   OneSignalPerZone = true;
input double ZoneRepeatTolerancePoints = 20.0;
input double TouchTolerancePoints = 10.0;
input string SMIndicatorName = "SM_VIP_Replica";
input int    SM_RsiLength = 5;
input int    SM_RsiPrice = PRICE_CLOSE;
input int    SM_HalfLength = 5;
input int    SM_DevPeriod = 100;
input double SM_Deviations = 0.7;
input int    SM_SignalCooldownBars = 8;
input bool   SM_ConfirmTurn = true;
input bool   Alerts        = false;
input bool   AlertOnClose  = true;
input int    BarCount      = 10000;

double ResistanceDots[];
double SupportDots[];
double SellArrows[];
double BuyArrows[];

datetime lastAlertTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorShortName("Support and Resistance Breakout Arrows Replica");

   SetIndexBuffer(0, ResistanceDots);
   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 1);
   SetIndexArrow(0, 159);
   SetIndexLabel(0, "Resistance dots");
   SetIndexEmptyValue(0, EMPTY_VALUE);

   SetIndexBuffer(1, SupportDots);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 1);
   SetIndexArrow(1, 159);
   SetIndexLabel(1, "Support dots");
   SetIndexEmptyValue(1, EMPTY_VALUE);

   SetIndexBuffer(2, SellArrows);
   if(ShowConfluenceSignals)
      SetIndexStyle(2, DRAW_ARROW, STYLE_SOLID, 2);
   else
      SetIndexStyle(2, DRAW_NONE);
   SetIndexArrow(2, 234);
   SetIndexLabel(2, "Sell confluence signal");
   SetIndexEmptyValue(2, EMPTY_VALUE);

   SetIndexBuffer(3, BuyArrows);
   if(ShowConfluenceSignals)
      SetIndexStyle(3, DRAW_ARROW, STYLE_SOLID, 2);
   else
      SetIndexStyle(3, DRAW_NONE);
   SetIndexArrow(3, 233);
   SetIndexLabel(3, "Buy confluence signal");
   SetIndexEmptyValue(3, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
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
   int strength = MathMax(1, SignalDots);
   int confirmBars = MathMax(1, ConfirmationBars);

   if(rates_total <= strength + confirmBars + 5)
      return(0);

   int maxBars = MathMin(BarCount + confirmBars, rates_total - strength - 2);
   int start = maxBars;

   for(int i = start; i >= 0; i--)
   {
      ResistanceDots[i] = EMPTY_VALUE;
      SupportDots[i]    = EMPTY_VALUE;
      SellArrows[i]     = EMPTY_VALUE;
      BuyArrows[i]      = EMPTY_VALUE;
   }

   double resistance = EMPTY_VALUE;
   double support = EMPTY_VALUE;
   double lastBuyZone = EMPTY_VALUE;
   double lastSellZone = EMPTY_VALUE;
   double dotOffset = MathMax(Point * 10, (high[ArrayMaximum(high, MathMin(100, rates_total), 0)] - low[ArrayMinimum(low, MathMin(100, rates_total), 0)]) * 0.003);
   double arrowOffset = dotOffset * 2.5;

   for(int candidate = start; candidate >= confirmBars; candidate--)
   {
      int bar = candidate - confirmBars;
      bool swingHigh = IsSwingHigh(candidate, high, close, strength, confirmBars);
      bool swingLow = IsSwingLow(candidate, low, close, strength, confirmBars);

      if(swingHigh)
         resistance = HighLow ? high[candidate] : MathMax(open[candidate], close[candidate]);

      if(swingLow)
         support = HighLow ? low[candidate] : MathMin(open[candidate], close[candidate]);

      if(resistance != EMPTY_VALUE)
         ResistanceDots[bar] = resistance + dotOffset;

      if(support != EMPTY_VALUE)
         SupportDots[bar] = support - dotOffset;

      bool buyConfluence = IsSupportTouchedNow(bar, support, high, low) && HasRecentSMLowerTouch(bar);
      bool sellConfluence = IsResistanceTouchedNow(bar, resistance, high, low) && HasRecentSMUpperTouch(bar);

      buyConfluence = buyConfluence && !IsSameZone(support, lastBuyZone) && !HasRecentSignal(BuyArrows, bar);
      sellConfluence = sellConfluence && !IsSameZone(resistance, lastSellZone) && !HasRecentSignal(SellArrows, bar);

      if(buyConfluence)
      {
         BuyArrows[bar] = low[bar] - arrowOffset;
         lastBuyZone = support;
         FireAlert("BUY confluence", time[bar], close[bar]);
      }

      if(sellConfluence)
      {
         SellArrows[bar] = high[bar] + arrowOffset;
         lastSellZone = resistance;
         FireAlert("SELL confluence", time[bar], close[bar]);
      }

      int signalBar = AlertOnClose ? bar : bar + 1;
      if(signalBar >= rates_total)
         signalBar = bar;

      bool brokeUp = resistance != EMPTY_VALUE && close[bar] > resistance && close[bar + 1] <= resistance;
      bool brokeDown = support != EMPTY_VALUE && close[bar] < support && close[bar + 1] >= support;

      if(RSICCI_Filter)
      {
         brokeUp = brokeUp && PassBuyFilter(bar);
         brokeDown = brokeDown && PassSellFilter(bar);
      }

      if(brokeUp)
      {
         FireAlert("BUY breakout", time[signalBar], close[bar]);
      }

      if(brokeDown)
      {
         FireAlert("SELL breakout", time[signalBar], close[bar]);
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
bool IsSupportTouchedNow(int bar, double support, const double &high[], const double &low[])
{
   if(support == EMPTY_VALUE)
      return(false);

   double tolerance = TouchTolerancePoints * Point;
   return(low[bar] <= support + tolerance && high[bar] >= support - tolerance);
}

//+------------------------------------------------------------------+
bool IsResistanceTouchedNow(int bar, double resistance, const double &high[], const double &low[])
{
   if(resistance == EMPTY_VALUE)
      return(false);

   double tolerance = TouchTolerancePoints * Point;
   return(high[bar] >= resistance - tolerance && low[bar] <= resistance + tolerance);
}

//+------------------------------------------------------------------+
bool IsSameZone(double currentZone, double lastZone)
{
   if(!OneSignalPerZone)
      return(false);

   if(currentZone == EMPTY_VALUE || lastZone == EMPTY_VALUE)
      return(false);

   return(MathAbs(currentZone - lastZone) <= ZoneRepeatTolerancePoints * Point);
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
bool HasRecentSMLowerTouch(int bar)
{
   int bars = MathMax(1, ConfluenceBars);

   for(int i = 0; i < bars; i++)
   {
      int shift = bar + i;
      if(shift >= Bars)
         continue;

      double rsi = GetSMValue(0, shift);
      double lower = GetSMValue(3, shift);

      if(rsi != EMPTY_VALUE && lower != EMPTY_VALUE && rsi <= lower)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool HasRecentSMUpperTouch(int bar)
{
   int bars = MathMax(1, ConfluenceBars);

   for(int i = 0; i < bars; i++)
   {
      int shift = bar + i;
      if(shift >= Bars)
         continue;

      double rsi = GetSMValue(0, shift);
      double upper = GetSMValue(2, shift);

      if(rsi != EMPTY_VALUE && upper != EMPTY_VALUE && rsi >= upper)
         return(true);
   }

   return(false);
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
bool IsSwingHigh(int bar, const double &high[], const double &close[], int strength, int confirmBars)
{
   double value = HighLow ? high[bar] : close[bar];

   for(int i = 1; i <= strength; i++)
   {
      double leftValue = HighLow ? high[bar + i] : close[bar + i];

      if(value <= leftValue)
         return(false);
   }

   for(int j = 1; j <= confirmBars; j++)
   {
      double rightValue = HighLow ? high[bar - j] : close[bar - j];

      if(value < rightValue)
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
bool IsSwingLow(int bar, const double &low[], const double &close[], int strength, int confirmBars)
{
   double value = HighLow ? low[bar] : close[bar];

   for(int i = 1; i <= strength; i++)
   {
      double leftValue = HighLow ? low[bar + i] : close[bar + i];

      if(value >= leftValue)
         return(false);
   }

   for(int j = 1; j <= confirmBars; j++)
   {
      double rightValue = HighLow ? low[bar - j] : close[bar - j];

      if(value > rightValue)
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
bool PassBuyFilter(int bar)
{
   double rsi = iRSI(NULL, 0, (int)RSIPeriod, PRICE_CLOSE, bar);
   double cci = iCCI(NULL, 0, (int)CCIPeriod, PRICE_TYPICAL, bar);

   return(rsi <= RSIOverbought && cci >= CCIBuyLevel);
}

//+------------------------------------------------------------------+
bool PassSellFilter(int bar)
{
   double rsi = iRSI(NULL, 0, (int)RSIPeriod, PRICE_CLOSE, bar);
   double cci = iCCI(NULL, 0, (int)CCIPeriod, PRICE_TYPICAL, bar);

   return(rsi >= RSIOversold && cci <= CCISellLevel);
}

//+------------------------------------------------------------------+
void FireAlert(string direction, datetime signalTime, double price)
{
   if(!Alerts)
      return;

   if(signalTime == lastAlertTime)
      return;

   if(signalTime != Time[0] && !AlertOnClose)
      return;

   lastAlertTime = signalTime;
   Alert(Symbol(), " ", Period(), " - ", direction, " at ", DoubleToString(price, Digits));
}
//+------------------------------------------------------------------+
