//+------------------------------------------------------------------+
//|                                                          MAA.mq5 |
//|                                  © Forex Assistant, Alan Norberg |
//+------------------------------------------------------------------+
#property version "4.40"

//--- Входные параметры для торговли
input int    NumberOfTrades        = 1;      // На сколько частей делить сделку (1 = обычная сделка)
input double LotSize               = 0.01;   // ОБЩИЙ размер лота для сделки
input int    StopLossBufferPips    = 15; // Отступ для Стоп-Лосса от уровня в пипсах
input int    TakeProfitBufferPips  = 10; // Отступ для Тейк-Профита от уровня в пипсах
input int    MinBarsBetweenTrades = 4;       // Минимальное кол-во свечей между сделками
input int    MinProfitPips = 20; // Минимальная дистанция до TP в пипсах, чтобы сделка имела смысл
input int    TrailingStopPips      = 50;     // Дистанция трейлинг-стопа в пипсах (0 = выключен)
input double BreakoutTP_ATR_Multiplier = 3.0; // Множитель ATR для тейк-профита на пробое
input bool   EnableDebugLogs = false; // Включить подробное логирование? (сильно замедляет тесты)
input bool   AllowMultipleTrades = false; // Разрешить новую серию ордеров?

//--- Входные параметры для сигналов
input group "--- Пороги Сигналов ---"
input int long_score_threshold  = 80;     // Порог в % для сигнала LONG
input int short_score_threshold = 80;     // Порог в % для сигнала SHORT

//--- Входные параметры для фильтров
input group "--- Фильтры ---"
input int    ADX_TrendStrength     = 25;     // Минимальная сила тренда по ADX
input int    SR_ProximityPips      = 15;     // Зона приближения к уровням S/R в пипсах
input double VolumeMultiplier      = 2.0;    // Множитель для всплеска объема
input double MinATR_Value          = 0.00050;// Минимальное значение ATR для торговли

//--- Входные параметры для свечных паттернов
input group "--- Фильтры Свечных Паттернов ---";
input double PinBarMaxBodyRatio = 0.33; // Макс. размер тела относительно свечи (1/3)
input double PinBarMinWickRatio = 0.60; // Мин. размер главной тени относительно свечи
input double DojiMaxBodyRatio   = 0.15; // Макс. размер тела для Доджи (15% от свечи)
input int    DojiClusterBars    = 5;    // На скольких свечах ищем скопление
input int    DojiClusterMinCount= 3;    // Сколько минимум Доджи должно быть для скопления

//--- Прототипы функций ---
void UpdateDashboard(int long_score, int short_score, double long_prob, double short_prob);
void CheckD1Trend(int &long_score, int &short_score);
void CheckDeepRSI(int &long_score, int &short_score);
void CheckFractalDivergence(int &long_score, int &short_score);
void CheckDeepMACD(int &long_score, int &short_score);
void CheckEMACross(int &long_score, int &short_score);
void CheckSMACross(int &long_score, int &short_score);
void CheckWMATrend(int &long_score, int &short_score);
void CheckSmartBBands(int &long_score, int &short_score);
void CheckIchimoku(int &long_score, int &short_score);
void CheckVolumeSpikes(int &long_score, int &short_score);
void CheckADXCrossover(int &long_score, int &short_score);
void CheckSupportResistanceSignal(int &long_score, int &short_score);
void CheckStochastic(int &long_score, int &short_score);
void CheckBollingerSqueeze(int &long_score, int &short_score);
void CheckFibonacciRetracement(int &long_score, int &short_score);
void CheckVWAP(int &long_score, int &short_score);
void CheckVWRSI(int &long_score, int &short_score);
void CheckImbalance_Advanced(int &long_score, int &short_score);
void CheckPinBarSignal(int &long_score, int &short_score);
void CheckDojiClusterBreakout(int &long_score, int &short_score);
double CalculateVWRSI(int period);
bool IsVolatilitySufficient();
bool GetNearestSupportResistance(double &support_level, double &resistance_level);
bool IsTrendStrongADX();


//+------------------------------------------------------------------+
//| Стандартные функции советника                                    |
//+------------------------------------------------------------------+
int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason)
{
    ObjectDelete(0, "MegaAnalysis_Line1");
    ObjectDelete(0, "MegaAnalysis_Line2");
    ObjectDelete(0, "MegaAnalysis_Line3");
    ObjectDelete(0, "SR_Support_Line");
    ObjectDelete(0, "SR_Resistance_Line");
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Главная рабочая функция OnTick                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Проверка на новый бар ---
    static datetime prev_time = 0;
    static int barsSinceLastTrade = 999; // << ДОБАВЛЕНО: Наш счетчик. Начинаем с большого числа, чтобы разрешить первую сделку.
    
    datetime current_time = iTime(_Symbol, _Period, 0);
    if(prev_time == current_time)
    {
        return; 
    }
    prev_time = current_time;
    barsSinceLastTrade++; // << ДОБАВЛЕНО: Увеличиваем счетчик на каждой новой свече
    
    // --- Шаг 0: Инициализация ---
    int long_score = 0;
    int short_score = 0;

    //--- ШАГ 1: СБОР ВСЕХ СИГНАЛОВ ---
    CheckD1Trend(long_score, short_score);
    CheckDeepRSI(long_score, short_score);
    CheckFractalDivergence(long_score, short_score);
    CheckDeepMACD(long_score, short_score);
    CheckEMACross(long_score, short_score);
    CheckSMACross(long_score, short_score);
    CheckWMATrend(long_score, short_score);
    CheckSmartBBands(long_score, short_score);
    CheckIchimoku(long_score, short_score);
    CheckVolumeSpikes(long_score, short_score);
    CheckSupportResistanceSignal(long_score, short_score);
    CheckADXCrossover(long_score, short_score);
    CheckStochastic(long_score, short_score);
    CheckBollingerSqueeze(long_score, short_score);
    CheckFibonacciRetracement(long_score, short_score);
    CheckVWAP(long_score, short_score);
    CheckVWRSI(long_score, short_score);
    CheckPinBarSignal(long_score, short_score);
    CheckImbalance_Advanced(long_score, short_score);
    CheckDojiClusterBreakout(long_score, short_score);

   
    //--- ШАГ 2: ФИНАЛЬНЫЙ ПОДСЧЕТ И ТОРГОВЛЯ ---
    if(EnableDebugLogs) Print("--- ИТОГОВЫЙ ПОДСЧЕТ ---");
    int total_score = long_score + short_score;
    double long_probability = 0, short_probability = 0;
    
    if(total_score > 0)
    {
        long_probability = (double)long_score / total_score * 100;
        short_probability = (double)short_score / total_score * 100;
    }
    
    // Вызываем нашу функцию для отображения на панели
    UpdateDashboard(long_score, short_score, long_probability, short_probability);
    
    string print_report = StringFormat("Анализ %s (%s): Очки Long/Short: %d/%d. Вероятность Long: %.0f%%, Short: %.0f%%.",_Symbol,EnumToString(_Period),long_score,short_score,long_probability,short_probability);
    if(EnableDebugLogs) Print(print_report);

    // --- ТОРГОВЫЙ БЛОК ---
        if(barsSinceLastTrade < MinBarsBetweenTrades)
        {
            if(EnableDebugLogs) Print("Торговля пропущена: активен cooldown-период (%d < %d свечей).", barsSinceLastTrade, MinBarsBetweenTrades);
        }
        else if(!IsTrendStrongADX())
        {
            // Сообщение выводится из самой функции IsTrendStrongADX
        }
        else if(!IsVolatilitySufficient())
        {
            // Сообщение выводится из самой функции IsVolatilitySufficient
        }
        else if(AllowMultipleTrades == false && PositionSelect(_Symbol) == true)
        {
            if(EnableDebugLogs) Print("Торговое решение пропущено: позиция уже есть.");
            CheckTrailingStop(); // Если позиция есть, проверяем трейлинг-стоп
        }
        else // Если все предварительные фильтры пройдены и позиций нет, приступаем к основной логике
        {
            double support=0, resistance=0;
            if(GetNearestSupportResistance(support, resistance)) // Если уровни успешно найдены
            {
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                
                // --- НАЧАЛО ФИНАЛЬНОГО ТОРГОВОГО БЛОКА ---
            double support=0, resistance=0;
            if(GetNearestSupportResistance(support, resistance)) // Если уровни успешно найдены
            {
                // --- ЛОГИКА ДЛЯ СИГНАЛА НА ПОКУПКУ (LONG) ---
                if (long_probability >= long_score_threshold)
                {
                    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    double final_tp = resistance - (TakeProfitBufferPips * 10 * point);

                    if((final_tp - price) >= (MinProfitPips * 10 * point)) // Проверка на "пространство для маневра"
                    {
                        if(EnableDebugLogs) Print("Получен сигнал LONG. Открываем %d частичных ордера с каскадным тейк-профитом...", NumberOfTrades);
                        double partial_lot = NormalizeDouble(LotSize / NumberOfTrades, 2);
                        if(partial_lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)){ if(EnableDebugLogs) Print("Ошибка: Расчетный лот слишком мал."); return; }

                        double stop_loss = support - (StopLossBufferPips * 10 * point);
                        double total_profit_distance = final_tp - price;
                        double profit_step = total_profit_distance / NumberOfTrades; // Рассчитываем размер одной "ступеньки"

                        for(int i = 0; i < NumberOfTrades; i++)
                        {
                            MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
                            // Рассчитываем тейк-профит для каждой ступеньки
                            double take_profit = price + (profit_step * (i + 1));

                            r.action=TRADE_ACTION_DEAL; r.symbol=_Symbol; r.volume=partial_lot; r.type=ORDER_TYPE_BUY;
                            r.price=price; r.sl=stop_loss; r.tp=take_profit; r.magic=12345; r.comment="Long part "+(string)(i+1);
                            if(!OrderSend(r,res)) { if(EnableDebugLogs) Print("Ошибка BUY: %d", res.retcode); }
                            else { if(EnableDebugLogs) Print("BUY #%d отправлен с TP=%.5f", i+1, take_profit); barsSinceLastTrade = 0; }
                        }
                    }
                    else { if(EnableDebugLogs) Print("Long-сделка пропущена: недостаточно пространства до уровня сопротивления."); }
                }
                // --- ЛОГИКА ДЛЯ СИГНАЛА НА ПРОДАЖУ (SHORT) ---
                else if (short_probability >= short_score_threshold)
                {
                    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    double final_tp = support + (TakeProfitBufferPips * 10 * point);

                    if((price - final_tp) >= (MinProfitPips * 10 * point)) // Проверка на "пространство для маневра"
                    {
                        if(EnableDebugLogs) Print("Получен сигнал SHORT. Открываем %d частичных ордера с каскадным тейк-профитом...", NumberOfTrades);
                        double partial_lot = NormalizeDouble(LotSize / NumberOfTrades, 2);
                        if(partial_lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)){ if(EnableDebugLogs) Print("Ошибка: Расчетный лот слишком мал."); return; }
                        
                        double stop_loss = resistance + (StopLossBufferPips * 10 * point);
                        double total_profit_distance = price - final_tp;
                        double profit_step = total_profit_distance / NumberOfTrades; // Рассчитываем размер одной "ступеньки"

                        for(int i = 0; i < NumberOfTrades; i++)
                        {
                           MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
                           // Рассчитываем тейк-профит для каждой ступеньки
                           double take_profit = price - (profit_step * (i + 1));
                           
                           r.action=TRADE_ACTION_DEAL; r.symbol=_Symbol; r.volume=partial_lot; r.type=ORDER_TYPE_SELL;
                           r.price=price; r.sl=stop_loss; r.tp=take_profit; r.magic=12345; r.comment="Short by MAA";
                           if(!OrderSend(r,res)) { if(EnableDebugLogs) Print("Ошибка SELL: %d", res.retcode); }
                           else { if(EnableDebugLogs) Print("SELL #%d отправлен с TP=%.5f", i+1, take_profit); barsSinceLastTrade = 0; }
                        }
                    }
                     else { if(EnableDebugLogs) Print("Short-сделка пропущена: недостаточно пространства до уровня поддержки."); }
                }
            }
        }
     }       
        
   
}

//+------------------------------------------------------------------+
//|                                                                  |
//|         ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ АНАЛИЗА                      |
//|                                                                  |
//+------------------------------------------------------------------+

// --- Функция для D1 Тренда ---
void CheckD1Trend(int &long_score, int &short_score)
{
    int ema_d1_handle = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_d1_handle != INVALID_HANDLE) 
    {
        double ema_d1_buffer[]; ArraySetAsSeries(ema_d1_buffer, true);
        MqlRates rates_d1[]; ArraySetAsSeries(rates_d1, true);
        if(CopyRates(_Symbol, PERIOD_D1, 1, 1, rates_d1) > 0 && CopyBuffer(ema_d1_handle, 0, 1, 1, ema_d1_buffer) > 0) 
        {
            if(rates_d1[0].close > ema_d1_buffer[0]) 
            {
                long_score += 3;
                if(EnableDebugLogs) Print("D1 Trend - Long (+3 очка)");
            }
            else 
            {
                short_score += 3;
                if(EnableDebugLogs) Print("D1 Trend - Short (+3 очка)");
            }
        }
        IndicatorRelease(ema_d1_handle);
    }
}

// --- Функция углубленного анализа RSI ---
void CheckDeepRSI(int &long_score, int &short_score)
{
    int rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    if(rsi_handle != INVALID_HANDLE)
    {
        int data_to_copy = 3;
        double rsi_buffer[];
        ArraySetAsSeries(rsi_buffer, true);
        
        if(CopyBuffer(rsi_handle, 0, 0, data_to_copy, rsi_buffer) > 0)
        {
            double rsi_current = rsi_buffer[1];
            double rsi_prev = rsi_buffer[2];

            // --- 1. Анализ "Возврата из зоны" (+2 очка) ---
            if(rsi_prev < 30 && rsi_current >= 30) 
            {
                long_score += 2; 
                if(EnableDebugLogs) Print("RSI Exit - Long (+2 очка)"); // << ИЗМЕНЕНИЕ
            }
            if(rsi_prev > 70 && rsi_current <= 70) 
            {
                short_score += 2; 
                if(EnableDebugLogs) Print("RSI Exit - Short (+2 очка)"); // << ИЗМЕНЕНИЕ
            }
            
            // --- 2. Анализ "Зоны импульса" (+1 очко) ---
            if(rsi_current > 50) 
            {
                long_score++;
                if(EnableDebugLogs) Print("RSI Zone - Long (+1 очко)"); // << ИЗМЕНЕНИЕ
            }
            if(rsi_current < 50) 
            {
                short_score++;
                if(EnableDebugLogs) Print("RSI Zone - Short (+1 очко)"); // << ИЗМЕНЕНИЕ
            }
        }
        IndicatorRelease(rsi_handle);
    }
}

// --- Функция для поиска дивергенции RSI по фракталам  ---
void CheckFractalDivergence(int &long_score, int &short_score)
{
    int rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    int fractals_handle = iFractals(_Symbol, _Period);

    if(rsi_handle == INVALID_HANDLE || fractals_handle == INVALID_HANDLE)
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для RSI или Fractals.");
        return;
    }

    int history_bars = 100;
    double rsi_buffer[], fractals_up_buffer[], fractals_down_buffer[];
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(fractals_up_buffer, true);
    ArraySetAsSeries(fractals_down_buffer, true);

    if(CopyBuffer(rsi_handle, 0, 0, history_bars, rsi_buffer) < history_bars ||
       CopyBuffer(fractals_handle, 0, 0, history_bars, fractals_up_buffer) < history_bars ||
       CopyBuffer(fractals_handle, 1, 0, history_bars, fractals_down_buffer) < history_bars)
    {
        IndicatorRelease(rsi_handle);
        IndicatorRelease(fractals_handle);
        return;
    }

    // --- Поиск Медвежьей дивергенции (по пикам) ---
    int newest_peak_idx = -1, older_peak_idx = -1;
    for(int i = 3; i < history_bars; i++)
    {
        if(fractals_up_buffer[i] != EMPTY_VALUE)
        {
            if(newest_peak_idx == -1) { newest_peak_idx = i; }
            else { older_peak_idx = i; break; }
        }
    }

    if(newest_peak_idx > 0 && older_peak_idx > 0)
    {
        double price_new_peak = fractals_up_buffer[newest_peak_idx];
        double price_old_peak = fractals_up_buffer[older_peak_idx];
        double rsi_new_peak = rsi_buffer[newest_peak_idx];
        double rsi_old_peak = rsi_buffer[older_peak_idx];

        // Классическая медвежья дивергенция: цена делает более высокий максимум, а RSI - более низкий
        if(price_new_peak > price_old_peak && rsi_new_peak < rsi_old_peak)
        {
            short_score += 5;
            if(EnableDebugLogs) Print("Divergence - Long (+5 очков)");
        }
    }

    // --- Поиск Бычьей дивергенции (по впадинам) ---
    int newest_trough_idx = -1, older_trough_idx = -1;
    for(int i = 3; i < history_bars; i++)
    {
        if(fractals_down_buffer[i] != EMPTY_VALUE)
        {
            if(newest_trough_idx == -1) { newest_trough_idx = i; }
            else { older_trough_idx = i; break; }
        }
    }

    if(newest_trough_idx > 0 && older_trough_idx > 0)
    {
        double price_new_trough = fractals_down_buffer[newest_trough_idx];
        double price_old_trough = fractals_down_buffer[older_trough_idx];
        double rsi_new_trough = rsi_buffer[newest_trough_idx];
        double rsi_old_trough = rsi_buffer[older_trough_idx];
        
        // Классическая бычья дивергенция: цена делает более низкий минимум, а RSI - более высокий
        if(price_new_trough < price_old_trough && rsi_new_trough > rsi_old_trough)
        {
            long_score += 5;
            if(EnableDebugLogs) Print("Divergence - Short (+5 очков)");
        }
    }

    IndicatorRelease(rsi_handle);
    IndicatorRelease(fractals_handle);
}

// --- Функция углубленного анализа MACD  ---
void CheckDeepMACD(int &long_score, int &short_score)
{
    int macd_handle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
    if(macd_handle != INVALID_HANDLE)
    {
        // Готовим буферы только для главной и сигнальной линий
        double macd_main_buffer[], macd_signal_buffer[];
        int data_to_copy = 3; 
        ArraySetAsSeries(macd_main_buffer, true);
        ArraySetAsSeries(macd_signal_buffer, true);
        
        // Копируем данные только из существующих буферов 0 и 1
        if(CopyBuffer(macd_handle, 0, 0, data_to_copy, macd_main_buffer) > 0 &&
           CopyBuffer(macd_handle, 1, 0, data_to_copy, macd_signal_buffer) > 0)
        {
            // Извлекаем значения для свечей
            double main_current = macd_main_buffer[1];
            double main_prev = macd_main_buffer[2];
            double signal_current = macd_signal_buffer[1];
            double signal_prev = macd_signal_buffer[2];

            // --- Рассчитываем гистограмму вручную ---
            double hist_current = main_current - signal_current;
            double hist_prev = main_prev - signal_prev;

            // --- 1. Анализ ПЕРЕСЕЧЕНИЯ (+3 очка) ---
            if(main_prev <= signal_prev && main_current > signal_current)
            {
                long_score += 3;
                if(EnableDebugLogs) Print("MACD Crossover: Long (+3 очка)");
            }
            if(main_prev >= signal_prev && main_current < signal_current)
            {
                short_score += 3;
                if(EnableDebugLogs) Print("MACD Crossover: Short (+3 очка)");
            }
    
            // --- 2. Анализ СОСТОЯНИЯ (+1 очко) ---
            if(main_current > signal_current)
            {
                long_score++;
                if(EnableDebugLogs) Print("MACD State: Long (+1 очко)");
            }
            if(main_current < signal_current)
            {
                short_score++;
                if(EnableDebugLogs) Print("MACD State: Short (+1 очко)");
            }
    
            // --- 3. Анализ ИМПУЛЬСА ГИСТОГРАММЫ (+1 очко) ---
            if(hist_current > hist_prev)
            {
                long_score++;
                if(EnableDebugLogs) Print("MACD Histogram: Long (+1 очко)");
            }
            if(hist_current < hist_prev)
            {
                short_score++;
                if(EnableDebugLogs) Print("MACD Histogram: Short (+1 очко)");
            }
        }
        else
        {
            if(EnableDebugLogs) Print("MACD: Недостаточно данных для анализа на текущей свече.");
        }
        IndicatorRelease(macd_handle);
    }
    else
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для индикатора MACD.");
    }
}


// --- Функция для пересечения EMA(12,26) ---
void CheckEMACross(int &long_score, int &short_score)
{
    int ema12_handle = iMA(_Symbol, _Period, 12, 0, MODE_EMA, PRICE_CLOSE);
    int ema26_handle = iMA(_Symbol, _Period, 26, 0, MODE_EMA, PRICE_CLOSE);
    
    // Добавим проверку хэндлов для надежности
    if(ema12_handle != INVALID_HANDLE && ema26_handle != INVALID_HANDLE)
    {
        double ema12_buffer[], ema26_buffer[];
        ArraySetAsSeries(ema12_buffer, true);
        ArraySetAsSeries(ema26_buffer, true);
        
        if(CopyBuffer(ema12_handle, 0, 1, 1, ema12_buffer) > 0 && CopyBuffer(ema26_handle, 0, 1, 1, ema26_buffer) > 0)
        {
            double ema12 = ema12_buffer[0];
            double ema26 = ema26_buffer[0];
            
            // --- НОВАЯ ЛОГИКА ВЫВОДА В ЖУРНАЛ ---
            if (ema12 > ema26)
            {
                long_score += 2;
                if(EnableDebugLogs) Print("EMA Cross(12/26): Long (+2 очка)");
            }
            if (ema12 < ema26)
            {
                short_score += 2;
                if(EnableDebugLogs) Print("EMA Cross(12/26): Short (+2 очка)");
            }
        }
    }
    
    // Освобождаем оба хэндла в любом случае
    IndicatorRelease(ema12_handle);
    IndicatorRelease(ema26_handle);
}


// --- Функция для SMA(50,200) "Золотого креста" ---
void CheckSMACross(int &long_score, int &short_score)
{
    int sma50_handle = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
    int sma200_handle = iMA(_Symbol, _Period, 200, 0, MODE_SMA, PRICE_CLOSE);

    if(sma50_handle != INVALID_HANDLE && sma200_handle != INVALID_HANDLE)
    {
        double sma50_buffer[], sma200_buffer[];
        ArraySetAsSeries(sma50_buffer, true);
        ArraySetAsSeries(sma200_buffer, true);

        if(CopyBuffer(sma50_handle, 0, 1, 1, sma50_buffer) > 0 && CopyBuffer(sma200_handle, 0, 1, 1, sma200_buffer) > 0)
        {
            double sma50 = sma50_buffer[0];
            double sma200 = sma200_buffer[0];

            // --- НОВАЯ ЛОГИКА ВЫВОДА В ЖУРНАЛ ---
            if (sma50 > sma200)
            {
                long_score += 3;
                if(EnableDebugLogs) Print("SMA Cross(50/200): Золотой крест. Long (+3 очка)");
            }
            if (sma50 < sma200)
            {
                short_score += 3;
                if(EnableDebugLogs) Print("SMA Cross(50/200): Мертвый крест. Short (+3 очка)");
            }
        }
    }
    
    IndicatorRelease(sma50_handle);
    IndicatorRelease(sma200_handle);
}

// --- Функция для цены относительно WMA(200) ---
void CheckWMATrend(int &long_score, int &short_score)
{
    int wma200_handle = iMA(_Symbol, _Period, 200, 0, MODE_LWMA, PRICE_CLOSE);
    if(wma200_handle != INVALID_HANDLE) 
    {
        double wma200_buffer[]; 
        ArraySetAsSeries(wma200_buffer, true);
        MqlRates rates[]; 
        ArraySetAsSeries(rates, true);
        
        if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0 && CopyBuffer(wma200_handle, 0, 1, 1, wma200_buffer) > 0) 
        {
            double close_price = rates[0].close;
            double wma200 = wma200_buffer[0];
            
            // --- НОВАЯ ЛОГИКА ВЫВОДА В ЖУРНАЛ ---
            if (close_price > wma200)
            {
                long_score += 3;
                if(EnableDebugLogs) Print("WMA Trend(200): Цена выше линии. Long (+3 очка)");
            }
            else // Условие "меньше или равно"
            {
                short_score += 3;
                if(EnableDebugLogs) Print("WMA Trend(200): Цена ниже линии. Short (+3 очка)");
            }
        }
        IndicatorRelease(wma200_handle);
    }
}

// --- Функция для "умных" Полос Боллинджера ---
void CheckSmartBBands(int &long_score, int &short_score){
     int bb_handle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
      int sma200_handle_for_bb = iMA(_Symbol, _Period, 200, 0, MODE_SMA, PRICE_CLOSE); // Нам нужен хэндл на SMA 200 для определения тренда
      
      if(bb_handle != INVALID_HANDLE && sma200_handle_for_bb != INVALID_HANDLE)
      {
          double bb_upper_buffer[], bb_lower_buffer[];
          double sma200_buffer_for_bb[];
          MqlRates rates[];
          
          ArraySetAsSeries(bb_upper_buffer, true);
          ArraySetAsSeries(bb_lower_buffer, true);
          ArraySetAsSeries(sma200_buffer_for_bb, true);
          ArraySetAsSeries(rates, true);
          
          // Копируем все необходимые данные
          if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0 &&
             CopyBuffer(bb_handle, 1, 1, 1, bb_upper_buffer) > 0 &&      // Верхняя полоса
             CopyBuffer(bb_handle, 2, 1, 1, bb_lower_buffer) > 0 &&      // Нижняя полоса
             CopyBuffer(sma200_handle_for_bb, 0, 1, 1, sma200_buffer_for_bb) > 0) // Значение SMA 200
          {
              double price_close = rates[0].close;
              double bb_upper = bb_upper_buffer[0];
              double bb_lower = bb_lower_buffer[0];
              double sma200_value = sma200_buffer_for_bb[0];
      
              // --- ПРИМЕНЯЕМ НОВУЮ КОНТЕКСТНУЮ ЛОГИКУ ---
      
              // Сценарий 1: Глобальный тренд вверх
              if(price_close > sma200_value)
              {
                  // Ищем только покупки на откате к нижней границе
                  if(price_close <= bb_lower)
                  {
                      long_score += 3; // Сильный сигнал по тренду
                      if(EnableDebugLogs) Print("BBands: покупка на откате в восходящем тренде. Long (+3 очка)");
                  }
              }
              // Сценарий 2: Глобальный тренд вниз
              else if(price_close < sma200_value)
              {
                  // Ищем только продажи на отскоке к верхней границе
                  if(price_close >= bb_upper)
                  {
                      short_score += 3; // Сильный сигнал по тренду
                      if(EnableDebugLogs) Print("BBands: продажа на отскоке в нисходящем тренде. Short (+3 очка)");
                  }
              }
              // Если цена около SMA 200, мы ничего не делаем
          }
          
          IndicatorRelease(bb_handle);
          IndicatorRelease(sma200_handle_for_bb);
      }
      else
      {
          if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для Bollinger Bands или SMA 200.");
      }
}

// --- Функция для анализа Облака Ишимоку ---
void CheckIchimoku(int &long_score, int &short_score)
{
    int ichimoku_handle = iIchimoku(_Symbol, _Period, 9, 26, 52);
    if(ichimoku_handle != INVALID_HANDLE)
    {
        double tenkan_buffer[], kijun_buffer[], senkou_a_buffer[], senkou_b_buffer[], chikou_buffer[];
        ArraySetAsSeries(tenkan_buffer, true); ArraySetAsSeries(kijun_buffer, true);
        ArraySetAsSeries(senkou_a_buffer, true); ArraySetAsSeries(senkou_b_buffer, true);
        ArraySetAsSeries(chikou_buffer, true);
        
        // Копируем все необходимые данные
        if(CopyBuffer(ichimoku_handle, 0, 1, 1, tenkan_buffer) > 0 && 
           CopyBuffer(ichimoku_handle, 1, 1, 1, kijun_buffer) > 0 &&
           CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_a_buffer) > 0 && // Облако берем для текущей свечи
           CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_b_buffer) > 0 &&
           CopyBuffer(ichimoku_handle, 4, 26, 1, chikou_buffer) > 0)   // Chikou смещен на 26 баров
        {
            double tenkan_sen = tenkan_buffer[0];
            double kijun_sen = kijun_buffer[0];
            double senkou_span_a = senkou_a_buffer[0];
            double senkou_span_b = senkou_b_buffer[0];
            double chikou_span = chikou_buffer[0];
            
            MqlRates current_rates[];
            if(CopyRates(_Symbol, _Period, 0, 1, current_rates) > 0)
            {
                double current_price = current_rates[0].close;
                
                // 1. Цена vs Облако (+3 очка)
                if(current_price > senkou_span_a && current_price > senkou_span_b)
                {
                    long_score += 3;
                    if(EnableDebugLogs) Print("Ichimoku: Цена выше Облака Long (+3 очка)");
                }
                if(current_price < senkou_span_a && current_price < senkou_span_b)
                {
                    short_score += 3;
                    if(EnableDebugLogs) Print("Ichimoku: Цена ниже Облака Short (+3 очка)");
                }
            }

            // 2. Пересечение Tenkan/Kijun (+2 очка)
            if(tenkan_sen > kijun_sen)
            {
                long_score += 2;
                if(EnableDebugLogs) Print("Ichimoku: Tenkan > Kijun Long (+2 очка)");
            }
            if(tenkan_sen < kijun_sen)
            {
                short_score += 2;
                if(EnableDebugLogs) Print("Ichimoku: Tenkan < Kijun Short (+2 очка)");
            }
            
            // 3. Фильтр Chikou Span (+1 очко)
            MqlRates past_rates[];
            if(CopyRates(_Symbol, _Period, 26, 1, past_rates) > 0)
            {
                double past_price = past_rates[0].close;
                if(chikou_span > past_price)
                {
                    long_score++;
                    if(EnableDebugLogs) Print("Ichimoku: Chikou выше цены Long (+1 очко)");
                }
                if(chikou_span < past_price)
                {
                    short_score++;
                    if(EnableDebugLogs) Print("Ichimoku: Chikou ниже цены Short (+1 очко)");
                }
            }
        }
        IndicatorRelease(ichimoku_handle);
    }
    else 
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для индикатора Ichimoku.");
    }
}

// --- Функция анализа Сжатия и Прорыва Полос Боллинджера ---
void CheckBollingerSqueeze(int &long_score, int &short_score)
{
    // --- Получаем хэндлы на нужные нам индикаторы ---
    int bb_handle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
    int stddev_handle = iStdDev(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE); // StdDev с тем же периодом, что и BB

    if(bb_handle == INVALID_HANDLE || stddev_handle == INVALID_HANDLE)
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для BB или StdDev.");
        return;
    }

    // --- Готовим и копируем данные ---
    int history_bars_for_squeeze = 75; // Период для поиска самого сильного сжатия
    double bb_upper_buffer[], bb_lower_buffer[], stddev_buffer[];
    MqlRates rates[];
    
    ArraySetAsSeries(bb_upper_buffer, true);
    ArraySetAsSeries(bb_lower_buffer, true);
    ArraySetAsSeries(stddev_buffer, true);
    ArraySetAsSeries(rates, true);
    
    // Копируем данные за весь период поиска сжатия
    if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0 &&
       CopyBuffer(bb_handle, 1, 1, 1, bb_upper_buffer) > 0 &&
       CopyBuffer(bb_handle, 2, 1, 1, bb_lower_buffer) > 0 &&
       CopyBuffer(stddev_handle, 0, 1, history_bars_for_squeeze, stddev_buffer) > 0)
    {
        double price_close = rates[0].close;
        double bb_upper = bb_upper_buffer[0];
        double bb_lower = bb_lower_buffer[0];
        
        // --- 1. Определяем, есть ли сейчас "Сжатие" ---
        double current_stddev = stddev_buffer[0];
        double min_stddev = current_stddev;

        // Ищем минимальное значение StdDev за последние N баров
        for(int i = 1; i < history_bars_for_squeeze; i++)
        {
            if(stddev_buffer[i] < min_stddev)
            {
                min_stddev = stddev_buffer[i];
            }
        }
        
        // Считаем, что "сжатие" есть, если текущая волатильность очень близка к своему минимуму
        bool isSqueeze = (current_stddev <= min_stddev * 1.1);
        
        // --- 2. Если было сжатие, ищем прорыв ---
        if(isSqueeze)
        {
            // Прорыв вверх
            if(price_close > bb_upper)
            {
                long_score += 4; // Сильный сигнал на прорыв волатильности
                if(EnableDebugLogs) Print("BBands Squeeze: Обнаружен прорыв вверх из сжатия. Long (+4 очко)");
            }
            // Прорыв вниз
            if(price_close < bb_lower)
            {
                short_score += 4; // Сильный сигнал на прорыв волатильности
                if(EnableDebugLogs) Print("BBands Squeeze: Обнаружен прорыв вниз из сжатия. Short (+4 очко)");
            }
        }
    }
    
    IndicatorRelease(bb_handle);
    IndicatorRelease(stddev_handle);
}

// --- Функция-фильтр по волатильности ATR ---
bool IsVolatilitySufficient()
{
    int atr_handle = iATR(_Symbol, _Period, 14); // Стандартный период ATR - 14
    if(atr_handle != INVALID_HANDLE)
    {
        double atr_buffer[];
        ArraySetAsSeries(atr_buffer, true);
        
        // Копируем значение ATR с последней закрытой свечи
        if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
        {
            double current_atr = atr_buffer[0];
            IndicatorRelease(atr_handle);
            
            // Сравниваем текущий ATR с нашим пороговым значением
            if(current_atr < MinATR_Value)
            {
                if(EnableDebugLogs) Print("Фильтр ATR: Волатильность слишком низкая (%.5f < %.5f). Торговля запрещена.", current_atr, MinATR_Value);
                return false; // Волатильность недостаточна
            }
            else
            {
                return true; // Волатильность достаточна
            }
        }
        IndicatorRelease(atr_handle);
    }
    return false; // Если не удалось получить ATR, на всякий случай запрещаем торговлю
}

// --- Функция анализа Стохастического Осциллятора ---
void CheckStochastic(int &long_score, int &short_score)
{
    int stochastic_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

    if(stochastic_handle != INVALID_HANDLE)
    {
        double main_line_buffer[], signal_line_buffer[];
        int data_to_copy = 3; 
        ArraySetAsSeries(main_line_buffer, true);
        ArraySetAsSeries(signal_line_buffer, true);
        
        if(CopyBuffer(stochastic_handle, 0, 0, data_to_copy, main_line_buffer) > 0 &&
           CopyBuffer(stochastic_handle, 1, 0, data_to_copy, signal_line_buffer) > 0)
        {
            double main_current = main_line_buffer[1];
            double main_prev = main_line_buffer[2];
            double signal_current = signal_line_buffer[1];
            double signal_prev = signal_line_buffer[2];

            // --- ПРОВЕРКА СИГНАЛОВ ПЕРЕСЕЧЕНИЯ ---
            if(main_prev <= signal_prev && main_current > signal_current)
            {
                long_score++;
                if(EnableDebugLogs) Print("Stochastic Signal: Обнаружено бычье пересечение Long (+1 очко)");
                if(main_current < 20 && signal_current < 20)
                {
                    long_score += 3;
                    if(EnableDebugLogs) Print("Stochastic Signal: Пересечение в зоне перепроданности. Long (+3 очка)");
                }
            }
            else if(main_prev >= signal_prev && main_current < signal_current)
            {
                short_score++;
                if(EnableDebugLogs) Print("Stochastic Signal: Обнаружено медвежье пересечение Short (+1 очко)");
                if(main_current > 80 && signal_current > 80)
                {
                    short_score += 3;
                    if(EnableDebugLogs) Print("Stochastic Signal: Пересечение в зоне перекупленности. Short (+3 очка)");
                }
            }
        }
        else
        {
            if(EnableDebugLogs) Print("Stochastic: Недостаточно данных для анализа.");
        }
        IndicatorRelease(stochastic_handle);
    }
    else
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для индикатора Stochastic.");
    }
}

// --- Функция поиска всплесков объема ---
void CheckVolumeSpikes(int &long_score, int &short_score)
{
    // --- Готовим массивы для цен и объемов ---
    MqlRates rates[];
    long volumes[];
    int history_to_check = 21; // Проверяем за последние 20 баров + текущий
    
    // Копируем данные
    if(CopyRates(_Symbol, _Period, 0, history_to_check, rates) < history_to_check ||
       CopyTickVolume(_Symbol, _Period, 0, history_to_check, volumes) < history_to_check)
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось скопировать данные для анализа объема.");
        return;
    }
    
    // MQL5 копирует данные в обратном порядке, перевернем их для удобства
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volumes, true);
    
    // --- Рассчитываем средний объем за последние 20 баров ---
    long average_volume = 0;
    for(int i = 1; i < history_to_check; i++) // Начинаем с 1, чтобы не учитывать текущий, формирующийся бар
    {
        average_volume += volumes[i];
    }
    average_volume = average_volume / (history_to_check - 1);
    
    // --- Анализируем последнюю закрытую свечу (индекс 1) ---
    long last_bar_volume = volumes[1];
    
    // Проверяем, был ли всплеск объема
    if(last_bar_volume > average_volume * VolumeMultiplier)
    {
        // Если был всплеск, проверяем характер свечи
        double last_close = rates[1].close;
        double last_open = rates[1].open;
        double prev_close = rates[2].close;
        double prev_open = rates[2].open;
        
        // Бычье поглощение на всплеске объема
        if(last_close > last_open && last_close > prev_open && last_open < prev_close)
        {
            long_score += 3;
            if(EnableDebugLogs) Print("Volume Spike: Обнаружено бычье поглощение на всплеске объема. Long (+3 очка)");
        }
        
        // Медвежье поглощение на всплеске объема
        if(last_close < last_open && last_close < prev_open && last_open > prev_close)
        {
            short_score += 3;
            if(EnableDebugLogs) Print("Volume Spike: Обнаружено медвежье поглощение на всплеске объема. Short (+3 очка)");
        }
    }
}

// --- Функция анализа отката по Фибоначчи с помощью ZigZag ---
void CheckFibonacciRetracement(int &long_score, int &short_score)
{
    int zigzag_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", 12, 5, 3);
    if(zigzag_handle == INVALID_HANDLE) { if(EnableDebugLogs) Print("Fibo: Ошибка создания хэндла ZigZag."); return; }

    // Копируем данные ЗигЗага за последние 300 свечей
    int history_bars = 100;
    double zigzag_buffer[];
    ArraySetAsSeries(zigzag_buffer, true);
    if(CopyBuffer(zigzag_handle, 0, 0, history_bars, zigzag_buffer) < 3)
    {
        if(EnableDebugLogs) Print("Fibo: Недостаточно истории для анализа ZigZag.");
        IndicatorRelease(zigzag_handle);
        return;
    }
    
    // --- Ищем 3 последние, непустые точки ЗигЗага ---
    double points_price[3]; // Массив для хранения цен трех точек
    int    points_bar[3];   // Массив для хранения индексов баров трех точек
    int points_found = 0;
    
    for(int i = 3; i < history_bars; i++)
    {
        if(zigzag_buffer[i] != EMPTY_VALUE)
        {
            points_price[points_found] = zigzag_buffer[i];
            points_bar[points_found] = i;
            points_found++;
            if(points_found == 3) break; // Нашли три точки, выходим из цикла
        }
    }

    IndicatorRelease(zigzag_handle); 

    // --- Анализируем последнюю волну, только если нашли ровно 3 точки ---
    if(points_found == 3)
    {
        // Точки хранятся в обратном порядке: [0] - самая новая, [2] - самая старая
        double newest_point_price = points_price[0];
        double prev_point_price = points_price[1];
        double pre_prev_point_price = points_price[2];
        
        MqlRates current_rate[];
        if(CopyRates(_Symbol, _Period, 0, 1, current_rate) < 1) return;
        double current_price = current_rate[0].close;

        // --- Сценарий 1: Последняя волна была ВОСХОДЯЩЕЙ (предыдущая точка ниже последней) ---
        if(newest_point_price > prev_point_price)
        {
            double swing_high = newest_point_price;
            double swing_low = prev_point_price;
            double swing_range = swing_high - swing_low;
            if(swing_range == 0) return; // Защита от деления на ноль

            double fibo_61_8_level = swing_high - swing_range * 0.618;
            
            if(MathAbs(current_price - fibo_61_8_level) < (SR_ProximityPips * 10 * _Point))
            {
                long_score += 4;
                if(EnableDebugLogs) Print("Fibo Signal: Обнаружен откат к уровню поддержки 61.8%%! (+4 очка Long)");
            }
        }
        
        // --- Сценарий 2: Последняя волна была НИСХОДЯЩЕЙ (предыдущая точка выше последней) ---
        else if(newest_point_price < prev_point_price)
        {
            double swing_high = prev_point_price;
            double swing_low = newest_point_price;
            double swing_range = swing_high - swing_low;
            if(swing_range == 0) return;

            double fibo_61_8_level = swing_low + swing_range * 0.618;

            if(MathAbs(current_price - fibo_61_8_level) < (SR_ProximityPips * 10 * _Point))
            {
                short_score += 4;
                if(EnableDebugLogs) Print("Fibo Signal: Обнаружен откат к уровню сопротивления 61.8%%! (+4 очка Short)");
            }
        }
    }
}

// --- Функция анализа положения цены относительно VWAP ---
void CheckVWAP(int &long_score, int &short_score)
{
    string indicator_path = "Market\\Basic VWAP";
    
    int vwap_buffer_number = 0;

    int vwap_handle = iCustom(_Symbol, _Period, indicator_path);

    if(vwap_handle != INVALID_HANDLE)
    {
        double vwap_buffer[];
        ArraySetAsSeries(vwap_buffer, true);

        // Копируем значение VWAP с последней закрытой свечи
        if(CopyBuffer(vwap_handle, vwap_buffer_number, 1, 1, vwap_buffer) > 0)
        {
            double vwap_value = vwap_buffer[0];
            
            // Если VWAP рассчитан, продолжаем
            if(vwap_value > 0)
            {
                // Получаем текущую цену
                MqlRates rates[];
                if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0)
                {
                    double price_close = rates[0].close;

                    // --- Применяем логику: +2 очка за торговлю по правильную сторону от VWAP ---
                    if(price_close > vwap_value)
                    {
                        long_score += 2;
                        if(EnableDebugLogs) Print("VWAP: Цена выше VWAP. Long (+2 Очка)");
                    }
                    if(price_close < vwap_value)
                    {
                        short_score += 2;
                        if(EnableDebugLogs) Print("VWAP: Цена ниже VWAP. Short (+2 Очка)");
                    }
                }
            }
        }
        IndicatorRelease(vwap_handle);
    }
    else
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для индикатора VWAP. Проверьте имя в indicator_path.");
    }
}

// --- Функция для поиска уровней Поддержки и Сопротивления по фракталам ---
bool GetNearestSupportResistance(double &support_level, double &resistance_level)
{
    int history_bars = 75; // На скольких последних барах ищем уровни
    int fractals_handle = iFractals(_Symbol, _Period);
    if(fractals_handle == INVALID_HANDLE) return(false);

    double fractals_up_buffer[], fractals_down_buffer[];
    ArraySetAsSeries(fractals_up_buffer, true);
    ArraySetAsSeries(fractals_down_buffer, true);

    if(CopyBuffer(fractals_handle, 0, 0, history_bars, fractals_up_buffer) < 3 ||
       CopyBuffer(fractals_handle, 1, 0, history_bars, fractals_down_buffer) < 3)
    {
        IndicatorRelease(fractals_handle);
        return(false);
    }
    
    // Ищем самый высокий пик (сопротивление) и самую низкую впадину (поддержку)
    double highest_high = 0;
    double lowest_low = 999999; // Инициализируем очень большим значением

    for(int i = 3; i < history_bars; i++)
    {
        if(fractals_up_buffer[i] != EMPTY_VALUE && fractals_up_buffer[i] > highest_high)
        {
            highest_high = fractals_up_buffer[i];
        }
        if(fractals_down_buffer[i] != EMPTY_VALUE && fractals_down_buffer[i] < lowest_low)
        {
            lowest_low = fractals_down_buffer[i];
        }
    }

    IndicatorRelease(fractals_handle);

    // Если уровни найдены, возвращаем их и сообщаем об успехе
    if(highest_high > 0 && lowest_low < 999999)
    {
        resistance_level = highest_high;
        support_level = lowest_low;
        return(true);
    }
    
    return(false);
}

// --- Функция анализа сигнала от уровней поддержки и сопротивления ---
void CheckSupportResistanceSignal(int &long_score, int &short_score)
{
    // --- Ищем уровни с помощью фракталов ---
    int history_bars = 100;
    int fractals_handle = iFractals(_Symbol, _Period);
    if(fractals_handle == INVALID_HANDLE) return;

    double fractals_up_buffer[], fractals_down_buffer[];
    ArraySetAsSeries(fractals_up_buffer, true);
    ArraySetAsSeries(fractals_down_buffer, true);

    if(CopyBuffer(fractals_handle, 0, 0, history_bars, fractals_up_buffer) < 3 ||
       CopyBuffer(fractals_handle, 1, 0, history_bars, fractals_down_buffer) < 3)
    {
        IndicatorRelease(fractals_handle);
        return;
    }
    
    double resistance_level = 0;
    double support_level = 999999;

    for(int i = 3; i < history_bars; i++)
    {
        if(fractals_up_buffer[i] != EMPTY_VALUE && fractals_up_buffer[i] > resistance_level)
        {
            resistance_level = fractals_up_buffer[i];
        }
        if(fractals_down_buffer[i] != EMPTY_VALUE && fractals_down_buffer[i] < support_level)
        {
            support_level = fractals_down_buffer[i];
        }
    }

    IndicatorRelease(fractals_handle);

    // --- Если уровни найдены, применяем логику И РИСУЕМ ИХ ---
    if(resistance_level > 0 && support_level < 999999)
    {
        // ++++++++++ НОВЫЙ БЛОК: ВИЗУАЛИЗАЦИЯ УРОВНЕЙ ++++++++++
        // Рисуем линию поддержки
        if(ObjectFind(0,"SR_Support_Line")!=0) ObjectCreate(0,"SR_Support_Line",OBJ_HLINE,0,0,0);
        ObjectSetDouble(0,"SR_Support_Line",OBJPROP_PRICE,support_level);
        ObjectSetInteger(0,"SR_Support_Line",OBJPROP_COLOR,clrLimeGreen);
        ObjectSetInteger(0,"SR_Support_Line",OBJPROP_STYLE,STYLE_DOT);
        ObjectSetInteger(0,"SR_Support_Line",OBJPROP_WIDTH,2);

        // Рисуем линию сопротивления
        if(ObjectFind(0,"SR_Resistance_Line")!=0) ObjectCreate(0,"SR_Resistance_Line",OBJ_HLINE,0,0,0);
        ObjectSetDouble(0,"SR_Resistance_Line",OBJPROP_PRICE,resistance_level);
        ObjectSetInteger(0,"SR_Resistance_Line",OBJPROP_COLOR,clrRed);
        ObjectSetInteger(0,"SR_Resistance_Line",OBJPROP_STYLE,STYLE_DOT);
        ObjectSetInteger(0,"SR_Resistance_Line",OBJPROP_WIDTH,2);
        // +++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MqlRates rates[];
        if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0)
        {
            double price_low = rates[0].low;
            double price_high = rates[0].high;
            double proximity_zone = SR_ProximityPips * 10 * _Point;

            // Проверяем близость к уровню поддержки
            if(MathAbs(price_low - support_level) <= proximity_zone)
            {
                long_score += 3;
                if(EnableDebugLogs) Print("S/R Levels: Цена у уровня поддержки (+3 очка)");
            }

            // Проверяем близость к уровню сопротивления
            if(MathAbs(price_high - resistance_level) <= proximity_zone)
            {
                short_score += 3;
                if(EnableDebugLogs) Print("S/R Levels: Цена у уровня сопротивления (+3 очка)");
            }
        }
    }
}

// --- Функция анализа силы тренда ADX/DMI ---
void CheckADXCrossover(int &long_score, int &short_score)
{
    // --- Получаем хэндл на индикатор ADX со стандартным периодом 14 ---
    int adx_handle = iADX(_Symbol, _Period, 14);

    if(adx_handle != INVALID_HANDLE)
    {
        // Готовим буферы для всех трех линий
        double adx_main_buffer[], plus_di_buffer[], minus_di_buffer[];
        int data_to_copy = 3; 
        
        ArraySetAsSeries(adx_main_buffer, true);
        ArraySetAsSeries(plus_di_buffer, true);
        ArraySetAsSeries(minus_di_buffer, true);
        
        // Копируем данные
        if(CopyBuffer(adx_handle, 0, 0, data_to_copy, adx_main_buffer) > 0 &&      // Буфер 0: Главная линия ADX
           CopyBuffer(adx_handle, 1, 0, data_to_copy, plus_di_buffer) > 0 &&       // Буфер 1: Линия +DI
           CopyBuffer(adx_handle, 2, 0, data_to_copy, minus_di_buffer) > 0)      // Буфер 2: Линия -DI
        {
            // --- 1. Фильтр силы тренда ---
            double adx_current = adx_main_buffer[1]; // Значение ADX на последней закрытой свече

            if(adx_current >= ADX_TrendStrength) // Проверяем, есть ли вообще тренд
            {
                // --- 2. Если тренд есть, ищем пересечение ---
                double plus_di_current = plus_di_buffer[1];
                double plus_di_prev = plus_di_buffer[2];
                double minus_di_current = minus_di_buffer[1];
                double minus_di_prev = minus_di_buffer[2];

                // Бычье пересечение: +DI пересекает -DI снизу вверх
                if(plus_di_prev <= minus_di_prev && plus_di_current > minus_di_current)
                {
                    long_score += 2;
                    if(EnableDebugLogs) Print("ADX: Обнаружено бычье пересечение (+DI > -DI). Long (+2 Очка)");
                }
                
                // Медвежье пересечение: -DI пересекает +DI снизу вверх
                if(minus_di_prev <= plus_di_prev && minus_di_current > plus_di_current)
                {
                    short_score += 2;
                    if(EnableDebugLogs) Print("ADX: Обнаружено медвежье пересечение (-DI > +DI). Short (+2 Очка)");
                }
            }
            else
            {
                if(EnableDebugLogs) Print("ADX Фильтр: Тренд слишком слабый (%.2f < %d). Сигналы DMI игнорируются.", adx_current, ADX_TrendStrength);
            }
        }
        IndicatorRelease(adx_handle);
    }
    else
    {
        if(EnableDebugLogs) Print("Ошибка: не удалось создать хэндл для индикатора ADX.");
    }
}

// --- Функция-фильтр: проверяет, достаточно ли сильный тренд по ADX ---
bool IsTrendStrongADX()
{
    int adx_handle = iADX(_Symbol, _Period, 14);
    if(adx_handle == INVALID_HANDLE) return false; // Если ошибка, на всякий случай запрещаем торговлю

    double adx_buffer[];
    ArraySetAsSeries(adx_buffer, true);

    if(CopyBuffer(adx_handle, 0, 1, 1, adx_buffer) > 0)
    {
        IndicatorRelease(adx_handle);
        if(adx_buffer[0] >= ADX_TrendStrength)
        {
            return true; // Тренд сильный, торговля разрешена
        }
    }
    
    IndicatorRelease(adx_handle);
    if(EnableDebugLogs) Print("Торговля заблокирована фильтром ADX: на рынке нет сильного тренда.");
    return false; // Тренд слабый, торговля запрещена
}

// --- Функция для управления трейлинг-стопом ---
void CheckTrailingStop()
{
    // Если трейлинг-стоп выключен в настройках, ничего не делаем
    if(TrailingStopPips <= 0)
    {
        return;
    }

    // Получаем информацию по открытой позиции
    if(PositionSelect(_Symbol))
    {
        double current_sl = PositionGetDouble(POSITION_SL);
        double current_tp = PositionGetDouble(POSITION_TP);
        long   position_ticket = PositionGetInteger(POSITION_TICKET);
        long   position_magic = PositionGetInteger(POSITION_MAGIC);
        long   position_type = PositionGetInteger(POSITION_TYPE);
        
        // Убеждаемся, что работаем только с позицией нашего советника
        if(position_magic != 12345)
        {
            return;
        }

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double trailing_stop_distance = TrailingStopPips * 10 * point;
        
        // Логика для позиции на ПОКУПКУ (Long)
        if(position_type == POSITION_TYPE_BUY)
        {
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double new_stop_loss = current_price - trailing_stop_distance;

            // Передвигаем стоп, только если он выше текущего
            if(new_stop_loss > current_sl || current_sl == 0)
            {
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_SLTP; // Модификация SL/TP
                request.position = position_ticket;
                request.sl = new_stop_loss;
                request.tp = current_tp; // Тейк-профит оставляем прежним
                
                if(!OrderSend(request, result))
                {
                    if(EnableDebugLogs) Print("Ошибка модификации Trailing Stop (BUY): %d", result.retcode);
                }
                else
                {
                    if(EnableDebugLogs) Print("Trailing Stop (BUY) успешно передвинут на %.5f", new_stop_loss);
                }
            }
        }
        // Логика для позиции на ПРОДАЖУ (Short)
        else if(position_type == POSITION_TYPE_SELL)
        {
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double new_stop_loss = current_price + trailing_stop_distance;

            // Передвигаем стоп, только если он ниже текущего
            if(new_stop_loss < current_sl || current_sl == 0)
            {
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_SLTP;
                request.position = position_ticket;
                request.sl = new_stop_loss;
                request.tp = current_tp;
                
                if(!OrderSend(request, result))
                {
                    if(EnableDebugLogs) Print("Ошибка модификации Trailing Stop (SELL): %d", result.retcode);
                }
                else
                {
                    if(EnableDebugLogs) Print("Trailing Stop (SELL) успешно передвинут на %.5f", new_stop_loss);
                }
            }
        }
    }
}

// --- Функция-калькулятор для VW-RSI ---
double CalculateVWRSI(int period)
{
    // Запрашиваем цены и объемы за период + 1 бар для расчета изменений
    MqlRates rates[];
    long volumes[];
    if(CopyRates(_Symbol, _Period, 0, period + 1, rates) < period + 1 ||
       CopyTickVolume(_Symbol, _Period, 0, period + 1, volumes) < period + 1)
    {
        return -1.0; // Возвращаем -1 в случае ошибки
    }

    // Переворачиваем массивы для удобства
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volumes, true);
    
    double sum_gains_x_volume = 0;
    double sum_losses_x_volume = 0;

    // Считаем взвешенные по объему приросты и потери
    for(int i = 1; i <= period; i++) // Начинаем с 1, так как нам нужно изменение относительно i-1
    {
        double change = rates[i].close - rates[i-1].close;
        long volume = volumes[i];
        
        if(change > 0) // Если цена выросла
        {
            sum_gains_x_volume += change * volume;
        }
        else // Если цена упала
        {
            sum_losses_x_volume += MathAbs(change) * volume;
        }
    }
    
    // Считаем средние значения
    double avg_gain_vol = sum_gains_x_volume / period;
    double avg_loss_vol = sum_losses_x_volume / period;
    
    // Рассчитываем VW-RS и сам VW-RSI
    if(avg_loss_vol == 0) return 100.0; // Защита от деления на ноль
    
    double vw_rs = avg_gain_vol / avg_loss_vol;
    double vw_rsi = 100.0 - (100.0 / (1.0 + vw_rs));
    
    return vw_rsi;
}


// --- Функция-анализатор для сигналов VW-RSI ---
void CheckVWRSI(int &long_score, int &short_score)
{
    // Получаем текущее и предыдущее значения нашего кастомного VW-RSI
    double vw_rsi_current = CalculateVWRSI(14);
    // Для предыдущего значения нужно будет реализовать более сложный расчет с хранением истории,
    // поэтому для простоты пока будем использовать только анализ зон.
    
    if(vw_rsi_current < 0) // Если калькулятор вернул ошибку
    {
        if(EnableDebugLogs) Print("VW-RSI: Не удалось рассчитать значение.");
        return;
    }
    
    // --- Анализ "Зоны импульса" (+1 очко) ---
    if(vw_rsi_current > 50)
    {
        long_score++;
        if(EnableDebugLogs) Print("VW-RSI: Бычья зона (>50) (+1 очко)");
    }
    if(vw_rsi_current < 50)
    {
        short_score++;
        if(EnableDebugLogs) Print("VW-RSI: Медвежья зона (<50) (+1 очко)");
    }
    
    // --- Анализ зон перекупленности/перепроданности (+2 очка) ---
    // В отличие от RSI, здесь мы даем очки за само нахождение в зоне,
    // так как это уже подтверждено объемом
    if(vw_rsi_current < 30)
    {
        long_score += 2;
        if(EnableDebugLogs) Print("VW-RSI: В зоне перепроданности (<30) (+2 очка)");
    }
    if(vw_rsi_current > 70)
    {
        short_score += 2;
        if(EnableDebugLogs) Print("VW-RSI: В зоне перекупленности (>70) (+2 очка)");
    }
}

// --- Функция анализа свечного паттерна "Пин-бар" у уровней S/R ---
void CheckPinBarSignal(int &long_score, int &short_score)
{
    // Получаем данные последней закрытой свечи
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, 1, rates) < 1) return;

    double candle_open = rates[0].open;
    double candle_high = rates[0].high;
    double candle_low = rates[0].low;
    double candle_close = rates[0].close;

    // Рассчитываем размеры свечи
    double total_range = candle_high - candle_low;
    double body_size = MathAbs(candle_close - candle_open);
    
    // Избегаем деления на ноль на дожи-свечах
    if(total_range == 0) return;

    double upper_wick = candle_high - MathMax(candle_open, candle_close);
    double lower_wick = MathMin(candle_open, candle_close) - candle_low;

    // --- Проверяем, является ли свеча Пин-баром ---
    bool is_bullish_pinbar = (body_size <= total_range * PinBarMaxBodyRatio) && (lower_wick >= total_range * PinBarMinWickRatio);
    bool is_bearish_pinbar = (body_size <= total_range * PinBarMaxBodyRatio) && (upper_wick >= total_range * PinBarMinWickRatio);
    
    // Если это один из видов пин-бара, то ищем подтверждение от уровней
    if(is_bullish_pinbar || is_bearish_pinbar)
    {
        double support=0, resistance=0;
        if(GetNearestSupportResistance(support, resistance))
        {
            double proximity_zone = SR_ProximityPips * 10 * _Point;

            // Если это бычий пин-бар и он находится у поддержки
            if(is_bullish_pinbar && MathAbs(candle_low - support) <= proximity_zone)
            {
                long_score += 4;
                if(EnableDebugLogs) Print("Candle Pattern: Обнаружен бычий Пин-бар у поддержки! (+4 очка)");
            }
            
            // Если это медвежий пин-бар и он находится у сопротивления
            if(is_bearish_pinbar && MathAbs(candle_high - resistance) <= proximity_zone)
            {
                short_score += 4;
                if(EnableDebugLogs) Print("Candle Pattern: Обнаружен медвежий Пин-бар у сопротивления! (+4 очка)");
            }
        }
    }
}


// --- Функция продвинутого анализа Имбаланса (Магнит + Тест) ---
void CheckImbalance_Advanced(int &long_score, int &short_score)
{
    MqlRates rates[];
    int history_bars = 50;
    if(CopyRates(_Symbol, _Period, 0, history_bars, rates) < history_bars) return;
    ArraySetAsSeries(rates, true);

    double current_price_low = rates[1].low;
    double current_price_high = rates[1].high;

    // Ищем в прошлое, пока не найдем первый же незаполненный имбаланс
    // Изменили "history_bars" на "history_bars - 1", чтобы i+1 не вышло за пределы
    for(int i = 3; i < history_bars - 1; i++)
    {
        // --- Поиск БЫЧЬЕГО имбаланса (ниже текущей цены) ---
        double bullish_fvg_top = rates[i+1].high;
        double bullish_fvg_bottom = rates[i-1].low;
        
        if(bullish_fvg_top < bullish_fvg_bottom)
        {
            if(bullish_fvg_bottom < current_price_low)
            {
                long_score += 2;
                if(EnableDebugLogs) Print("Imbalance Magnet: Найден бычий FVG ниже цены (+2 очка)");
                if(current_price_low <= bullish_fvg_bottom)
                {
                    long_score += 2;
                    if(EnableDebugLogs) Print("Imbalance: Цена тестирует бычий FVG! (еще +2 очка)");
                }
                break; 
            }
        }

        // --- Поиск МЕДВЕЖЬЕГО имбаланса (выше текущей цены) ---
        double bearish_fvg_bottom = rates[i+1].low;
        double bearish_fvg_top = rates[i-1].high;
        
        if(bearish_fvg_bottom > bearish_fvg_top)
        {
            if(bearish_fvg_top > current_price_high)
            {
                short_score += 2;
                if(EnableDebugLogs) Print("Imbalance Magnet: Найден медвежий FVG выше цены (+2 очка)");
                if(current_price_high >= bearish_fvg_top)
                {
                    short_score += 2;
                    if(EnableDebugLogs) Print("Imbalance: Цена тестирует медвежий FVG! (еще +2 очка)");
                }
                break;
            }
        }
    }
}

// --- Функция анализа прорыва из скопления Доджи (ИСПРАВЛЕННАЯ ВЕРСИЯ) ---
void CheckDojiClusterBreakout(int &long_score, int &short_score)
{
    // Запрашиваем на 1 бар больше, чем глубина поиска, для проверки пробоя
    int bars_to_check_for_breakout = 1;
    int bars_to_copy = DojiClusterBars + bars_to_check_for_breakout + 1; // +1 для запаса
    
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, bars_to_copy, rates) < bars_to_copy) return;
    ArraySetAsSeries(rates, true);

    // --- 1. Ищем скопление Доджи на барах, ПРЕДШЕСТВУЮЩИХ последнему закрытому ---
    int doji_count = 0;
    double cluster_high = 0;
    double cluster_low = 999999;

    for(int i = 1 + bars_to_check_for_breakout; i <= DojiClusterBars + bars_to_check_for_breakout; i++)
    {
        double range = rates[i].high - rates[i].low;
        double body = MathAbs(rates[i].open - rates[i].close);

        if(range > 0 && body <= range * DojiMaxBodyRatio)
        {
            doji_count++;
        }
        
        if(rates[i].high > cluster_high) cluster_high = rates[i].high;
        if(rates[i].low < cluster_low) cluster_low = rates[i].low;
    }

    // --- 2. Если скопление найдено, проверяем ПОСЛЕДНЮЮ ЗАКРЫТУЮ СВЕЧУ (индекс 1) на пробой ---
    if(doji_count >= DojiClusterMinCount)
    {
        // Используем PrintFormat для правильного отображения чисел
        if(EnableDebugLogs) PrintFormat("Doji Cluster: Обнаружено скопление Доджи в диапазоне [%.5f - %.5f]", cluster_low, cluster_high);
        
        double breakout_candle_close = rates[1].close;

        // Проверяем пробой вверх
        if(breakout_candle_close > cluster_high)
        {
            long_score += 4;
            if(EnableDebugLogs) Print("Doji Cluster: Пробой вверх из скопления! (+4 очка)");
        }
        
        // Проверяем пробой вниз
        if(breakout_candle_close < cluster_low)
        {
            short_score += 4;
            if(EnableDebugLogs) Print("Doji Cluster: Пробой вниз из скопления! (+4 очка)");
        }
    }
}

// --- Функция для обновления панели на графике ---
void UpdateDashboard(int long_score, int short_score, double long_prob, double short_prob){
    string label_name1 = "MegaAnalysis_Line1";
    string label_name2 = "MegaAnalysis_Line2";
    string label_name3 = "MegaAnalysis_Line3";

    string text1 = StringFormat("Баллы Long/Short: %d / %d", long_score, short_score);
    string text2 = StringFormat("Вероятность Long: %.0f%%", long_prob);
    string text3 = StringFormat("Вероятность Short: %.0f%%", short_prob);

    // --- Обновляем ЛЕЙБЛ 1 (Баллы) ---
    ObjectDelete(0, label_name1);
    if(ObjectCreate(0, label_name1, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, label_name1, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, label_name1, OBJPROP_XDISTANCE, 16);
        ObjectSetInteger(0, label_name1, OBJPROP_YDISTANCE, 80);
        ObjectSetString(0, label_name1, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, label_name1, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, label_name1, OBJPROP_COLOR, clrSilver);
        ObjectSetString(0, label_name1, OBJPROP_TEXT, text1);
    }
    
    // --- Обновляем ЛЕЙБЛ 2 (Вероятность Long) ---
    ObjectDelete(0, label_name2);
    if(ObjectCreate(0, label_name2, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, label_name2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, label_name2, OBJPROP_XDISTANCE, 16);
        ObjectSetInteger(0, label_name2, OBJPROP_YDISTANCE, 60);
        ObjectSetString(0, label_name2, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, label_name2, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, label_name2, OBJPROP_COLOR, clrSilver);
        ObjectSetString(0, label_name2, OBJPROP_TEXT, text2);
    }

    // --- Обновляем ЛЕЙБЛ 3 (Вероятность Short) ---
    ObjectDelete(0, label_name3);
    if(ObjectCreate(0, label_name3, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, label_name3, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, label_name3, OBJPROP_XDISTANCE, 16);
        ObjectSetInteger(0, label_name3, OBJPROP_YDISTANCE, 40);
        ObjectSetString(0, label_name3, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, label_name3, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, label_name3, OBJPROP_COLOR, clrSilver);
        ObjectSetString(0, label_name3, OBJPROP_TEXT, text3);
    }
    
    ChartRedraw();
}
