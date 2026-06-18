//+------------------------------------------------------------------+
//|              SupportResistanceBreakoutArrows_Replica.mq4         |
//|              Editable MT4 indicator replica                      |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1 Red
#property indicator_color2 Blue
#property indicator_color3 Magenta
#property indicator_color4 Blue
#property indicator_color5 Gold
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 2
#property indicator_width4 2
#property indicator_width5 1

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
input bool   UseSequentialSMFirst = false;
input bool   AllowSameBarSMAndSR = false;
input bool   UseSMDivergenceFilter = false;
input int    DivergenceLookback = 30;
input int    DivergenceSwingStrength = 2;
input double DivergencePriceTolerancePips = 3.0;
input double DivergenceMinSMDelta = 2.0;
input bool   RequireDivergenceSMBandTouch = true;
input int    SignalCooldownBars = 8;
input bool   OneSignalPerZone = true;
input double ZoneRepeatTolerancePoints = 20.0;
input double TouchTolerancePoints = 10.0;
input double MinSwingRangePips = 8.0;
input double MinSwingAtrMultiplier = 0.35;
input int    SwingAtrPeriod = 14;
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
input int    EmaPeriod     = 30;
input bool   ShowRangeMeter = true;
input int    AdrPeriod      = 14;
input double AdrWarnPercent = 75.0;
input double AdrLimitPercent = 90.0;
input int    AdxPeriod      = 10;
input double AdxRangeLevel  = 22.0;
input double AdxTrendLevel  = 25.0;
input bool   UseTrendSignalFilter = true;
input bool   ShowSetupDiagnostics = false;
input int    DiagnosticBars = 250;
input int    DiagnosticFontSize = 8;
input int    RangeMeterCorner = 0;
input int    RangeMeterX    = 12;
input int    RangeMeterY    = 22;

double ResistanceDots[];
double SupportDots[];
double SellArrows[];
double BuyArrows[];
double EmaLine[];

datetime lastAlertTime = 0;
string rangeMeterPrefix = "SR_SM_VIP_RANGE_METER_";
string diagnosticPrefix = "SR_SM_VIP_DIAG_";

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

   SetIndexBuffer(4, EmaLine);
   SetIndexStyle(4, DRAW_LINE, STYLE_SOLID, 1);
   SetIndexLabel(4, "EMA 30");
   SetIndexEmptyValue(4, EMPTY_VALUE);
   SetIndexDrawBegin(4, MathMax(1, EmaPeriod));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteRangeMeter();
   DeleteDiagnostics();
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

   if(ShowSetupDiagnostics)
      DeleteDiagnostics();
   else
      DeleteDiagnostics();

   for(int i = start; i >= 0; i--)
   {
      ResistanceDots[i] = EMPTY_VALUE;
      SupportDots[i]    = EMPTY_VALUE;
      SellArrows[i]     = EMPTY_VALUE;
      BuyArrows[i]      = EMPTY_VALUE;
      EmaLine[i]         = iMA(NULL, 0, MathMax(1, EmaPeriod), 0, MODE_EMA, PRICE_CLOSE, i);
   }

   double resistance = EMPTY_VALUE;
   double support = EMPTY_VALUE;
   double lastBuyZone = EMPTY_VALUE;
   double lastSellZone = EMPTY_VALUE;
   int pendingBuySMBar = -1;
   int pendingSellSMBar = -1;
   double dotOffset = MathMax(Point * 10, (high[ArrayMaximum(high, MathMin(100, rates_total), 0)] - low[ArrayMinimum(low, MathMin(100, rates_total), 0)]) * 0.003);
   double arrowOffset = dotOffset * 2.5;

   for(int candidate = start; candidate >= confirmBars; candidate--)
   {
      int bar = candidate - confirmBars;
      bool swingHigh = IsSwingHigh(candidate, high, close, strength, confirmBars);
      bool swingLow = IsSwingLow(candidate, low, close, strength, confirmBars);

      if(swingHigh && IsSignificantSwingHigh(candidate, high, low, close, strength, confirmBars))
         resistance = HighLow ? high[candidate] : MathMax(open[candidate], close[candidate]);

      if(swingLow && IsSignificantSwingLow(candidate, high, low, close, strength, confirmBars))
         support = HighLow ? low[candidate] : MathMin(open[candidate], close[candidate]);

      if(resistance != EMPTY_VALUE)
         ResistanceDots[bar] = resistance + dotOffset;

      if(support != EMPTY_VALUE)
         SupportDots[bar] = support - dotOffset;

      bool buySMEvent = IsSMLowerTouchEvent(bar);
      bool sellSMEvent = IsSMUpperTouchEvent(bar);

      if(buySMEvent)
      {
         pendingBuySMBar = bar;
         DrawDiagnostic(bar, time[bar], low[bar] - arrowOffset * 0.7, "SM BUY", Lime);
      }

      if(sellSMEvent)
      {
         pendingSellSMBar = bar;
         DrawDiagnostic(bar, time[bar], high[bar] + arrowOffset * 0.7, "SM SELL", Magenta);
      }

      bool buySRTouch = IsSupportTouchedNow(bar, support, high, low);
      bool sellSRTouch = IsResistanceTouchedNow(bar, resistance, high, low);
      bool buySMValid = UseSequentialSMFirst ? HasValidPendingSMEvent(bar, pendingBuySMBar) : HasRecentSMLowerTouch(bar);
      bool sellSMValid = UseSequentialSMFirst ? HasValidPendingSMEvent(bar, pendingSellSMBar) : HasRecentSMUpperTouch(bar);
      bool buyConfluence = buySRTouch && buySMValid;
      bool sellConfluence = sellSRTouch && sellSMValid;
      bool buyDivergenceOk = true;
      bool sellDivergenceOk = true;
      int buyDivergenceBar = UseSequentialSMFirst ? pendingBuySMBar : bar;
      int sellDivergenceBar = UseSequentialSMFirst ? pendingSellSMBar : bar;

      if(UseSMDivergenceFilter)
      {
         buyDivergenceOk = HasBullishSMDivergence(buyDivergenceBar, low);
         sellDivergenceOk = HasBearishSMDivergence(sellDivergenceBar, high);
         buyConfluence = buyConfluence && buyDivergenceOk;
         sellConfluence = sellConfluence && sellDivergenceOk;
      }

      bool buyDirectionOk = AllowBuySignal(bar, close);
      bool sellDirectionOk = AllowSellSignal(bar, close);
      buyConfluence = buyConfluence && buyDirectionOk;
      sellConfluence = sellConfluence && sellDirectionOk;

      bool buyZoneOk = !IsSameZone(support, lastBuyZone);
      bool sellZoneOk = !IsSameZone(resistance, lastSellZone);
      bool buyCooldownOk = !HasRecentSignal(BuyArrows, bar);
      bool sellCooldownOk = !HasRecentSignal(SellArrows, bar);
      buyConfluence = buyConfluence && buyZoneOk && buyCooldownOk;
      sellConfluence = sellConfluence && sellZoneOk && sellCooldownOk;

      DrawSetupDiagnostics(bar, time, high, low, arrowOffset,
                           buySRTouch, buySMValid, buyDivergenceOk, buyDirectionOk, buyZoneOk, buyCooldownOk,
                           sellSRTouch, sellSMValid, sellDivergenceOk, sellDirectionOk, sellZoneOk, sellCooldownOk);

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

   UpdateRangeMeter();

   return(rates_total);
}

//+------------------------------------------------------------------+
void UpdateRangeMeter()
{
   if(!ShowRangeMeter)
   {
      DeleteRangeMeter();
      return;
   }

   double adr = AverageDailyRange(MathMax(1, AdrPeriod));
   double todayRange = iHigh(NULL, PERIOD_D1, 0) - iLow(NULL, PERIOD_D1, 0);

   if(adr <= 0.0 || todayRange <= 0.0)
      return;

   double usedPercent = todayRange / adr * 100.0;
   double remainingRange = MathMax(0.0, adr - todayRange);
   double adx = iADX(NULL, 0, MathMax(1, AdxPeriod), PRICE_CLOSE, MODE_MAIN, 0);
   string adxStatus = "NEUTRO";
   color adxColor = Silver;
   string status = "OK";
   color statusColor = Lime;

   if(usedPercent >= AdrLimitPercent)
   {
      status = "AGOTADO";
      statusColor = Red;
   }
   else if(usedPercent >= AdrWarnPercent)
   {
      status = "ALTO";
      statusColor = Gold;
   }

   if(adx < AdxRangeLevel)
   {
      adxStatus = "RANGO";
      adxColor = Lime;
   }
   else if(adx >= AdxTrendLevel)
   {
      adxStatus = "TENDENCIA";
      adxColor = Gold;
   }

   SetRangeMeterLabel(0, "Rango efectivo ADR(" + IntegerToString(MathMax(1, AdrPeriod)) + ")", White);
   SetRangeMeterLabel(1, "ADR: " + DoubleToString(ToPips(adr), 1) + " pips", Silver);
   SetRangeMeterLabel(2, "Hoy: " + DoubleToString(ToPips(todayRange), 1) + " pips", Silver);
   SetRangeMeterLabel(3, "Usado: " + DoubleToString(usedPercent, 1) + "%", statusColor);
   SetRangeMeterLabel(4, "Libre: " + DoubleToString(ToPips(remainingRange), 1) + " pips", Silver);
   SetRangeMeterLabel(5, "Estado: " + status, statusColor);
   SetRangeMeterLabel(6, "ADX(" + IntegerToString(MathMax(1, AdxPeriod)) + "): " + DoubleToString(adx, 1), adxColor);
   SetRangeMeterLabel(7, "Mercado: " + adxStatus, adxColor);
}

//+------------------------------------------------------------------+
void DrawSetupDiagnostics(int bar,
                          const datetime &time[],
                          const double &high[],
                          const double &low[],
                          double arrowOffset,
                          bool buySRTouch,
                          bool buySMValid,
                          bool buyDivergenceOk,
                          bool buyDirectionOk,
                          bool buyZoneOk,
                          bool buyCooldownOk,
                          bool sellSRTouch,
                          bool sellSMValid,
                          bool sellDivergenceOk,
                          bool sellDirectionOk,
                          bool sellZoneOk,
                          bool sellCooldownOk)
{
   if(!ShowSetupDiagnostics || bar > MathMax(0, DiagnosticBars))
      return;

   if(buySRTouch)
   {
      string buyMessage = "BUY OK";
      color buyColor = Lime;

      if(!buySMValid)
      {
         buyMessage = "BUY: NO SM";
         buyColor = Silver;
      }
      else if(!buyDivergenceOk)
      {
         buyMessage = "BUY: NO DIV";
         buyColor = Red;
      }
      else if(!buyDirectionOk)
      {
         buyMessage = "BUY: EMA/ADX";
         buyColor = Orange;
      }
      else if(!buyZoneOk)
      {
         buyMessage = "BUY: ZONE";
         buyColor = Orange;
      }
      else if(!buyCooldownOk)
      {
         buyMessage = "BUY: COOL";
         buyColor = Orange;
      }

      DrawDiagnostic(bar, time[bar], low[bar] - arrowOffset * 1.4, buyMessage, buyColor);
   }

   if(sellSRTouch)
   {
      string sellMessage = "SELL OK";
      color sellColor = Magenta;

      if(!sellSMValid)
      {
         sellMessage = "SELL: NO SM";
         sellColor = Silver;
      }
      else if(!sellDivergenceOk)
      {
         sellMessage = "SELL: NO DIV";
         sellColor = Red;
      }
      else if(!sellDirectionOk)
      {
         sellMessage = "SELL: EMA/ADX";
         sellColor = Orange;
      }
      else if(!sellZoneOk)
      {
         sellMessage = "SELL: ZONE";
         sellColor = Orange;
      }
      else if(!sellCooldownOk)
      {
         sellMessage = "SELL: COOL";
         sellColor = Orange;
      }

      DrawDiagnostic(bar, time[bar], high[bar] + arrowOffset * 1.4, sellMessage, sellColor);
   }
}

//+------------------------------------------------------------------+
void DrawDiagnostic(int bar, datetime eventTime, double price, string text, color textColor)
{
   if(!ShowSetupDiagnostics || bar > MathMax(0, DiagnosticBars))
      return;

   string name = diagnosticPrefix + IntegerToString(bar) + "_" +
                 IntegerToString(StringLen(text)) + "_" +
                 IntegerToString((int)StringGetChar(text, 0));

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, eventTime, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectMove(0, name, 0, eventTime, price);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, MathMax(6, DiagnosticFontSize));
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
void DeleteDiagnostics()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, diagnosticPrefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
double AverageDailyRange(int period)
{
   int availableBars = iBars(NULL, PERIOD_D1);
   int count = MathMin(period, availableBars - 1);

   if(count <= 0)
      return(0.0);

   double totalRange = 0.0;

   for(int i = 1; i <= count; i++)
      totalRange += iHigh(NULL, PERIOD_D1, i) - iLow(NULL, PERIOD_D1, i);

   return(totalRange / count);
}

//+------------------------------------------------------------------+
double PipSize()
{
   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
}

//+------------------------------------------------------------------+
double ToPips(double priceDistance)
{
   double pip = PipSize();

   if(pip <= 0.0)
      return(0.0);

   return(priceDistance / pip);
}

//+------------------------------------------------------------------+
void SetRangeMeterLabel(int row, string text, color textColor)
{
   string name = rangeMeterPrefix + IntegerToString(row);

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, RangeMeterDisplayCorner());
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, RangeMeterAnchor());
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, RangeMeterX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, RangeMeterY + row * 16);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
int RangeMeterAnchor()
{
   int corner = RangeMeterDisplayCorner();

   if(corner == 1)
      return(ANCHOR_RIGHT_UPPER);

   if(corner == 3)
      return(ANCHOR_RIGHT_LOWER);

   if(corner == 2)
      return(ANCHOR_LEFT_LOWER);

   return(ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
int RangeMeterDisplayCorner()
{
   if(RangeMeterCorner == 1)
      return(0);

   if(RangeMeterCorner == 3)
      return(2);

   return(RangeMeterCorner);
}

//+------------------------------------------------------------------+
void DeleteRangeMeter()
{
   for(int i = 0; i < 8; i++)
      ObjectDelete(0, rangeMeterPrefix + IntegerToString(i));
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
bool IsSMLowerTouchEvent(int bar)
{
   double rsi = GetSMValue(0, bar);
   double lower = GetSMValue(3, bar);

   if(rsi == EMPTY_VALUE || lower == EMPTY_VALUE || rsi > lower)
      return(false);

   double previousRsi = GetSMValue(0, bar + 1);
   double previousLower = GetSMValue(3, bar + 1);

   if(previousRsi == EMPTY_VALUE || previousLower == EMPTY_VALUE)
      return(true);

   return(previousRsi > previousLower);
}

//+------------------------------------------------------------------+
bool IsSMUpperTouchEvent(int bar)
{
   double rsi = GetSMValue(0, bar);
   double upper = GetSMValue(2, bar);

   if(rsi == EMPTY_VALUE || upper == EMPTY_VALUE || rsi < upper)
      return(false);

   double previousRsi = GetSMValue(0, bar + 1);
   double previousUpper = GetSMValue(2, bar + 1);

   if(previousRsi == EMPTY_VALUE || previousUpper == EMPTY_VALUE)
      return(true);

   return(previousRsi < previousUpper);
}

//+------------------------------------------------------------------+
bool HasValidPendingSMEvent(int currentBar, int pendingSMBar)
{
   if(pendingSMBar < 0)
      return(false);

   int barsAfterEvent = pendingSMBar - currentBar;
   int minBarsAfterEvent = AllowSameBarSMAndSR ? 0 : 1;

   if(barsAfterEvent < minBarsAfterEvent)
      return(false);

   return(barsAfterEvent <= MathMax(1, ConfluenceBars));
}

//+------------------------------------------------------------------+
bool HasBullishSMDivergence(int bar, const double &low[])
{
   int strength = MathMax(1, DivergenceSwingStrength);
   int currentShift = FindRecentLowShift(bar, low, strength);
   int previousShift = FindPreviousLowShift(currentShift, low, MathMax(strength + 2, DivergenceLookback), strength);

   if(currentShift < 0 || previousShift < 0)
      return(false);

   double currentSM = GetSMValue(0, currentShift);
   double previousSM = GetSMValue(0, previousShift);

   if(currentSM == EMPTY_VALUE || previousSM == EMPTY_VALUE)
      return(false);

   double tolerance = MathMax(0.0, DivergencePriceTolerancePips) * PipSize();
   bool priceMadeLowerLow = low[currentShift] <= low[previousShift] + tolerance;
   bool smMadeHigherLow = currentSM >= previousSM + MathMax(0.0, DivergenceMinSMDelta);

   if(!priceMadeLowerLow || !smMadeHigherLow)
      return(false);

   return(!RequireDivergenceSMBandTouch || HasSMLowerBandTouchNear(currentShift, strength));
}

//+------------------------------------------------------------------+
bool HasBearishSMDivergence(int bar, const double &high[])
{
   int strength = MathMax(1, DivergenceSwingStrength);
   int currentShift = FindRecentHighShift(bar, high, strength);
   int previousShift = FindPreviousHighShift(currentShift, high, MathMax(strength + 2, DivergenceLookback), strength);

   if(currentShift < 0 || previousShift < 0)
      return(false);

   double currentSM = GetSMValue(0, currentShift);
   double previousSM = GetSMValue(0, previousShift);

   if(currentSM == EMPTY_VALUE || previousSM == EMPTY_VALUE)
      return(false);

   double tolerance = MathMax(0.0, DivergencePriceTolerancePips) * PipSize();
   bool priceMadeHigherHigh = high[currentShift] >= high[previousShift] - tolerance;
   bool smMadeLowerHigh = currentSM <= previousSM - MathMax(0.0, DivergenceMinSMDelta);

   if(!priceMadeHigherHigh || !smMadeLowerHigh)
      return(false);

   return(!RequireDivergenceSMBandTouch || HasSMUpperBandTouchNear(currentShift, strength));
}

//+------------------------------------------------------------------+
int FindRecentLowShift(int bar, const double &low[], int strength)
{
   int bestShift = -1;
   double bestValue = EMPTY_VALUE;

   for(int i = 0; i <= strength; i++)
   {
      int shift = bar + i;
      if(shift >= Bars)
         break;

      if(bestShift < 0 || low[shift] < bestValue)
      {
         bestShift = shift;
         bestValue = low[shift];
      }
   }

   return(bestShift);
}

//+------------------------------------------------------------------+
int FindRecentHighShift(int bar, const double &high[], int strength)
{
   int bestShift = -1;
   double bestValue = -EMPTY_VALUE;

   for(int i = 0; i <= strength; i++)
   {
      int shift = bar + i;
      if(shift >= Bars)
         break;

      if(bestShift < 0 || high[shift] > bestValue)
      {
         bestShift = shift;
         bestValue = high[shift];
      }
   }

   return(bestShift);
}

//+------------------------------------------------------------------+
int FindPreviousLowShift(int currentShift, const double &low[], int lookback, int strength)
{
   int bestShift = -1;
   double bestValue = EMPTY_VALUE;
   int firstShift = currentShift + strength + 1;
   int lastShift = MathMin(Bars - 1, currentShift + lookback);

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(bestShift < 0 || low[shift] < bestValue)
      {
         bestShift = shift;
         bestValue = low[shift];
      }
   }

   return(bestShift);
}

//+------------------------------------------------------------------+
int FindPreviousHighShift(int currentShift, const double &high[], int lookback, int strength)
{
   int bestShift = -1;
   double bestValue = -EMPTY_VALUE;
   int firstShift = currentShift + strength + 1;
   int lastShift = MathMin(Bars - 1, currentShift + lookback);

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(bestShift < 0 || high[shift] > bestValue)
      {
         bestShift = shift;
         bestValue = high[shift];
      }
   }

   return(bestShift);
}

//+------------------------------------------------------------------+
bool HasSMLowerBandTouchNear(int centerShift, int radius)
{
   for(int i = 0; i <= radius; i++)
   {
      int shift = centerShift + i;
      if(shift >= Bars)
         break;

      double rsi = GetSMValue(0, shift);
      double lower = GetSMValue(3, shift);

      if(rsi != EMPTY_VALUE && lower != EMPTY_VALUE && rsi <= lower)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool HasSMUpperBandTouchNear(int centerShift, int radius)
{
   for(int i = 0; i <= radius; i++)
   {
      int shift = centerShift + i;
      if(shift >= Bars)
         break;

      double rsi = GetSMValue(0, shift);
      double upper = GetSMValue(2, shift);

      if(rsi != EMPTY_VALUE && upper != EMPTY_VALUE && rsi >= upper)
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
bool AllowBuySignal(int bar, const double &close[])
{
   if(!UseTrendSignalFilter)
      return(true);

   if(IsRangeMarket(bar))
      return(true);

   return(close[bar] >= TrendEmaValue(bar));
}

//+------------------------------------------------------------------+
bool AllowSellSignal(int bar, const double &close[])
{
   if(!UseTrendSignalFilter)
      return(true);

   if(IsRangeMarket(bar))
      return(true);

   return(close[bar] <= TrendEmaValue(bar));
}

//+------------------------------------------------------------------+
bool IsRangeMarket(int bar)
{
   double adx = iADX(NULL, 0, MathMax(1, AdxPeriod), PRICE_CLOSE, MODE_MAIN, bar);
   return(adx < AdxRangeLevel);
}

//+------------------------------------------------------------------+
double TrendEmaValue(int bar)
{
   return(iMA(NULL, 0, MathMax(1, EmaPeriod), 0, MODE_EMA, PRICE_CLOSE, bar));
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
bool IsSignificantSwingHigh(int bar,
                            const double &high[],
                            const double &low[],
                            const double &close[],
                            int strength,
                            int confirmBars)
{
   double value = HighLow ? high[bar] : close[bar];
   double lowestNearby = low[bar];

   for(int i = 1; i <= strength; i++)
      lowestNearby = MathMin(lowestNearby, low[bar + i]);

   for(int j = 1; j <= confirmBars; j++)
      lowestNearby = MathMin(lowestNearby, low[bar - j]);

   return((value - lowestNearby) >= RequiredSwingRange(bar));
}

//+------------------------------------------------------------------+
bool IsSignificantSwingLow(int bar,
                           const double &high[],
                           const double &low[],
                           const double &close[],
                           int strength,
                           int confirmBars)
{
   double value = HighLow ? low[bar] : close[bar];
   double highestNearby = high[bar];

   for(int i = 1; i <= strength; i++)
      highestNearby = MathMax(highestNearby, high[bar + i]);

   for(int j = 1; j <= confirmBars; j++)
      highestNearby = MathMax(highestNearby, high[bar - j]);

   return((highestNearby - value) >= RequiredSwingRange(bar));
}

//+------------------------------------------------------------------+
double RequiredSwingRange(int bar)
{
   double fixedRange = MathMax(0.0, MinSwingRangePips) * PipSize();
   double atrRange = 0.0;

   if(MinSwingAtrMultiplier > 0.0)
      atrRange = iATR(NULL, 0, MathMax(1, SwingAtrPeriod), bar) * MinSwingAtrMultiplier;

   return(MathMax(fixedRange, atrRange));
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
