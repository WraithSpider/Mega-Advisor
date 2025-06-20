//+------------------------------------------------------------------+
//|                                                          MAA.mq5 |
//|                                  © Forex Assistant, Alan Norberg |
//+------------------------------------------------------------------+
#property version "4.22"

//--- Входные параметры для торговли
input int    NumberOfTrades        = 1;      // На сколько частей делить сделку (1 = обычная сделка)
input double FirstTargetRatio      = 0.5;    // Коэффициент для первого тейк-профита (0.5 = 50%)
input double LotSize               = 0.01;   // ОБЩИЙ размер лота для сделки
input int    StopLossBufferPips    = 15; // Отступ для Стоп-Лосса от уровня в пипсах
input int    TakeProfitBufferPips  = 10; // Отступ для Тейк-Профита от уровня в пипсах
input int MinBarsBetweenTrades = 4;       // Минимальное кол-во свечей между сделками

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
    
    //--- ШАГ 2: ФИНАЛЬНЫЙ ПОДСЧЕТ И ТОРГОВЛЯ ---
    Print("--- ИТОГОВЫЙ ПОДСЧЕТ ---");
    int total_score = long_score + short_score;
    if(total_score > 0)
    {
        double long_probability = (double)long_score / total_score * 100;
        double short_probability = (double)short_score / total_score * 100;
        UpdateDashboard(long_score, short_score, long_probability, short_probability);
        
        string print_report = StringFormat("Анализ %s (%s): Очки Long/Short: %d/%d. Вероятность Long: %.0f%%, Short: %.0f%%.",_Symbol,EnumToString(_Period),long_score,short_score,long_probability,short_probability);
        Print(print_report);

        // --- Проверяем все фильтры перед торговлей ---
        if(barsSinceLastTrade < MinBarsBetweenTrades)
        {
            Print("Торговля пропущена: активен cooldown-период (%d < %d свечей).", barsSinceLastTrade, MinBarsBetweenTrades);
        }
        else if(!IsVolatilitySufficient())
        {
            Print("Торговля пропущена: низкая волатильность (ATR).");
        }
        else if(PositionSelect(_Symbol) == true)
        {
            Print("Торговое решение пропущено: по символу %s уже есть открытая позиция.", _Symbol);
        }
        else // Если все фильтры пройдены, приступаем к торговле
        {
            double support=0, resistance=0;
            if(GetNearestSupportResistance(support, resistance)) // Если уровни успешно найдены
            {
                // --- Если сигнал на ПОКУПКУ (LONG) достаточно сильный ---
                if (long_probability >= long_score_threshold)
                {
                    double partial_lot = NormalizeDouble(LotSize / NumberOfTrades, 2);
                    if(partial_lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)){ Print("Ошибка: Расчетный лот слишком мал."); return; }

                    Print("Получен сигнал LONG. Открываем %d частичных ордера с динамическими целями...", NumberOfTrades);
                    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK), point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    
                    // Используем РАЗДЕЛЬНЫЕ отступы для SL и TP
                    double stop_loss = support - (StopLossBufferPips * 10 * point);
                    double final_tp = resistance - (TakeProfitBufferPips * 10 * point);
                    
                    for(int i = 0; i < NumberOfTrades; i++)
                    {
                        MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
                        double take_profit = (i == 0 && NumberOfTrades > 1) ? (price + (final_tp - price) * FirstTargetRatio) : final_tp;

                        r.action=TRADE_ACTION_DEAL; r.symbol=_Symbol; r.volume=partial_lot; r.type=ORDER_TYPE_BUY;
                        r.price=price; r.sl=stop_loss; r.tp=take_profit; r.magic=12345; r.comment="Long by MAA";
                        if(!OrderSend(r,res)) { Print("Ошибка BUY: %d", res.retcode); }
                        else { Print("BUY #%d отправлен.", i+1); barsSinceLastTrade = 0; } // Сбрасываем счетчик
                    }
                }
                // --- Если сигнал на ПРОДАЖУ (SHORT) достаточно сильный ---
                else if (short_probability >= short_score_threshold)
                {
                    double partial_lot = NormalizeDouble(LotSize / NumberOfTrades, 2);
                    if(partial_lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)){ Print("Ошибка: Расчетный лот слишком мал."); return; }

                    Print("Получен сигнал SHORT. Открываем %d частичных ордера с динамическими целями...", NumberOfTrades);
                    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID), point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                    // Используем РАЗДЕЛЬНЫЕ отступы для SL и TP
                    double stop_loss = resistance + (StopLossBufferPips * 10 * point);
                    double final_tp = support + (TakeProfitBufferPips * 10 * point);

                    for(int i = 0; i < NumberOfTrades; i++)
                    {
                       MqlTradeRequest r; MqlTradeResult res; ZeroMemory(r); ZeroMemory(res);
                       double take_profit = (i == 0 && NumberOfTrades > 1) ? (price - (price - final_tp) * FirstTargetRatio) : final_tp;
                       
                       r.action=TRADE_ACTION_DEAL; r.symbol=_Symbol; r.volume=partial_lot; r.type=ORDER_TYPE_SELL;
                       r.price=price; r.sl=stop_loss; r.tp=take_profit; r.magic=12345; r.comment="Short by MAA";
                       if(!OrderSend(r,res)) { Print("Ошибка SELL: %d", res.retcode); }
                       else { Print("SELL #%d отправлен.", i+1); barsSinceLastTrade = 0; } // Сбрасываем счетчик
                    }
                }
            }
        }
    }
    else { UpdateDashboard(0,0,0,0); }
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
                Print("D1 Trend - Long (+3 очка)");
            }
            else 
            {
                short_score += 3;
                Print("D1 Trend - Short (+3 очка)");
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
                Print("RSI Exit - Long (+2 очка)"); // << ИЗМЕНЕНИЕ
            }
            if(rsi_prev > 70 && rsi_current <= 70) 
            {
                short_score += 2; 
                Print("RSI Exit - Short (+2 очка)"); // << ИЗМЕНЕНИЕ
            }
            
            // --- 2. Анализ "Зоны импульса" (+1 очко) ---
            if(rsi_current > 50) 
            {
                long_score++;
                Print("RSI Zone - Long (+1 очко)"); // << ИЗМЕНЕНИЕ
            }
            if(rsi_current < 50) 
            {
                short_score++;
                Print("RSI Zone - Short (+1 очко)"); // << ИЗМЕНЕНИЕ
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
        Print("Ошибка: не удалось создать хэндл для RSI или Fractals.");
        return;
    }

    int history_bars = 300;
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

    int first_peak_bar = -1, second_peak_bar = -1;
    for(int i = 3; i < history_bars; i++)
    {
        if(fractals_up_buffer[i] != EMPTY_VALUE)
        {
            if(first_peak_bar == -1) first_peak_bar = i;
            else { second_peak_bar = i; break; }
        }
    }

    if(first_peak_bar != -1 && second_peak_bar != -1)
    {
        double price_peak1 = fractals_up_buffer[first_peak_bar];
        double price_peak2 = fractals_up_buffer[second_peak_bar];
        double rsi_peak1 = rsi_buffer[first_peak_bar];
        double rsi_peak2 = rsi_buffer[second_peak_bar];

        if(price_peak1 > price_peak2 && rsi_peak1 < rsi_peak2)
        {
            short_score += 5;
            Print("Медвежья дивергенция - Short (+5 очко)"); 
        }
    }

    int first_trough_bar = -1, second_trough_bar = -1;
    for(int i = 3; i < history_bars; i++)
    {
        if(fractals_down_buffer[i] != EMPTY_VALUE)
        {
            if(first_trough_bar == -1) first_trough_bar = i;
            else { second_trough_bar = i; break; }
        }
    }

    if(first_trough_bar != -1 && second_trough_bar != -1)
    {
        double price_trough1 = fractals_down_buffer[first_trough_bar];
        double price_trough2 = fractals_down_buffer[second_trough_bar];
        double rsi_trough1 = rsi_buffer[first_trough_bar];
        double rsi_trough2 = rsi_buffer[second_trough_bar];

        if(price_trough1 < price_trough2 && rsi_trough1 > rsi_trough2)
        {
            long_score += 5;
            Print("Бычья дивергенция - Long (+5 очко)");
        }
    }
    IndicatorRelease(rsi_handle);
    IndicatorRelease(fractals_handle);
}

// --- Функция углубленного анализа MACD (ДИАГНОСТИЧЕСКАЯ ВЕРСИЯ) ---
void CheckDeepMACD(int &long_score, int &short_score)
{
    Print("--- Запуск CheckDeepMACD ---"); // ТРАССЕР 1: Проверяем, что функция вообще вызывается

    int macd_handle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);

    if(macd_handle != INVALID_HANDLE)
    {
        Print("MACD: Хэндл успешно создан."); // ТРАССЕР 2: Проверяем создание хэндла

        double macd_main_buffer[], macd_signal_buffer[], macd_histogram_buffer[];
        int data_to_copy = 3; 
        ArraySetAsSeries(macd_main_buffer, true);
        ArraySetAsSeries(macd_signal_buffer, true);
        ArraySetAsSeries(macd_histogram_buffer, true);
        
        // Копируем данные в переменные, чтобы проверить результат
        int copied_main = CopyBuffer(macd_handle, 0, 0, data_to_copy, macd_main_buffer);
        int copied_signal = CopyBuffer(macd_handle, 1, 0, data_to_copy, macd_signal_buffer);
        int copied_hist = CopyBuffer(macd_handle, 2, 0, data_to_copy, macd_histogram_buffer);
        
        Print("MACD: Попытка копирования данных. Скопировано Main:%d, Signal:%d, Hist:%d", copied_main, copied_signal, copied_hist); // ТРАССЕР 3

        if(copied_main > 0 && copied_signal > 0 && copied_hist > 0)
        {
            Print("MACD: Вход в блок анализа сигналов."); // ТРАССЕР 4: Проверяем, что вошли в главный блок
            
            double main_current = macd_main_buffer[1];
            double main_prev = macd_main_buffer[2];
            double signal_current = macd_signal_buffer[1];
            double signal_prev = macd_signal_buffer[2];
            double hist_current = macd_histogram_buffer[1];
            double hist_prev = macd_histogram_buffer[2];

            if(main_prev <= signal_prev && main_current > signal_current) { long_score += 3; Print("MACD Crossover: Long (+3 очка)"); }
            if(main_prev >= signal_prev && main_current < signal_current) { short_score += 3; Print("MACD Crossover: Short (+3 очка)"); }
    
            if(main_current > signal_current) { long_score++; Print("MACD State: Long (+1 очко)"); }
            if(main_current < signal_current) { short_score++; Print("MACD State: Short (+1 очко)"); }
    
            if(hist_current > hist_prev) { long_score++; Print("MACD Histogram: Long (+1 очко)"); }
            if(hist_current < hist_prev) { short_score++; Print("MACD Histogram: Short (+1 очко)"); }
        }
        else
        {
            Print("MACD: Данных для анализа недостаточно."); // Это сообщение должно было появляться раньше
        }
        
        IndicatorRelease(macd_handle);
    }
    else
    {
        Print("MACD: КРИТИЧЕСКАЯ ОШИБКА! Не удалось создать хэндл для индикатора MACD.");
    }
}


// --- Функция для пересечения EMA(12,26) ---
void CheckEMACross(int &long_score, int &short_score){
    int ema12_handle = iMA(_Symbol, _Period, 12, 0, MODE_EMA, PRICE_CLOSE);
    int ema26_handle = iMA(_Symbol, _Period, 26, 0, MODE_EMA, PRICE_CLOSE);
    double ema12_buffer[], ema26_buffer[];
    ArraySetAsSeries(ema12_buffer, true);
    ArraySetAsSeries(ema26_buffer, true);
    if(CopyBuffer(ema12_handle, 0, 1, 1, ema12_buffer) > 0 && CopyBuffer(ema26_handle, 0, 1, 1, ema26_buffer) > 0)
    {
        double ema12 = ema12_buffer[0];
        double ema26 = ema26_buffer[0];
        if (ema12 > ema26) long_score += 2;
        if (ema12 < ema26) short_score += 2;
        Print("EMA(12/26) Cross(",EnumToString(_Period),"): состояние. Очки Long/Short: ",long_score,"/",short_score);
    }
    IndicatorRelease(ema12_handle);
    IndicatorRelease(ema26_handle);
}

// --- Функция для SMA(50,200) "Золотого креста" ---
void CheckSMACross(int &long_score, int &short_score){
    int sma50_handle = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
    int sma200_handle = iMA(_Symbol, _Period, 200, 0, MODE_SMA, PRICE_CLOSE);
    double sma50_buffer[], sma200_buffer[];
    ArraySetAsSeries(sma50_buffer, true);
    ArraySetAsSeries(sma200_buffer, true);
    if(CopyBuffer(sma50_handle, 0, 1, 1, sma50_buffer) > 0 && CopyBuffer(sma200_handle, 0, 1, 1, sma200_buffer) > 0)
    {
        double sma50 = sma50_buffer[0];
        double sma200 = sma200_buffer[0];
        if (sma50 > sma200) long_score += 3;
        if (sma50 < sma200) short_score += 3;
        Print("SMA(50/200) Cross(",EnumToString(_Period),"): состояние. Очки Long/Short: ",long_score,"/",short_score);
    }
    IndicatorRelease(sma50_handle);
    IndicatorRelease(sma200_handle);
}

// --- Функция для цены относительно WMA(200) ---
void CheckWMATrend(int &long_score, int &short_score){
    int wma200_handle = iMA(_Symbol, _Period, 200, 0, MODE_LWMA, PRICE_CLOSE);
    if(wma200_handle != INVALID_HANDLE) {
        double wma200_buffer[]; ArraySetAsSeries(wma200_buffer, true);
        MqlRates rates[]; ArraySetAsSeries(rates, true); // << ОБЪЯВЛЕНИЕ ПЕРЕМЕЩЕНО СЮДА
        if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0 && CopyBuffer(wma200_handle, 0, 1, 1, wma200_buffer) > 0) {
            if (rates[0].close > wma200_buffer[0]) long_score += 3; else short_score += 3;
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
                      Print("BBands(",EnumToString(_Period),"): покупка на откате в восходящем тренде. Очки Long +3");
                  }
              }
              // Сценарий 2: Глобальный тренд вниз
              else if(price_close < sma200_value)
              {
                  // Ищем только продажи на отскоке к верхней границе
                  if(price_close >= bb_upper)
                  {
                      short_score += 3; // Сильный сигнал по тренду
                      Print("BBands(",EnumToString(_Period),"): продажа на отскоке в нисходящем тренде. Очки Short +3");
                  }
              }
              // Если цена около SMA 200, мы ничего не делаем
          }
          
          IndicatorRelease(bb_handle);
          IndicatorRelease(sma200_handle_for_bb);
      }
      else
      {
          Print("Ошибка: не удалось создать хэндл для Bollinger Bands или SMA 200.");
      }
}

// --- Функция для анализа Облака Ишимоку ---
void CheckIchimoku(int &long_score, int &short_score){
    int ichimoku_handle = iIchimoku(_Symbol, _Period, 9, 26, 52);
    if(ichimoku_handle != INVALID_HANDLE)
    {
        double tenkan_buffer[], kijun_buffer[], senkou_a_buffer[], senkou_b_buffer[], chikou_buffer[];
        ArraySetAsSeries(tenkan_buffer, true); ArraySetAsSeries(kijun_buffer, true);
        ArraySetAsSeries(senkou_a_buffer, true); ArraySetAsSeries(senkou_b_buffer, true);
        ArraySetAsSeries(chikou_buffer, true);
        if(CopyBuffer(ichimoku_handle, 0, 1, 1, tenkan_buffer) > 0 && CopyBuffer(ichimoku_handle, 1, 1, 1, kijun_buffer) > 0 &&
           CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_a_buffer) > 0 && CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_b_buffer) > 0 &&
           CopyBuffer(ichimoku_handle, 4, 26, 1, chikou_buffer) > 0)
        {
            double tenkan_sen = tenkan_buffer[0]; double kijun_sen = kijun_buffer[0];
            double senkou_span_a = senkou_a_buffer[0]; double senkou_span_b = senkou_b_buffer[0];
            double chikou_span = chikou_buffer[0];
            MqlRates current_rates[]; CopyRates(_Symbol, _Period, 0, 1, current_rates);
            double current_price = current_rates[0].close;
            MqlRates past_rates[]; CopyRates(_Symbol, _Period, 26, 1, past_rates);
            double past_price = past_rates[0].close;
            if(current_price > senkou_span_a && current_price > senkou_span_b) long_score += 3;
            if(current_price < senkou_span_a && current_price < senkou_span_b) short_score += 3;
            if(tenkan_sen > kijun_sen) long_score += 2;
            if(tenkan_sen < kijun_sen) short_score += 2;
            if(chikou_span > past_price) long_score++;
            if(chikou_span < past_price) short_score++;
            Print("Ichimoku(",EnumToString(_Period),"): анализ завершен. Очки Long/Short: ",long_score,"/",short_score);
        }
        IndicatorRelease(ichimoku_handle);
    }
    else { Print("Ошибка: не удалось создать хэндл для индикатора Ichimoku."); }
}

   // --- Функция анализа Сжатия и Прорыва Полос Боллинджера ---
void CheckBollingerSqueeze(int &long_score, int &short_score)
{
    // --- Получаем хэндлы на нужные нам индикаторы ---
    int bb_handle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
    int stddev_handle = iStdDev(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE); // StdDev с тем же периодом, что и BB

    if(bb_handle == INVALID_HANDLE || stddev_handle == INVALID_HANDLE)
    {
        Print("Ошибка: не удалось создать хэндл для BB или StdDev.");
        return;
    }

    // --- Готовим и копируем данные ---
    int history_bars_for_squeeze = 120; // Период для поиска самого сильного сжатия
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
                Print("BBands Squeeze(",EnumToString(_Period),"): Обнаружен прорыв вверх из сжатия! Очки Long +4");
            }
            // Прорыв вниз
            if(price_close < bb_lower)
            {
                short_score += 4; // Сильный сигнал на прорыв волатильности
                Print("BBands Squeeze(",EnumToString(_Period),"): Обнаружен прорыв вниз из сжатия! Очки Short +4");
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
                   Print("Фильтр ATR: Волатильность слишком низкая (%.5f < %.5f). Торговля запрещена.", current_atr, MinATR_Value);
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
    // Стандартные параметры стохастика: %K=5, %D=3, Замедление=3
    int stochastic_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

    if(stochastic_handle != INVALID_HANDLE)
    {
        // Готовим буферы для главной и сигнальной линий
        double main_line_buffer[], signal_line_buffer[];
        int data_to_copy = 3; 
        
        ArraySetAsSeries(main_line_buffer, true);
        ArraySetAsSeries(signal_line_buffer, true);
        
        // Копируем данные из буферов
        if(CopyBuffer(stochastic_handle, 0, 0, data_to_copy, main_line_buffer) > 0 &&   // Буфер 0: Главная линия (%K)
           CopyBuffer(stochastic_handle, 1, 0, data_to_copy, signal_line_buffer) > 0)    // Буфер 1: Сигнальная линия (%D)
        {
            // Извлекаем значения для текущей закрытой свечи (индекс 1) и предыдущей (индекс 2)
            double main_current = main_line_buffer[1];
            double main_prev = main_line_buffer[2];
            double signal_current = signal_line_buffer[1];
            double signal_prev = signal_line_buffer[2];

            // --- ПРОВЕРКА СИГНАЛОВ ---

            // Бычье пересечение (быстрая выше медленной)
            if(main_prev <= signal_prev && main_current > signal_current)
            {
                // Сигнал №2: Обычное пересечение
                long_score++;
                Print("Stochastic(",EnumToString(_Period),"): Обнаружено обычное бычье пересечение. Очки Long +1");

                // Сигнал №1: Пересечение в зоне перепроданности
                if(main_current < 20 && signal_current < 20)
                {
                    long_score += 3;
                    Print("Stochastic(",EnumToString(_Period),"): Пересечение в зоне перепроданности! Очки Long +3");
                }
            }
            // Медвежье пересечение (быстрая ниже медленной)
            else if(main_prev >= signal_prev && main_current < signal_current)
            {
                // Сигнал №2: Обычное пересечение
                short_score++;
                Print("Stochastic(",EnumToString(_Period),"): Обнаружено обычное медвежье пересечение. Очки Short +1");
                
                // Сигнал №1: Пересечение в зоне перекупленности
                if(main_current > 80 && signal_current > 80)
                {
                    short_score += 3;
                    Print("Stochastic(",EnumToString(_Period),"): Пересечение в зоне перекупленности! Очки Short +3");
                }
            }
        }
        IndicatorRelease(stochastic_handle);
    }
    else
    {
        Print("Ошибка: не удалось создать хэндл для индикатора Stochastic.");
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
        Print("Ошибка: не удалось скопировать данные для анализа объема.");
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
            Print("Volume Spike: Обнаружено бычье поглощение на всплеске объема! Очки Long +3");
        }
        
        // Медвежье поглощение на всплеске объема
        if(last_close < last_open && last_close < prev_open && last_open > prev_close)
        {
            short_score += 3;
            Print("Volume Spike: Обнаружено медвежье поглощение на всплеске объема! Очки Short +3");
        }
    }
}

// --- Функция анализа отката по Фибоначчи с помощью ZigZag ---
void CheckFibonacciRetracement(int &long_score, int &short_score)
{
    // --- Получаем хэндл на индикатор ZigZag ---
    // Стандартные параметры ZigZag: ExtDepth=12, ExtDeviation=5, ExtBackstep=3
    int zigzag_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", 12, 5, 3);

    if(zigzag_handle == INVALID_HANDLE)
    {
        Print("Ошибка: не удалось создать хэндл для индикатора ZigZag.");
        return;
    }

    // --- Готовим буфер и копируем данные ЗигЗага ---
    double zigzag_buffer[];
    ArraySetAsSeries(zigzag_buffer, true);
    
    // Пытаемся скопировать 3 последних значения. Если их меньше, значит истории мало.
    if(CopyBuffer(zigzag_handle, 0, 0, 3, zigzag_buffer) < 3)
    {
        IndicatorRelease(zigzag_handle);
        return; 
    }
    
    // --- Ищем 3 последние, непустые точки ЗигЗага ---
    double last_point = 0, prev_point = 0, pre_prev_point = 0;
    int points_found = 0;
    for(int i = 0; i < 300; i++) // Ищем в последних 300 барах
    {
        if(CopyBuffer(zigzag_handle, 0, i, 1, zigzag_buffer) > 0 && zigzag_buffer[0] > 0)
        {
            if(points_found == 0) last_point = zigzag_buffer[0];
            if(points_found == 1) prev_point = zigzag_buffer[0];
            if(points_found == 2) { pre_prev_point = zigzag_buffer[0]; break; }
            points_found++;
        }
    }

    // --- Анализируем последнюю волну, если нашли 3 точки ---
    if(points_found == 2)
    {
        MqlRates current_rate[];
        CopyRates(_Symbol, _Period, 0, 1, current_rate);
        double current_price = current_rate[0].close;

        // --- Сценарий 1: Последняя волна была ВОСХОДЯЩЕЙ (prev -> last) ---
        if(last_point > prev_point && pre_prev_point < prev_point)
        {
            double swing_high = last_point;
            double swing_low = prev_point;
            double swing_range = swing_high - swing_low;
            double fibo_61_8_level = swing_high - swing_range * 0.618; // Уровень отката 61.8%

            // Проверяем, находится ли текущая цена около этого уровня поддержки
            if(MathAbs(current_price - fibo_61_8_level) < (_Point * 10)) // Погрешность в 10 пунктов
            {
                long_score += 4;
                Print("Fibonacci: Обнаружен откат к уровню поддержки 61.8%%. Очки Long +4");
            }
        }
        
        // --- Сценарий 2: Последняя волна была НИСХОДЯЩЕЙ (prev -> last) ---
        if(last_point < prev_point && pre_prev_point > prev_point)
        {
            double swing_high = prev_point;
            double swing_low = last_point;
            double swing_range = swing_high - swing_low;
            double fibo_61_8_level = swing_low + swing_range * 0.618; // Уровень отката 61.8%

            // Проверяем, находится ли текущая цена около этого уровня сопротивления
            if(MathAbs(current_price - fibo_61_8_level) < (_Point * 10)) // Погрешность в 10 пунктов
            {
                short_score += 4;
                Print("Fibonacci: Обнаружен откат к уровню сопротивления 61.8%%. Очки Short +4");
            }
        }
    }

    IndicatorRelease(zigzag_handle);
}

// --- Функция анализа положения цены относительно VWAP ---
void CheckVWAP(int &long_score, int &short_score)
{
    // Указываем имя файла вашего скачанного индикатора
    string indicator_path = "Market\\Basic VWAP";
    
    // Номер буфера, который мы определили по вашему скриншоту
    int vwap_buffer_number = 0;

    // ПРИМЕЧАНИЕ: Если у индикатора есть входные параметры (кроме цветов),
    // их нужно будет добавить в вызов iCustom через запятую после indicator_path.
    // Судя по названию "Basic VWAP", их скорее всего нет.
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
                        Print("VWAP: Цена выше VWAP. Очки Long +2");
                    }
                    if(price_close < vwap_value)
                    {
                        short_score += 2;
                        Print("VWAP: Цена ниже VWAP. Очки Short +2");
                    }
                }
            }
        }
        IndicatorRelease(vwap_handle);
    }
    else
    {
        Print("Ошибка: не удалось создать хэндл для индикатора VWAP. Проверьте имя в indicator_path.");
    }
}

// --- Функция для поиска уровней Поддержки и Сопротивления по фракталам ---
bool GetNearestSupportResistance(double &support_level, double &resistance_level)
{
    int history_bars = 100; // На скольких последних барах ищем уровни
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
    
    // Ищем самый высокий пик (сопротивление) и самую низкую впадину (поддержку)
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

    // --- Применяем логику начисления очков ---
    if(resistance_level > 0 && support_level < 999999)
    {
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
                Print("S/R Levels: Цена у уровня поддержки. Очки Long +3");
            }

            // Проверяем близость к уровню сопротивления
            if(MathAbs(price_high - resistance_level) <= proximity_zone)
            {
                short_score += 3;
                Print("S/R Levels: Цена у уровня сопротивления. Очки Short +3");
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
                    Print("ADX: Обнаружено бычье пересечение (+DI > -DI). Очки Long +2");
                }
                
                // Медвежье пересечение: -DI пересекает +DI снизу вверх
                if(minus_di_prev <= plus_di_prev && minus_di_current > plus_di_current)
                {
                    short_score += 2;
                    Print("ADX: Обнаружено медвежье пересечение (-DI > +DI). Очки Short +2");
                }
            }
            else
            {
                Print("ADX Фильтр: Тренд слишком слабый (%.2f < %d). Сигналы DMI игнорируются.", adx_current, ADX_TrendStrength);
            }
        }
        IndicatorRelease(adx_handle);
    }
    else
    {
        Print("Ошибка: не удалось создать хэндл для индикатора ADX.");
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
    Print("Торговля заблокирована фильтром ADX: на рынке нет сильного тренда.");
    return false; // Тренд слабый, торговля запрещена
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
