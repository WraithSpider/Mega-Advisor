//+------------------------------------------------------------------+
//|                                        MEGA_ANALYSIS_Advisor.mq5 |
//|                                  © Forex Assistant, Alan Norberg |
//|                                                       Версия 3.8 |
//+------------------------------------------------------------------+
#property version "3.8"

//--- Входные параметры
input bool   AllowMultipleTrades   = false;
input double LotSize               = 0.01;
input int    StopLossPips          = 40;
input int    TakeProfitPips        = 100;
input int    long_score_threshold  = 75;
input int    short_score_threshold = 81;
input double MinATR_Value = 0.00050; 

//--- Прототипы функций
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

//--- Стандартные функции советника ---
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
    static datetime prev_time = 0;
    datetime current_time = iTime(_Symbol, _Period, 0);
    if(prev_time == current_time) return;
    prev_time = current_time;

    int long_score = 0;
    int short_score = 0;
    Print("--- Новый бар! Начало полного анализа ---");

    CheckD1Trend(long_score, short_score);
    CheckDeepRSI(long_score, short_score);
    CheckFractalDivergence(long_score, short_score);
    CheckDeepMACD(long_score, short_score);
    CheckEMACross(long_score, short_score);
    CheckSMACross(long_score, short_score);
    CheckWMATrend(long_score, short_score);
    CheckSmartBBands(long_score, short_score);
    CheckIchimoku(long_score, short_score);
    
    // --- Шаг 3: ФИНАЛЬНЫЙ ПОДСЧЕТ И ТОРГОВЛЯ ---
    Print("--- ИТОГОВЫЙ ПОДСЧЕТ ---");
    int total_score = long_score + short_score;
    if (total_score > 0)
    {
        double long_probability = (double)long_score / total_score * 100;
        double short_probability = (double)short_score / total_score * 100;
        
        UpdateDashboard(long_score, short_score, long_probability, short_probability);
        
        string print_report = StringFormat("Анализ %s (%s): Очки Long/Short: %d/%d. Вероятность Long: %.0f%%, Short: %.0f%%.",
                                            _Symbol, EnumToString(_Period), long_score, short_score, long_probability, short_probability);
        Print(print_report);

        // --- ПРОВЕРКА ФИЛЬТРА ВОЛАТИЛЬНОСТИ ---
        if(IsVolatilitySufficient() == true)
        {
            // --- ЛОГИКА ОТКРЫТИЯ СДЕЛОК ---
            if(AllowMultipleTrades == false && PositionSelect(_Symbol) == true)
            {
                Print("Торговое решение пропущено: по символу %s уже есть открытая позиция.", _Symbol);
            }
            else
            {
                // Если сигнал на ПОКУПКУ (LONG) достаточно сильный
                if (long_probability >= long_score_threshold)
                {
                    MqlTradeRequest request; MqlTradeResult  result; 
                    ZeroMemory(request); ZeroMemory(result);
                    
                    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
                    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    
                    request.action = TRADE_ACTION_DEAL;
                    request.symbol = _Symbol;
                    request.volume = LotSize;
                    request.type = ORDER_TYPE_BUY;
                    request.price = price;
                    request.sl = price - (StopLossPips * 10 * point);
                    request.tp = price + (TakeProfitPips * 10 * point);
                    request.magic = 12345; 
                    request.comment = "Long by MEGA_ANALYSIS_Advisor";
                    
                    if(!OrderSend(request, result)) 
                    {
                        Print("Ошибка отправки ордера BUY: ", result.retcode, " - ", result.comment);
                    }
                    else 
                    {
                        Print("Ордер на ПОКУПКУ успешно отправлен.");
                    }
                }
                // Если сигнал на ПРОДАЖУ (SHORT) достаточно сильный
                else if (short_probability >= short_score_threshold)
                {
                    MqlTradeRequest request; MqlTradeResult  result; 
                    ZeroMemory(request); ZeroMemory(result);
                    
                    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                    request.action = TRADE_ACTION_DEAL;
                    request.symbol = _Symbol;
                    request.volume = LotSize;
                    request.type = ORDER_TYPE_SELL;
                    request.price = price;
                    request.sl = price + (StopLossPips * 10 * point);
                    request.tp = price - (TakeProfitPips * 10 * point);
                    request.magic = 12345;
                    request.comment = "Short by MEGA_ANALYSIS_Advisor";
                    
                    if(!OrderSend(request, result)) 
                    {
                        Print("Ошибка отправки ордера SELL: ", result.retcode, " - ", result.comment);
                    }
                    else 
                    {
                        Print("Ордер на ПРОДАЖУ успешно отправлен.");
                    }
                }
            }
        }
        else
        {
            // Этот блок выполнится, если фильтр ATR запретил торговлю
            Print("Торговля пропущена: низкая волатильность (ATR).");
        }
    }
    else // Этот else относится к "if (total_score > 0)"
    {
      UpdateDashboard(0,0,0,0);
    }
        

}

//+------------------------------------------------------------------+
//|                                                                  |
//|         ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ АНАЛИЗА                      |
//|                                                                  |
//+------------------------------------------------------------------+

// --- Функция для D1 Тренда ---
void CheckD1Trend(int &long_score, int &short_score){
    int ema_d1_handle = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_d1_handle != INVALID_HANDLE) {
        double ema_d1_buffer[]; ArraySetAsSeries(ema_d1_buffer, true);
        MqlRates rates_d1[]; ArraySetAsSeries(rates_d1, true);
        if(CopyRates(_Symbol, PERIOD_D1, 1, 1, rates_d1) > 0 && CopyBuffer(ema_d1_handle, 0, 1, 1, ema_d1_buffer) > 0) {
            if(rates_d1[0].close > ema_d1_buffer[0]) long_score += 3; else short_score += 3;
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

            if(rsi_prev < 30 && rsi_current >= 30) { long_score += 2; Print("RSI: выход из зоны перепроданности. Очки Long +2"); }
            if(rsi_prev > 70 && rsi_current <= 70) { short_score += 2; Print("RSI: выход из зоны перекупленности. Очки Short +2"); }
            
            if(rsi_current > 50) long_score++;
            if(rsi_current < 50) short_score++;
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
            Print("!!! ОБНАРУЖЕНА МЕДВЕЖЬЯ ДИВЕРГЕНЦИЯ ПО ФРАКТАЛАМ !!! Очки Short +5");
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
            Print("!!! ОБНАРУЖЕНА БЫЧЬЯ ДИВЕРГЕНЦИЯ ПО ФРАКТАЛАМ !!! Очки Long +5");
        }
    }
    IndicatorRelease(rsi_handle);
    IndicatorRelease(fractals_handle);
}

// --- Функция для углубленного MACD ---
void CheckDeepMACD(int &long_score, int &short_score){
    int macd_handle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   if(macd_handle != INVALID_HANDLE)
   {
       // Готовим буферы для главной линии, сигнальной и гистограммы
       double macd_main_buffer[], macd_signal_buffer[], macd_histogram_buffer[];
       
       // Нам нужны данные с нескольких последних свечей для анализа динамики
       int data_to_copy = 3; 
       ArraySetAsSeries(macd_main_buffer, true);
       ArraySetAsSeries(macd_signal_buffer, true);
       ArraySetAsSeries(macd_histogram_buffer, true);
       
       // Копируем данные из всех трех буферов индикатора
       if(CopyBuffer(macd_handle, 0, 0, data_to_copy, macd_main_buffer) > 0 &&   // Буфер 0: Главная линия
          CopyBuffer(macd_handle, 1, 0, data_to_copy, macd_signal_buffer) > 0 &&   // Буфер 1: Сигнальная линия
          CopyBuffer(macd_handle, 2, 0, data_to_copy, macd_histogram_buffer) > 0) // Буфер 2: Гистограмма
       {
           // Извлекаем значения для текущей закрытой свечи (индекс 1) и предыдущей (индекс 2)
           double main_current = macd_main_buffer[1];
           double main_prev = macd_main_buffer[2];
           double signal_current = macd_signal_buffer[1];
           double signal_prev = macd_signal_buffer[2];
           double hist_current = macd_histogram_buffer[1];
           double hist_prev = macd_histogram_buffer[2];
   
           // --- 1. Анализ ПЕРЕСЕЧЕНИЯ (+3 очка) ---
           // Бычье пересечение: раньше главная была НИЖЕ, а теперь стала ВЫШЕ
           if(main_prev <= signal_prev && main_current > signal_current)
           {
               long_score += 3;
               Print("MACD(",EnumToString(_Period),"): Обнаружено бычье пересечение! Очки Long +3");
           }
           // Медвежье пересечение: раньше главная была ВЫШЕ, а теперь стала НИЖЕ
           if(main_prev >= signal_prev && main_current < signal_current)
           {
               short_score += 3;
               Print("MACD(",EnumToString(_Period),"): Обнаружено медвежье пересечение! Очки Short +3");
           }
   
           // --- 2. Анализ СОСТОЯНИЯ (+1 очко) ---
           // Просто проверяем, кто выше сейчас
           if(main_current > signal_current) long_score++;
           if(main_current < signal_current) short_score++;
   
           // --- 3. Анализ ИМПУЛЬСА ГИСТОГРАММЫ (+1 очко) ---
           // Если гистограмма растет (увеличивается или уменьшает свое отрицательное значение)
           if(hist_current > hist_prev)
           {
               long_score++;
               Print("MACD(",EnumToString(_Period),"): Импульс гистограммы бычий. Очки Long +1");
           }
           // Если гистограмма падает (уменьшается или увеличивает свое положительное значение)
           if(hist_current < hist_prev)
           {
               short_score++;
               Print("MACD(",EnumToString(_Period),"): Импульс гистограммы медвежий. Очки Short +1");
           }
           
           Print("MACD(",EnumToString(_Period),"): анализ завершен. Итоговые очки Long/Short: ",long_score,"/",short_score);
       }
       IndicatorRelease(macd_handle);
   }
   else
   {
       Print("Ошибка: не удалось создать хэндл для индикатора MACD.");
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
