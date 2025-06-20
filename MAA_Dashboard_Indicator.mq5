//+------------------------------------------------------------------+
//|                                     MAA_Dashboard_Indicator.mq5  |
//+------------------------------------------------------------------+
#property version "1.02"
#property indicator_separate_window
#property indicator_buffers 0
#property indicator_plots   0

// Уникальное имя нашего "почтового ящика"
#define DATA_OBJECT_NAME "MAA_DATA_HOLDER"

//+------------------------------------------------------------------+
//| Функция, которая выполняется на каждом тике                     |
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
    string data_from_expert = "";
    
    // Пытаемся найти наш "почтовый ящик" на основном графике (окно 0)
    if(ObjectFind(0, DATA_OBJECT_NAME) >= 0)
    {
        // Если нашли, читаем из него текст
        data_from_expert = ObjectGetString(0, DATA_OBJECT_NAME, OBJPROP_TEXT);
    }
    else
    {
        data_from_expert = "Ожидание данных от советника MAA...\nУбедитесь, что советник запущен на этом графике.";
    }
    
    // Выводим полученный текст в НАШЕ ОКНО (окно индикатора) с помощью Comment()
    Comment(data_from_expert);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Выполняется при удалении индикатора с графика                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); // Очищаем комментарий в нашем окне
}