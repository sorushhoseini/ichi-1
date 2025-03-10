//+------------------------------------------------------------------+
//|                     Custom Dual Ichimoku Indicator               |
//|                         Developed for MT5                        |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots 10

//--- First Ichimoku settings
input int Tenkan1 = 9;
input int Kijun1 = 26;
input int SenkouB1 = 52;

//--- Second Ichimoku settings
input int Tenkan2 = 36;
input int Kijun2 = 104;
input int SenkouB2 = 208;

//--- Options for Displaying Dynamic Trend per Component
input bool ShowTenkan1Trend = false;
input bool ShowKijun1Trend = false;
input bool ShowSpanA1Trend = false;
input bool ShowSpanB1Trend = false;
input bool ShowTenkan2Trend = false;
input bool ShowKijun2Trend = false;
input bool ShowSpanA2Trend = false;
input bool ShowSpanB2Trend = false;

//--- Cross strategy selection
enum CrossStrategy {
    KijunStrategy = 0,
    TenkanStrategy = 1,
    FalseStrategy = 2
};
input CrossStrategy CrossSelection = FalseStrategy;  // Default set to False

//--- Dynamic Cross Arrow Selection
enum DynamicCrossComponent {
    TenkanComponent = 0,
    KijunComponent = 1
};
input DynamicCrossComponent DynamicCrossSelection = TenkanComponent;  // Default set to Tenkan

//--- Slope comparison settings
enum SlopeComponents {
    T1_K1 = 0,
    T1_K1_SpA1 = 1,
    T1_K1_SpA1_SpB1 = 2,
    T1_K1_SpA1_SpA2 = 3
};
input SlopeComponents SlopeSelection = T1_K1;  // Default set to T1_K1
input double SlopeSimilarityThresholdMin = 0.001;  // حداقل آستانه شباهت
input double SlopeSimilarityThresholdMax = 0.01;  // حداکثر آستانه شباهت

//--- Buffers for Ichimoku
double SpanA1Buffer[];
double SpanB1Buffer[];
double SpanA2Buffer[];
double SpanB2Buffer[];
double Tenkan1Buffer[];
double Kijun1Buffer[];
double Tenkan2Buffer[];
double Kijun2Buffer[];
double CrossSignalBuffer[];
double SlopeAlertBuffer[];

//--- Colors
#property indicator_color1 Orange  // SpanA1
#property indicator_color2 Green   // SpanB1
#property indicator_color3 Blue    // SpanA2
#property indicator_color4 Magenta // SpanB2
#property indicator_color5 Red     // Tenkan1
#property indicator_color6 Blue    // Kijun1
#property indicator_color7 Yellow  // Tenkan2
#property indicator_color8 Orange  // Kijun2
#property indicator_color9 Lime    // Cross Signal
#property indicator_color10 Purple  // Slope Alert

//--- Variables for limit the number of candles after cross
int crossCandleCount = 0;
const int maxCandleAfterCross = 20;

//+------------------------------------------------------------------+
//| Utility Functions                                               |
//+------------------------------------------------------------------+
void DisplayComment(const string &commentText) {
    Comment(commentText);
}

string DetermineDirection(double current, double previous) {
    if (current > previous) return "Up";
    if (current < previous) return "Down";
    return "Flat";
}

double CalculateSlope(double current, double previous) {
    return (current - previous);
}

int GetPeriodForBufferIndex(int bufIndex) {
    switch (bufIndex) {
        case 4:
            return Tenkan1;
        case 5:
            return Kijun1;
        case 0:
            return MathMax(Tenkan1, Kijun1);
        case 1:
            return SenkouB1;
        case 6:
            return Tenkan2;
        case 7:
            return Kijun2;
        case 2:
            return MathMax(Tenkan2, Kijun2);
        case 3:
            return SenkouB2;
    }
    return 9;
}

bool IsDynamicTrend(double currentVal, double prevVal, int i, int period, const double &high[], const double &low[]) {
    string dir = DetermineDirection(currentVal, prevVal);
    if (dir == "Flat") return false;

    double dynamicLevel = GetIchimokuLevel(high, low, i - period, period);
    if (dynamicLevel == EMPTY_VALUE) return false;

    return (dir == "Up" && currentVal > dynamicLevel) || (dir == "Down" && currentVal < dynamicLevel);
}

bool IsDynamicCross(const double &high[], int i, int period, double currentVal) {
    double highest = high[i];
    for (int j = i - period + 1; j <= i; j++) {
        if (high[j] > highest) highest = high[j];
    }
    return currentVal > highest;
}

//+------------------------------------------------------------------+
//| Initialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Comment("");
}

int OnInit() {
    IndicatorSetString(INDICATOR_SHORTNAME, "Ichimoku Slope Indicator");

    for (int i = 0; i < 10; i++) {
        PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_LINE);
    }

    SetIndexBuffer(0, SpanA1Buffer);
    SetIndexBuffer(1, SpanB1Buffer);
    SetIndexBuffer(2, SpanA2Buffer);
    SetIndexBuffer(3, SpanB2Buffer);
    SetIndexBuffer(4, Tenkan1Buffer);
    SetIndexBuffer(5, Kijun1Buffer);
    SetIndexBuffer(6, Tenkan2Buffer);
    SetIndexBuffer(7, Kijun2Buffer);
    SetIndexBuffer(8, CrossSignalBuffer);
    SetIndexBuffer(9, SlopeAlertBuffer);

    PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(8, PLOT_ARROW, 233);
    PlotIndexSetInteger(9, PLOT_DRAW_TYPE, DRAW_LINE);

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Ichimoku Calculation Functions                                  |
//+------------------------------------------------------------------+
double GetIchimokuLevel(const double &high[], const double &low[], int index, int period) {
    if (index < period) return EMPTY_VALUE;
    double highest = high[index], lowest = low[index];
    for (int i = index - period + 1; i <= index; i++) {
        if (high[i] > highest) highest = high[i];
        if (low[i] < lowest) lowest = low[i];
    }
    return (highest + lowest) / 2.0;
}

void CalculateIchimokuLevels(const double &high[], const double &low[], int rates_total) {
    for (int i = 0; i < rates_total; i++) {
        Tenkan1Buffer[i] = GetIchimokuLevel(high, low, i, Tenkan1);
        Kijun1Buffer[i] = GetIchimokuLevel(high, low, i, Kijun1);
        SpanA1Buffer[i] = (Tenkan1Buffer[i] + Kijun1Buffer[i]) / 2.0;
        SpanB1Buffer[i] = GetIchimokuLevel(high, low, i, SenkouB1);

        Tenkan2Buffer[i] = GetIchimokuLevel(high, low, i, Tenkan2);
        Kijun2Buffer[i] = GetIchimokuLevel(high, low, i, Kijun2);
        SpanA2Buffer[i] = (Tenkan2Buffer[i] + Kijun2Buffer[i]) / 2.0;
        SpanB2Buffer[i] = GetIchimokuLevel(high, low, i, SenkouB2);
    }
}

//+------------------------------------------------------------------+
//| Check if there's a cross between Tenkan1 & Kijun1                |
//+------------------------------------------------------------------+
bool IsCrossed(int i) {
    if (i < 1) return false;
    bool crossUp = (Tenkan1Buffer[i] > Kijun1Buffer[i] && Tenkan1Buffer[i - 1] <= Kijun1Buffer[i - 1]);
    bool crossDown = (Tenkan1Buffer[i] < Kijun1Buffer[i] && Tenkan1Buffer[i - 1] >= Kijun1Buffer[i - 1]);
    return (crossUp || crossDown);
}

//+------------------------------------------------------------------+
//| Main Calculation Function                                       |
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
                const int &spread[]) {
    if (rates_total < 312) return prev_calculated;

    CalculateIchimokuLevels(high, low, rates_total);

    if (rates_total < 2) return prev_calculated;

    int i = rates_total - 1;
    string lines[8];
    for (int bufIndex = 0; bufIndex < 8; bufIndex++) {
        double currVal = 0.0, prevVal = 0.0;
        switch (bufIndex) {
            case 0:
                currVal = SpanA1Buffer[i];
                prevVal = SpanA1Buffer[i - 1];
                break;
            case 1:
                currVal = SpanB1Buffer[i];
                prevVal = SpanB1Buffer[i - 1];
                break;
            case 2:
                currVal = SpanA2Buffer[i];
                prevVal = SpanA2Buffer[i - 1];
                break;
            case 3:
                currVal = SpanB2Buffer[i];
                prevVal = SpanB2Buffer[i - 1];
                break;
            case 4:
                currVal = Tenkan1Buffer[i];
                prevVal = Tenkan1Buffer[i - 1];
                break;
            case 5:
                currVal = Kijun1Buffer[i];
                prevVal = Kijun1Buffer[i - 1];
                break;
            case 6:
                currVal = Tenkan2Buffer[i];
                prevVal = Tenkan2Buffer[i - 1];
                break;
            case 7:
                currVal = Kijun2Buffer[i];
                prevVal = Kijun2Buffer[i - 1];
                break;
        }

        string name = "";
        switch (bufIndex) {
            case 0:
                name = "SpanA1";
                break;
            case 1:
                name = "SpanB1";
                break;
            case 2:
                name = "SpanA2";
                break;
            case 3:
                name = "SpanB2";
                break;
            case 4:
                name = "Tenkan1";
                break;
            case 5:
                name = "Kijun1";
                break;
            case 6:
                name = "Tenkan2";
                break;
            case 7:
                name = "Kijun2";
                break;
        }

        string dir = DetermineDirection(currVal, prevVal);
        int periodForThis = GetPeriodForBufferIndex(bufIndex);
        bool isDyn = IsDynamicTrend(currVal, prevVal, i, periodForThis, high, low);

        lines[bufIndex] = name + ": " + dir;
        if (dir != "Flat" && isDyn)
            lines[bufIndex] += " (Dynamic Trend)";
    }
    string mission1Report = "";
    for (int idx = 0; idx < 8; idx++) {
        mission1Report += lines[idx] + "\n";
    }

    string mission2Report = "";
    bool foundCross = IsCrossed(i);
    if (foundCross) {
        if (CrossSelection == FalseStrategy) {
            mission2Report = "Cross occurred but CrossSelection=False => No action.";
            CrossSignalBuffer[i] = EMPTY_VALUE;
            Print("Cross occurred at index: ", i, " but CrossSelection is False");
        } else {
            double currVal, prevVal;
            int period;
            bool isDynCross = false;
            if (DynamicCrossSelection == TenkanComponent) {
                currVal = Tenkan1Buffer[i];
                prevVal = Tenkan1Buffer[i - 1];
                period = 8;
                isDynCross = IsDynamicCross(high, i, period, currVal);
                Print("Tenkan1 Dynamic Cross: ", isDynCross, " at index: ", i);
            } else {
                currVal = Kijun1Buffer[i];
                prevVal = Kijun1Buffer[i - 1];
                period = 25;
                isDynCross = IsDynamicCross(high, i, period, currVal);
                Print("Kijun1 Dynamic Cross: ", isDynCross, " at index: ", i);
            }
            if (isDynCross && crossCandleCount < maxCandleAfterCross) {
                crossCandleCount++;
                mission2Report = "Cross + " + (DynamicCrossSelection == TenkanComponent ? "Tenkan1" : "Kijun1") + " Dynamic Cross => Arrow drawn.";
                Print("Cross + ", (DynamicCrossSelection == TenkanComponent ? "Tenkan1" : "Kijun1"), " Dynamic Cross Confirmed at index: ", i);
                CrossSignalBuffer[i] = low[i] - 10 * _Point;
            } else {
                mission2Report = "Cross occurred but " + (DynamicCrossSelection == TenkanComponent ? "Tenkan1" : "Kijun1") + " is NOT dynamic cross or count exceeded => No arrow.";
                Print("Cross occurred but NO ", (DynamicCrossSelection == TenkanComponent ? "Tenkan1" : "Kijun1"), " Dynamic Cross or count exceeded at index: ", i);
                CrossSignalBuffer[i] = EMPTY_VALUE;
                crossCandleCount = 0;  // Reset the counter
            }
        }
    } else {
        mission2Report = "No Cross in current bar.";
        CrossSignalBuffer[i] = EMPTY_VALUE;
        crossCandleCount = 0;  // Reset the counter
    }

    string mission3Report = "";
    double slopeT1 = CalculateSlope(Tenkan1Buffer[i], Tenkan1Buffer[i - 1]);
    double slopeK1 = CalculateSlope(Kijun1Buffer[i], Kijun1Buffer[i - 1]);
    double slopeSpA1 = CalculateSlope(SpanA1Buffer[i], SpanA1Buffer[i - 1]);
    double slopeSpB1 = CalculateSlope(SpanB1Buffer[i], SpanB1Buffer[i - 1]);
    double slopeSpA2 = CalculateSlope(SpanA2Buffer[i], SpanA2Buffer[i - 1]);

    bool similarSlopes = false;
    bool sameDirection = true;
    double slopeThreshold = MathMin(SlopeSimilarityThresholdMax, MathMax(SlopeSimilarityThresholdMin, SlopeSimilarityThresholdMin));
    switch (SlopeSelection) {
        case T1_K1:
            similarSlopes = (MathAbs(slopeT1 - slopeK1) <= slopeThreshold && DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0));
            sameDirection = (DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0));
            break;
        case T1_K1_SpA1:
            similarSlopes = (MathAbs(slopeT1 - slopeK1) <= slopeThreshold && MathAbs(slopeK1 - slopeSpA1) <= slopeThreshold && DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0) && DetermineDirection(slopeK1, 0) == DetermineDirection(slopeSpA1, 0));
            sameDirection = (DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0) && DetermineDirection(slopeK1, 0) == DetermineDirection(slopeSpA1, 0));
            break;
        case T1_K1_SpA1_SpB1:
            similarSlopes = (MathAbs(slopeT1 - slopeK1) <= slopeThreshold && MathAbs(slopeK1 - slopeSpA1) <= slopeThreshold && MathAbs(slopeSpA1 - slopeSpB1) <= slopeThreshold && DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0) && DetermineDirection(slopeK1, 0) == DetermineDirection(slopeSpA1, 0) && DetermineDirection(slopeSpA1, 0) == DetermineDirection(slopeSpB1, 0));
            sameDirection = (DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0) && DetermineDirection(slopeK1, 0) == DetermineDirection(slopeSpA1, 0) && DetermineDirection(slopeSpA1, 0) == DetermineDirection(slopeSpB1, 0));
            break;
        case T1_K1_SpA1_SpA2:
            similarSlopes = (MathAbs(slopeT1 - slopeK1) <= slopeThreshold && MathAbs(slopeK1 - slopeSpA1) <= slopeThreshold && MathAbs(slopeSpA1 - slopeSpA2) <= slopeThreshold && DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0) && DetermineDirection(slopeK1, 0) == DetermineDirection(slopeSpA1, 0) && DetermineDirection(slopeSpA1, 0) == DetermineDirection(slopeSpA2, 0));
            sameDirection = (DetermineDirection(slopeT1, 0) == DetermineDirection(slopeK1, 0) && DetermineDirection(slopeK1, 0) == DetermineDirection(slopeSpA1, 0) && DetermineDirection(slopeSpA1, 0) == DetermineDirection(slopeSpA2, 0));
            break;
    }

    if (similarSlopes && sameDirection) {
        SlopeAlertBuffer[i] = low[i] - 20 * _Point;
        mission3Report = "Slopes are similar and same direction => Alert drawn.";
        Print