#ifndef Filter
#define Filter

//+------------------------------------------------------------------+
//|                                                       Filter.mqh |
//|                                               Alexey Volchanskiy |
//|                                      https://mql4.wordpress.com/ |
//+------------------------------------------------------------------+
#property copyright "Alexey Volchanskiy"
#property link      "https://mql4.wordpress.com/"
#property version   "1.04"
#property strict
#include <Object.mqh>
#include <AvLib\coeff.mqh>
#include <AvLib\Errors.mqh>

/*
Формат массива или файла коэффициентов фильтра
double coeff[] = {FiltersCount, FilterAddr, FilterLen, FilterAddr, FilterLen..., coeff1, coeff2, coeff3...};
*/
enum EErrors {EOk, ENumFilterOutOfRange};

class CFilter : CObject
{
#define TICK_BUF_SIZE       0x1000              // 4096
#define TICK_BUF_MAX_IDX    (TICK_BUF_SIZE - 1) // 0xFFF
#define OUT_BUF_SIZE        0x10000             // 65536
#define OUT_BUF_MAX_IDX     (OUT_BUF_SIZE - 1)  // 0xFFFF   

private:
    double  TickBuf[TICK_BUF_SIZE]; // промежуточный кольцевой буфер для хранения тиков
    double  OutBuf[OUT_BUF_SIZE];   // выходной кольцевой буфер
    double  Coeff[];                // массив коэффициентов
    int     TickBufIdx;             // индекс для нового входящего тика в TickBuf
    int     OutBufIdx;              // индекс для выходного буфера 
public:
    enum Errors {OK, NUM_FILTER_OUT_OF_RANGE };  
public:
    CFilter() {}
    ~CFilter() 
    {
        ArrayFree(Coeff);
    }
    
    double  GetOutBuf(const int idx)
    {
        int tmp = OutBufIdx-idx-1;
        double out = tmp >= 0 ? OutBuf[tmp] : OutBuf[OUT_BUF_SIZE+(tmp)]; 
        return out;
    }

    void    Init()
    {
        TickBufIdx = TICK_BUF_MAX_IDX;
        OutBufIdx = 0;
        for(int n = 0; n < TICK_BUF_SIZE; n++)
            TickBuf[n] = 0;
        for(int n = 0; n < OUT_BUF_SIZE; n++)
            OutBuf[n] = 0;
    }        

    EErrors  LoadCoeffFromArray(int numFilter, double &coeffArray[])
    {
        if(numFilter >= coeffArray[0])  // количество фильтров в массиве
            return ENumFilterOutOfRange;
        uint addr = (uint)coeffArray[1 + numFilter * 2];
        uint len = (uint)coeffArray[2 + numFilter * 2];   
        ArrayResize(Coeff, len);
        for(uint n = 0; n < len; n++)
            Coeff[n] = coeffArray[addr++];
        Init();    
        return EOk;
    }

    void    LoadCoeffFromArray(double &coeffArray[])
    {
        int len = ArraySize(coeffArray); 
        ArrayResize(Coeff, len);
        for(int n = 0; n < len; n++)
            Coeff[n] = coeffArray[n];
        Init();    
    }
    
    bool    LoadCoeffFromFile(int numFilter, string fileName)
    {
        // не реализовано
        return true;
    }
    
    // фильтрация одного тика
    double  FilterTick(double tick)
    {
        TickBuf[TickBufIdx] = tick;
        if (TickBufIdx == 0)
            TickBufIdx = TICK_BUF_MAX_IDX;
        else
            TickBufIdx--;
        int asize = ArraySize(Coeff); // вынести из функции!!!
        double acc = 0;
        int tbIdx = TickBufIdx;
        // делаем фильтрацию в цикле for
        for (int n = 0; n < asize; n++)
        {
            tbIdx++;
            /* вместо
            if(tbIdx > TICK_BUF_MAX_IDX)
            tbIdx = 0;
            */
            tbIdx &= TICK_BUF_MAX_IDX; // небольшая оптимизация вместо if
            acc += TickBuf[tbIdx] * Coeff[n];
        }
        OutBuf[OutBufIdx] = acc;
        OutBufIdx++;
        OutBufIdx &= OUT_BUF_MAX_IDX;
        return acc;
    }
    
    // фильтрация массива
    void    FilterTickSeries(double &ticks[], int count)
    {
        for(int n = 0; n < count; n++)
            ticks[n] = FilterTick(ticks[n]);
    }
};
#endif