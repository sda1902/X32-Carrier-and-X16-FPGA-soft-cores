unit Structures;

{
Блок содержит описания структур, используемых
системой компилирования и работы с проектами.
}

interface

uses SysUtils, Grids, ComCtrls;

type
    TP = array [0..0] of Byte;
    PP = ^TP;


// Запись, описывающая любой буфер данных,
// используемый по различному назначению
type TDataBuffer = record
     BuffPtr: PP;                           // указатель на буфер
     BuffLength: Longint;                  // текущая длина буфера в байтах
     BuffCount: Longint;                   // количество элементов данных в буфере
     BuffName: array [0..255] of Char;     // название буфера.
     end;

// Запись, описывающая набор объектов, выделенных из исходного текста
// Максимальное количество - до 2048
type TObjectCollection = record
     ObjectName: array [0..2047,0..255] of Char;  //строки названий объектов
     ObjectType: array [0..2047] of Byte;         //байты типов объектов
     ObjectOwner: array [0..2047] of Longint;     //указатели на объекты-хозяины
     ObjectSet: array [0..2047,0..255] of Char;   //строки названий объектов, являющихся наборами команд
     ObjectGran: array [0..2047] of Byte;         // гранулярность адреса
     BinaryDatas: array [0..2047] of PP;         //компилированные данные объектов
     BinaryLengths: array [0..2047] of Longint;  //размеры объектов
     BinaryCounts: array [0..2047] of Longint;   //реальное количество байт в объектах
     CrossDatas: array [0..2047] of PP;          //указатели на кросс-таблицы объектов
     CrossLengths: array [0..2047] of Longint;   //размеры буферов кросс-таблиц
     CrossCounts: array [0..2047] of Longint;    //количество байт в каждой таблице.
     ListDatas: array [0..2047] of PP;           //данные листинга
     ListLengths: array [0..2047] of Longint;    //размеры буферов листинга
     ListCounts: array [0..2047] of Longint;     //реальная длина данных в буферах листинга
     end;
{
Используемая кодировка байтов типов объектов
255 - свободная позиция в таблице
0 - виртуальный объект исходного текста
1 -
2 -
3 - OBJECT
}

// Запись, определяющая набор блоков описания систем команд
type TInstructionBuffer = record
     ISETName: ShortString;                      //название системы команд
     ISETFields: array [0..127] of ShortString;  //названия полей в мнемонике команд
     ISETFieldLocs: array [0..127] of Longint;   //расположение полей команд по битам
     ISETFieldSizes: array [0..127] of Longint;  //длина поля команды
     ISETBuffs: array [0..127] of PP;            //буферы, содержащие величины полей команд
     ISETBuffLengths: array [0..127] of Longint; //длины буферов, содержащие значения полей команд
     ISETBuffCounts: array [0..127] of Longint;  //количество элементов данных в каждом буфере.
     ISETBuffWidths: array [0..127] of Longint;  //ширина записей в каждом буфере.
     ISETMnemonicBuffer: PP;                     //буфер, содержащий мнемоники команд.
     ISETMnemonicLength: Longint;                //длина буфера мнемоник команд.
     ISETMnemonicCount: Longint;                 //количество элементов в буфере.
     ISETMnemonicWidth: Longint;                 //ширина записей в буфере.
     ISETMnemonicLoc: Longint;                   //расположение кода операции в командном слове
     ISETMnemonicSize: Longint;                  //размер кода операции в битах.
     ISETAlignCode: LongInt;   //код выравнивания
     end;

// запись идентифицирующая строку проектного файла
type TProjectEntry = record
     EntryName: array [0..255] of Char; //название точки входа
     EntryType: byte;                   //тип точки входа
     EntryData: PP;                  //блок данных точки входа
     EntryDataLength: Longint;          //длина данных для точки входа
     end;

//------------------------------------------------------------------------------
// Константы.
//------------------------------------------------------------------------------
const
     ClusterRecLength: Longint = 300;      //размер записи кластера
     LabRecLength: Longint = 298;          // размер записи для LAB
     CellRecLength: Longint = 265;         // размер для логической ячейки
     IORecLength: Longint = 271;           // размер для блока ввода/вывода
     PinRecLength: Longint = 261;          // размер для описания вывода
     EABRecLength: Longint = 266;          // размер для описания сегмента памяти

     WireType: Byte = 0;                   //идентификатор провода
     CellType: Byte = 1;                   //идентификатор логической ячейки
     LabType: Byte = 2;                    //идентификатор пакета логических блоков
     IOType: Byte = 3;                     //идентификатор блока ввода, вывода
     EABType: Byte = 4;                    //идентификатор сегмента памяти типа 0
     ClusterType: Byte = 5;                //идентификатор кластера
     PinType: Byte = 6;                    //идентификатор внешнего вывода

     // Константные строки, используемые для определения операторов
     ParamDel: Char = ':';
     EquationDel: Char = '=';

     // типы структур, записываемых в BPDL объекте
     BPDLUnitType: Byte = 0;
     BPDLBusType: Byte = 1;
     BPDLRegisterType: Byte = 2;
     BPDLConnectionType: Byte = 3;
     BPDLMemoryType: Byte = 4;
     BPDLFileType: Byte = 5;
     BPDLSubstType: Byte = 6;
     BPDLSubRegType: Byte = 7;
     BPDLConstantType: Byte = 8;
     BPDLConnectionBusType: Byte = 9;

     BPDLBusOperationType: Byte = $83;
     BPDLConFunctionType: Byte = $84;

     // типы структур, записываемых в проектных файлах
     ProjectRootEntryType: Byte = 0;
     ProjectSourcesEntryType: Byte = 1;
     ProjectLibraryEntryType: Byte = 2;
     ProjectEnvEntryType: Byte = 3;
     ProjectOptionsEntryType: Byte=4;
     ProjectOptionsBinaryType: Byte=5;
     ProjectLogDirType: Byte = 8;
     ProjectLogEntryType: Byte = 9;

     DataOpsCount: Longint=13;
     DataOps: array [0..13] of String = (
                                       'BYTE',     //0
                                       'WORD',     //1
                                       'DWORD',    //2
                                       'QWORD',    //3
                                       'EWORD',    //4
                                       'SINGLE',   //5
                                       'DOUBLE',   //6
                                       'EXTENDED', //7
                                       'BIT',      //8
                                       'NIBBLE',   //9
                                       'VARBIT',   //10
                                       'VARBYTE',  //11
                                       'VARFLOAT', //12
                                       'ABSTRACT'  //13
                                       );

     Oprs: array [0..32] of string=(
                                    '+',         //0
                                    '-',         //1
                                    '*',         //2
                                    '/',         //3
                                    '^',         //4
                                    'EXP',       //5   *
                                    'PI',        //6   *
                                    'LG',        //7   *
                                    'LN',        //8   *
                                    'LOG',       //9
                                    'LB',        //10  *
                                    'NOT',       //11  *
                                    'XOR',       //12
                                    'AND',       //13
                                    'OR',        //14
                                    'SHL',       //15
                                    'SHR',       //16
                                    'ASL',       //17
                                    'ASR',       //18
                                    'CSL',       //19
                                    'CSR',       //20
                                    'SIN',       //21  *
                                    'COS',       //22  *
                                    'TG',        //23  *
                                    'ARCSIN',    //24  *
                                    'ARCCOS',    //25  *
                                    'ARCTG',     //26  *
                                    'DEG',       //27  *
                                    'RAD',       //28  *
                                    'ABS',       //29  *
                                    'INT',       //30  *
                                    'FRACT',     //31  *
                                    'SQRT'       //32  *
                                    );
//------------------------------------------------------------------------------
// константы для сервера компиляции
//------------------------------------------------------------------------------
     // смещения в буферах данных
     SrvLengthDisp: Longint = 0;
     SrvFlagsDisp: Longint = 8;
     SrvPointerDisp: Longint = 12;
     SrvDataDisp: Longint = 16;
     SrvUploadDisp: Longint = 27;


implementation

end.
