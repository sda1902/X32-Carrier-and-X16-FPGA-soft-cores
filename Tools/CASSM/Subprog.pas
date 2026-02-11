unit Subprog;

interface

uses
    SysUtils, Structures, Classes, Math;

function CharToString(CharStr: array of Char): String;
procedure AddToSourceBuffer(Src: array of Byte; var Buff: TDataBuffer; var F: Boolean);

procedure SaveDataBuffer(var Buff: TDataBuffer; FName: String);
procedure SaveSourceBuffer(Buff: TDataBuffer; FName: String);
procedure SaveObjects(var ObjCollection: TObjectCollection; FName: String);
procedure SaveInstructionsCollection(S: String; var InstCollection: array of TInstructionBuffer);

function GetSourceLineFromSource(SrcBuffer: TDataBuffer; A: Longint): string;
procedure GetWord(var S: String; var T: String);
procedure RemoveFirstSpaces(var S: String);
procedure SetOwnerInSource(Line: Longint; Owner: Longint; var Buff: TDataBuffer);
function GetKeyWordType(Wrd: String): Byte;
procedure SkipParamString(var SrcBuffer: TDataBuffer; var SLine: Longint);
function CheckOwnerShip(Current: Longint; Obj: Byte; var ObjCollection: TObjectCollection): Boolean;
procedure RemoveStringFromSource(Line: Longint; var Buff: TDataBuffer);
procedure CreateObjectInCollection(Name: String; ObjType: Byte; var ObjCollection: TObjectCollection; var EFlag: Boolean ; var ObjNum: Longint);
function GetObjectPropWordType(S: String): Byte;
procedure ReplaceStringInSource(Str: String; Ln: Longint; var SrcBuffer: TDataBuffer);
function GetOwnerFromSource(Ln: Longint; Buffer: TDataBuffer): Longint;
function ReadParamString(var SrcBuffer: TDataBuffer; var SLine: Longint; var Buff: PP; CanDelete: Boolean; Module: Byte; Owner: Longint): Boolean;
function MyStrPas(Buff: PP): String;
function CheckConstantInBuffer(CName: string; var Buff: TDataBuffer): Boolean;

function ConvertExpression(S: String; var V: Extended): Byte;
function CheckRestrictedSymbols(S: String): Boolean;
function GetOperand(var S: String; var V: Extended): Byte;
function GetOpr(S: String): Byte;
function GetWrdType(S: String): Word;
function ConvertBool(S: String; var ECode: Byte): Extended;
function ConvertOct(S: String; var ECode: Byte): Extended;
function ConvertInt(S: String; var ECode: Byte): Extended;
function ConvertHex(S: String; var ECode: Byte): Extended;
function ConvertFlt(S: String; var ECode: Byte): Extended;
function CheckBool(S: String): Boolean;
function CheckOct(S: String): Boolean;
function CheckInt(S: String): Boolean;
function CheckHex(S: String): Boolean;
function CheckFlt(S: String): Boolean;
function CheckSymbol(S: String): Longint;
function CheckDataOperator(S: String): Longint;
function CheckReservedWord(S: String): Longint;

function CalcFieldSize(Bits: Longint): Longint;
procedure AddToFieldBuffer(V: Extended; Vf: Boolean; var FieldName: string; var InstBuffer: TInstructionBuffer; FIndex: Longint; var ECode: Byte);
procedure ConvertToIntegerBuffer(U: Extended;var Buff: array of Byte; var ECode: Byte);
procedure ConvertToFloatBuffer(V: Extended; var Buff: array of Byte);
function CalcMnemonicSize(Bits: Longint): Longint;
procedure RemoveLastSpaces(var Src: string);
procedure AddToMnemonicBuffer(V, Alv: Extended; Vf: Boolean;var MnemonicName: String; var FieldName: String; var InstBuffer: TInstructionBuffer; var ECode: Byte);
procedure AddToCrossBuffer(Indx: Longint; var ObjCollection: TObjectCollection; var Buff: array of Byte; Len: Longint);
function CheckInstruction(var InstName: string; var ObjCollection: TObjectCollection; var InstCollection: array of TInstructionBuffer; ObjIndex: Longint): Boolean;
function GetInstructionAlignment(var InstName: string; var ObjCollection: TObjectCollection; var InstCollection: array of TInstructionBuffer; ObjIndex: Longint): Longint;
function GetInstructionLength(var InstName: string; var ObjCollection: TObjectCollection; var InstCollection: array of TInstructionBuffer; ObjIndex: Longint): Longint;
function GetCompilerWordType(V: string): Longint;
function GetLabelOffset(var LName: string; var ObjCollection: TObjectCollection; Indx: Longint): Longint;
procedure AlignPointer(var Ptr: Longint; V: Longint);
procedure IncrementCounter(BuffSize: Longint; DataSize: Longint; var Ptr: Longint);
procedure FillByte(Buff: PP; Displ, Cnt: Longint; Dt: Byte);
procedure ShiftBuffer(var Buff: PP; var Cnt: Longint; var Depth: Longint);
procedure AddToBinaryBuffer(var Indx,Ptr: Longint; var ObjCollection: TObjectCollection; var Buff: PP; var SrcBuff: TDataBuffer; var Line: LongInt);
procedure ORBuffer(var Dst: PP; var Src: PP);
procedure SetValueToBuffer(Buff: PP; I: Longint; Tp: Longint; V: Extended; var ECode: Longint);
//function ConvertAddressEquation(var AType: Longint;var Equ: String;var DBuff: PP;var Indx: Longint;var Sel: Longint;var Ptr: Longint;var Obj: Longint;var ObjCollection: TObjectCollection): Byte;
function GetCrossTableByObjectName(var Name: String; var ObjCollection: TObjectCollection): Longint;
function GetVariableParameters(var VName: string;var ObjCollection: TObjectCollection; var BinIndex: Longint; var VOffset: Longint;var VLength: Longint;var VType: Byte): Boolean;
function GetLabelNameByAddress(var ObjCollection: TObjectCollection; var Indx,Ptr: LongInt): string;

implementation


// конвертация строки символов в строку текста
function CharToString(CharStr: array of Char): String;
var
   A: Longint;
   S: String;
begin
A:=0;
S:='';
while Ord(CharStr[A])<>0 do
      begin
      S:=S+CharStr[A];
      Inc(A);
      end;
Result:=S;
end;

//
//    Добавление строки в буфер исходного текста
//
procedure AddToSourceBuffer(Src: array of Byte; var Buff: TDataBuffer; var F: Boolean);
begin
F:=false;
if 256*(Buff.BuffCount+1) >= Buff.BuffLength then
   try
   ReallocMem(Buff.BuffPtr,Buff.BuffLength+16384);
   Buff.BuffLength:=Buff.BuffLength+16384;
   except
   F:=true;
   end;
if not F then
   begin
   Move(Src,Buff.BuffPtr[Buff.BuffCount*256],256);
   Inc(Buff.BuffCount);
   end
end;

//---------------------------------------------------------------------------------------------------------------------------------------------------
// Процедура тестовой записи буфера данных в файл
//
procedure SaveDataBuffer(var Buff: TDataBuffer; FName: String);
var
   A: LongInt;
   TB: array [0..7] of byte;
begin
A:=FileCreate(FName);
if A>0 then
   begin
   FileWrite(A,Buff.BuffName,256);
   FileWrite(A,Buff.BuffLength,4);
   FileWrite(A,Buff.BuffCount,4);
   FillChar(TB[0],8,0);
   FileWrite(A,TB[0],8);
   FileWrite(A,Buff.BuffPtr^,Buff.BuffLength);
   FileClose(A);
   end;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// Процедура тестовой записи файла исходного текста
//
procedure SaveSourceBuffer(Buff: TDataBuffer; FName: String);
var
   A, B, C: Longint;
   Bf: array [0..255] of Byte;
   Owner: array [0..255] of Char;
   S: String;
begin
if Buff.BuffCount<>0 then
   begin
   A:=FileCreate(FName);
   if A>0 then
      begin
      for B:=0 to Buff.BuffCount-1 do
          begin
          // запись номера хозяина строки
          S:='Owner: '+IntToStr(Buff.BuffPtr[4+B*256] or (Buff.BuffPtr[5+B*256] shl 8))+' ';
          StrPCopy(Owner,S);
          FileWrite(A,Owner[0],Length(S));
          Move(Buff.BuffPtr[6+B*256],Bf,250);
          C:=0;
          while Bf[C]<>0 do Inc(C);
          Bf[C]:=$0D;
          Bf[C+1]:=10;
          FileWrite(A,Bf[0],C+2);
          end;
      FileClose(A);
      end;
   end;
end;


//
// Чтение строки исходного текста
//
function GetSourceLineFromSource(SrcBuffer: TDataBuffer; A: Longint): string;
var
  Bf: array [0..255] of Char;
begin
if A<SrcBuffer.BuffCount then
  begin
  Move(SrcBuffer.BuffPtr[6+A*256],Bf,250);
  Result:=StrPas(Bf);
  end;
end;


// процедура возврата слова из строки
procedure GetWord(var S: String; var T: String);
var
   A: Longint;
begin
T:='';
if S<>'' then
   begin
   while (S[1]=' ')or(S[1]=#9) do
         begin
         Delete(S,1,1);
         if S='' then Break;
         end;
   if S<>'' then
      begin
      if (Ord(S[1])<$30)or(S[1]='[')or(S[1]=']')or(S[1]='{')or(S[1]='}')or(S[1]=';')or(S[1]='=')or(S[1]=':')or(S[1]='''') then T:=S[1]
         else for A:=1 to Length(S) do
              if (Ord(S[A])>=$30)and(S[A]<>'[')and(S[A]<>']')and(S[A]<>'{')and(S[A]<>'}')and(S[A]<>';')and(S[A]<>'=')and(S[A]<>':') then T:=T+S[A]
                                                                                                                                    else Break;
      end;
   Delete(S,1,Length(T));
   end;
end;

//------------------------------------------------------------------------------
// Процедура удаления первых пробелов из строки
procedure RemoveFirstSpaces(var S: String);
begin
if Length(S)<>0 then
   while (S[1]=' ')or(S[1]=#9) do
         begin
         Delete(S,1,1);
         if Length(S)=0 then Break;
         end;
end;

//------------------------------------------------------------------------------
// Процедура установки индекса владельца в строке исходного текста
procedure SetOwnerInSource(Line: Longint; Owner: Longint; var Buff: TDataBuffer);
begin
if Line<Buff.BuffCount then
   begin
   Buff.BuffPtr[4+Line*256]:=Owner;
   Buff.BuffPtr[5+Line*256]:=Owner shr 8;
   end;
end;

//------------------------------------------------------------------------------
// Процедура возврата типа слова, вычитанного из строки
function GetKeyWordType(Wrd: String): Byte;
var
   I: Longint;
const
     KeyWordCount: Longint = 4;
     KeyWordStrings: array [0..4] of String = (
                                              // объекты, имеющие строки текста
                                              'OBJECT',        //1 было 3
                                              'MACRO',         //2 было 10
                                              'ISET',           //3 было 11
                                              'FIELD',          //4 было 12
                                              'INSTRUCTIONS'   //5 было 13
                                              );
begin
Result:=0;
for I:=0 to KeyWordCount do
    if (Wrd=KeyWordStrings[I])and(Length(Wrd)=Length(KeyWordStrings[I])) then
       begin
       Result:=I+1;
       Break;
       end;
end;

//------------------------------------------------------------------------------
// процедура пропуска строк, входящих в блок параметров
procedure SkipParamString(var SrcBuffer: TDataBuffer; var SLine: Longint);
var
   S: String;
begin
while SLine<SrcBuffer.BuffCount do
      begin
      S:=GetSourceLineFromSource(SrcBuffer,SLine);
      Inc(SLine);
      if Length(S)>=2 then
         if (S[Length(S)]=#13)and(S[Length(S)-1]=')') then Break;
      end;
end;

//------------------------------------------------------------------------------
// проверка правильности вложения одного объекта в другой
function CheckOwnerShip(Current: Longint; Obj: Byte; var ObjCollection: TObjectCollection): Boolean;
begin
Result:=true;
if Current>=0 then
   case ObjCollection.ObjectType[Current] of
     0: // если текущий объект является объектом исходного текста
        Result:=(Obj=1)or(Obj=2)or(Obj=3);
     1: // если текущий текст является телом объекта кода
        Result:=false;
     2: // если это запись макро
        Result:=false;
     3: // если это описание системы команд
        Result:=(Obj=4)or(Obj=5);
        // поле
     4: Result:=false;
        // мнемоника команды
     5: Result:=false;
     end;
end;


//------------------------------------------------------------------------------
// удаление строки из буфера исходного текста
procedure RemoveStringFromSource(Line: Longint; var Buff: TDataBuffer);
begin
if Line<Buff.BuffCount then FillChar(Buff.BuffPtr[6+Line*256],250,0);
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// процедура создания объекта в коллекции
procedure CreateObjectInCollection(Name: String; ObjType: Byte; var ObjCollection: TObjectCollection; var EFlag: Boolean ; var ObjNum: Longint);
var
   I: Longint;
begin
EFlag:=true;
for I:=0 to 2047 do
    if ObjCollection.ObjectType[I]=255 then
       begin
       EFlag:=false;
       StrPCopy(ObjCollection.ObjectName[I],Name);
       ObjCollection.ObjectType[I]:=ObjType;
       ObjCollection.ObjectOwner[I]:=ObjNum;
       ObjNum:=I;
       Break;
       end;
end;

//---------------------------------------------------------------------------------------------------------------------------------------------------
// возврат типа свойства объекта
function GetObjectPropWordType(S: String): Byte;
var
   I: Longint;
const
     PropWords: array [1..2] of String = (
                                         'ISET',           //1 было 7
                                         'GRANULARITY'     //2 было 8
                                         );
begin
Result:=0;
for I:=1 to 2 do
    if (S=PropWords[I])and(Length(S)=Length(PropWords[I])) then
       begin
       Result:=I;
       Break;
       end;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// Замена строки в буфере исходного текста
procedure ReplaceStringInSource(Str: String; Ln: Longint; var SrcBuffer: TDataBuffer);
var
   Buff: array [0..256] of Char;
begin
StrPCopy(Buff,Str);
if Ln<SrcBuffer.BuffCount then Move(Buff,SrcBuffer.BuffPtr[6+Ln*256],250);
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// Запись параметров выделенных из текста объектов
procedure SaveObjects(var ObjCollection: TObjectCollection; FName: String);
var
   A: longint;
   Strings: TStringList;
begin
Strings:=TStringList.Create;
A:=0;
while ObjCollection.ObjectType[A]<>255 do
      begin
      // добавление названия объекта
      Strings.Add(IntToStr(A)+' '+StrPas(ObjCollection.ObjectName[A]));
      // добавление типа объекта
      case ObjCollection.ObjectType[A] of
           1: Strings.Add(Chr(9)+'Object');
           2: Strings.Add(Chr(9)+'Macro');
           3: Strings.Add(Chr(9)+'Iset');
           4: Strings.Add(Chr(9)+'Field');
           5: Strings.Add(Chr(9)+'Instructions');
           end;
      // добавление индекса хозяина
      Strings.Add(Chr(9)+'Owner: '+IntToStr(ObjCollection.ObjectOwner[A]));
      // добавление параметров, если это объект
      if ObjCollection.ObjectType[A]=1 then
         begin
         Strings.Add(Chr(9)+'Instruction Set='+StrPas(ObjCollection.ObjectSet[A]));
         Strings.Add(Chr(9)+'Granularity='+IntToStr(ObjCollection.ObjectGran[A]));
         end;
      Inc(A);
      end;
Strings.SaveToFile(FName);
Strings.Free;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// процедура возврата номера объекта хозяина из строки исходного текста
function GetOwnerFromSource(Ln: Longint; Buffer: TDataBuffer): Longint;
var
   A: Longint;
begin
A:=-1;
if Ln<Buffer.BuffCount then
   begin
   A:=0;
   Move(Buffer.BuffPtr[4+Ln*256],A,2);
   end;
Result:=A;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// функция формирования строки параметров, ограниченной круглыми скобками
function ReadParamString(var SrcBuffer: TDataBuffer; var SLine: Longint; var Buff: PP; CanDelete: Boolean; Module: Byte; Owner: Longint): Boolean;
var
   A: Longint;
   S,T,V: String;
   E,F: Boolean;
begin
S:='';
F:=false;
E:=false;
T:='';
if SLine<SrcBuffer.BuffCount then
   if Owner=GetOwnerFromSource(SLine,SrcBuffer) then
      begin
      V:=GetSourceLineFromSource(SrcBuffer,SLine);
      T:=V;
      end;
if Pos('(',T)<>0 then
   while SLine<SrcBuffer.BuffCount do
         if Owner<>GetOwnerFromSource(SLine,SrcBuffer)
            then begin
                 S:='';
                 Break;
                 end
            else begin
                 V:=GetSourceLineFromSource(SrcBuffer,SLine);
                 T:=V;
                 while T<>'' do
                       if F
                          then begin
                               if Length(T)>1 then
                                  if T[Length(T)]=';' then S:=S+T
                                     else if T[Length(T)-1]<>')' then S:=S+Copy(T,1,Length(T)-1)+';'
                                          else begin
                                          S:=S+Copy(T,1,Length(T)-2);
                                          if Length(S)<>0 then
                                             if S[Length(S)]<>';' then S:=S+';';
                                          E:=true;
                                          end;
                               T:='';
                               end
                          else begin
                               if Pos('(',T)=0 then T:=''
                                  else begin
                                  Delete(T,1,Pos('(',T));
                                  F:=true;
                                  end;
                          end;
                 if CanDelete then RemoveStringFromSource(SLine,SrcBuffer);
                 if not E then Inc(SLine)
                          else Break;
                 end;
Result:=false;
if S<>'' then
   try
   ReallocMem(Buff,Length(S)+1024);
   for A:=1 to Length(S) do Buff[A-1]:=Ord(S[A]);
   Buff[Length(S)]:=0;
   Result:=true;
   except
   end;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// Процедура конвертации строки байт в строку
function MyStrPas(Buff: PP): String;
var
   A: Longint;
   S: String;
begin
S:='';
A:=0;
while Buff[A]<>0 do
      begin
      S:=S+Chr(Buff[A]);
      Inc(A);
      end;
Result:=S;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
// Процедура проверки наличия константы в буфере
function CheckConstantInBuffer(CName: string; var Buff: TDataBuffer): Boolean;
var
   A: Longint;
begin
Result:=false;
A:=0;
while A<Buff.BuffCount do
      begin
      if (StrPas(Addr(Buff.BuffPtr[A]))=CName)and(Length(StrPas(Addr(Buff.BuffPtr[A])))=Length(CName)) then
         begin
         Result:=true;
         Break;
         end;
      A:=A+256;
      end;
end;


//---------------------------------------------------------------------------------------------------------------------------------------------------
//процедура конвертации математического выражения
// ECode=
// 0 - если все правильно обработано
// 1 - если неправильное определение открывающих и закрывающих скобок
// 2 - если отрицательный операнд квадратного корня
// 3 - если обнаружение неизвестного математического оператора
// 4 - если обнаружение в строке известного но несоответствующего по типу оператора или ключевого слова
// 5 - если число выходит за возможные пределы представления
// 6 - если неправильное определение операнда функции
// 7 - если неправильное применение оператора операции, например '23 sin 34'
// 8 - если встретилась операция деления на 0
// 9 - если переполнение
// 10 - если неправильные операнды логарифмической функции
// 11 - если невозможно представить число в целочисленном формате
//---------------------------------------------------------------------------------------------------------------------------------------------------
function ConvertExpression(S: String; var V: Extended): Byte;
var
   A,B: Longint;
   T: String;
   F_op,S_op,T_op: Boolean;
   Vf,Vs,Vt: Extended;
   FOp,SOp: String;
begin
Result:=0;
// проверка наличия запрещенных символов
if CheckRestrictedSymbols(S) then Result:=3
else begin
//определение правильности вложения скобочных выражений
V:=0.0;
T:=S;
if T<>'' then
   begin
   B:=0;
   for A:=0 to Length(T) do
       if T[A]='(' then B:=B+1
          else if T[A]=')' then begin
                                B:=B-1;
                                if B<0 then Break;
                                end;
   if B<>0 then Result:=1                               //призак ошибки по несовпадению скобок
      else begin
      F_op:=false;                                     //первый операнд
      S_op:=false;                                     //второй операнд
      T_op:=false;                                     //третий операнд
      FOp:='';
      SOp:='';
      while (T<>'')or(Fop<>'') do
            begin
            if (FOp<>'')and F_op and S_op and (not T_op) and (Sop='') then
               //выполнение операции, если первые два операнда прочитаны
               if (FOp='-')or(FOp='+') then
                  if T<>'' then
                     if (T[1]='*')or(T[1]='/')or(T[1]='^') then
                        begin
                        //обработка, если следующая операция является операцией, котрорую требуется выполнить первой
                        Sop:=T[1];
                        Delete(T,1,1);
                        Result:=GetOperand(T,Vt);
                        T_op:=true;
                        end;
            if (FOp<>'')and F_op and S_op and (SOp='') then
               begin
               //Обработка, если требуется произвести только одну первую операцию
               case GetOpr(Fop) of
                    0: try Vf:=Vf+Vs;                     //сложение
                       except on EOverflow do Result:=9; end;
                    1: try Vf:=Vf-Vs;                     //вычитание
                       except on EOverflow do Result:=9; end;
                    2: try Vf:=Vf*Vs;                     //умножение
                       except on EOverflow do Result:=9; end;
                    3: if Vs=0 then Result:=8
                          else try Vf:=Vf/Vs;                     //деление
                          except on EOverflow do Result:=9; end;
                    4: try Vf:=Power(Vf,Vs);              //возведение в степень
                       except on EOverflow do Result:=9; end;
                    5,6,7,8: Result:=7;
                    9: if (Vf<=0)or(Vs<=0) then Result:=10
                       else Vf:=LogN(Vf,Vs);               //произвольный логарифм
                    10,11: Result:=7;
                    12: try Vf:=Round(Vf) xor Round(Vs);  //XOR
                        except on EInvalidOp do Result:=11; end;
                    13: try Vf:=Round(Vf) and Round(Vs);  //AND
                        except on EInvalidOp do Result:=11; end;
                    14: try Vf:=Round(Vf) or Round(Vs);   //OR
                        except on EInvalidOp do Result:=11; end;
                    15: try Vf:=Round(Vf) shl Round(Vs); //SHL
                        except on EInvalidOp do Result:=11; end;
                    16: try Vf:=Round(Vf) shr Round(Vs); //SHR
                        except on EInvalidOp do Result:=11; end;
                    17: try Vf:=(Round(Vf) and $80000000)or((Round(Vf) shl Round(Vs))and $7fffffff); //ASL
                        except on EInvalidOp do Result:=11; end;
                    18: try Vf:=(Round(Vf) and $80000000)or((Round(Vf) shr Round(Vs))and $7fffffff); //ASR
                        except on EInvalidOp do Result:=11; end;
                    19: try Vf:=(Round(Vf) shr 31)or(Round(Vf) shl Round(Vs)); //CSL
                        except on EInvalidOp do Result:=11; end;
                    20: try Vf:=(Round(Vf) shl 31)or(Round(Vf) shr Round(Vs)); //CSR
                        except on EInvalidOp do Result:=11; end;
                    21,22,23,24,25,26,27,28,29,30,31,32: Result:=7;
                    255: Result:=3;
                    end;
               F_op:=true;
               S_op:=false;
               Fop:='';
               end;
            if (Fop<>'')and F_op and S_op and (Sop<>'') and T_op then
               begin
               //Обработка, если требуется выполнить вторую операцию раньше первой
               case GetOpr(Sop) of
                    0: try Vs:=Vs+Vt;                     //сложение
                       except on EOverflow do Result:=9; end;
                    1: try Vs:=Vs-Vt;                     //вычитание
                       except on EOverflow do Result:=9; end;
                    2: try Vs:=Vs*Vt;                     //умножение
                       except on EOverflow do Result:=9; end;
                    3: if Vt=0 then Result:=8
                       else try Vs:=Vs/Vt;                     //деление
                       except on EOverflow do Result:=9; end;
                    4: try Vs:=Power(Vs,Vt);              //возведение в степень
                       except on EOverflow do Result:=9; end;
                    5,6,7,8: Result:=7;
                    9: if (Vs<=0)or(Vt<=0) then Result:=10
                       else Vs:=LogN(Vs,Vt);               //произвольный логарифм
                    10,11: Result:=7;
                    12: try Vs:=Round(Vs) xor Round(Vt);  //XOR
                        except on EInvalidOp do Result:=11; end;
                    13: try Vs:=Round(Vs) and Round(Vt);  //AND
                        except on EInvalidOp do Result:=11; end;
                    14: try Vs:=Round(Vs) or Round(Vt);   //OR
                        except on EInvalidOp do Result:=11; end;
                    15: try Vs:=Round(Vs) shl Round (Vt); //SHL
                        except on EInvalidOp do Result:=11; end;
                    16: try Vs:=Round(Vs) shr Round (Vt); //SHR
                        except on EInvalidOp do Result:=11; end;
                    17: try Vs:=(Round(Vs) and $80000000)or((Round(Vs) shl Round(Vt))and $7fffffff); //ASL
                        except on EInvalidOp do Result:=11; end;
                    18: try Vs:=(Round(Vs) and $80000000)or((Round(Vs) shr Round(Vt))and $7fffffff); //ASR
                        except on EInvalidOp do Result:=11; end;
                    19: try Vs:=(Round(Vs) shr 31)or(Round(Vs) shl Round(Vt)); //CSL
                        except on EInvalidOp do Result:=11; end;
                    20: try Vs:=(Round(Vs) shl 31)or(Round(Vs) shr Round(Vt)); //CSR
                        except on EInvalidOp do Result:=11; end;
                    21,22,23,24,25,26,27,28,29,30,31,32: Result:=7;
                    255: Result:=3;
                    end;
               F_op:=true;
               S_op:=true;
               T_op:=false;
               Sop:='';
               end;
            if (not F_op)and(Fop='') then
               begin
               //Обработка, если вообще первое вхождение
               Result:=GetOperand(T,Vf);
               F_op:=true;
               end;
            if F_op and (Fop='') then
               if T<>'' then
                  begin
                  while (T[1]=' ')or(T[1]=#9) do Delete(T,1,1);
                  if (T[1]='+')or(T[1]='-')or(T[1]='*')or(T[1]='/')or(T[1]='^')
                     then begin
                          Fop:=T[1];
                          Delete(T,1,1);
                          end
                     else GetWord(T,Fop); //Попытка прочесть код операции после того как первый операнд был извлечен
                  end;
            if F_op and (Fop<>'')and(not S_op) then
               begin
               //Обработка, если требуется прочесть второй операнд операции
               Result:=GetOperand(T,Vs);
               S_op:=true;
               end;
            if Result<>0 then
               begin
               T:='';
               Fop:='';
               end;
            end;
      V:=Vf;
      end;
   end;
end;
end;
// Процедура проверки наличия в строке запрещенных для использования символов
function CheckRestrictedSymbols(S: String): Boolean;
var
   A: Longint;
begin
Result:=false;
if Length(S)>0 then
   for A:=0 to Length(S) do
       if (S[A]=',')or(S[A]='=') then
          begin
          Result:=true;
          Break;
          end;
end;
//Процедура возвращения операнда из строки
function GetOperand(var S: String; var V: Extended): Byte;
var
   A,B,C: Longint;
   T,Tt: String;
begin
while (Length(S)<>0)and((S[1]=' ')or(S[1]=#9)) do Delete(S,1,1);
if S<>'' then
   if S[1]='('
      then begin
           //Обработка, если это определение операнда через вложенное выражение
           B:=1;
           A:=1;
           while B<>0 do
                 begin
                 A:=A+1;
                 if S[A]='(' then B:=B+1
                             else if S[A]=')' then B:=B-1;
                 end;
           T:=Copy(S,2,A-2);
           Delete(S,1,A);
           V:=0;
           Result:=ConvertExpression(T,V);
           end
      else begin
           //Обработка, если это число или функция
           A:=GetWrdType(S);
           B:=A and $0FF;
           case B of
                0,15: begin
                   //попытка определения функции
                   GetWord(S,Tt);
                   C:=GetOpr(Tt);
                   case C of
                        0,1,2,3,4,9,12,13,14,15,16,17,18,19,20: Result:=7;
                        5,6,7,8,10,11,21,22,23,24,25,26,27,28,29,30,31,32: if S[1]<>'(' then Result:=6
                                                                                        else Result:=GetOperand(S,V);
                        255: Result:=3;
                        end;
                   if Result=0 then
                      begin
                      case C of
                           5: try V:=Exp(V);                    //Exp
                              except on EOverflow do Result:=9; end;
                           6: try V:=Pi*V;                      //Pi
                              except on EOverflow do Result:=9; end;
                           7: if V<=0 then Result:=10
                              else V:=Log10(V);                  //LG
                           8: if V<=0 then Result:=10
                              else V:=Ln(V);                     //Ln
                           10: if V<=0 then Result:=10
                               else V:=Log2(V);                  //Lb
                           11: try V:=not Round(V);             //NOT
                               except on EInvalidOp do Result:=11; end;
                           21: V:=Sin(V*Pi/180);            //Sin
                           22: V:=Cos(V*Pi/180);            //COS
                           23: V:=Tan(V*Pi/180);            //Tg
                           24: V:=(180*ArcSin(V))/Pi;       //ArcSin
                           25: V:=(180*ArcCos(V))/Pi;       //ArcCos
                           26: V:=(180*ArcTan(V))/Pi;       //ArcTg
                           27: V:=(180*V)/Pi;               //DEG
                           28: V:=(V*Pi)/180;               //RAD
                           29: V:=Abs(V);                   //ABS
                           30: V:=Int(V);                   //INT
                           31: V:=Frac(V);                  //FRACT
                           32: if V<0 then Result:=2
                               else V:=Sqrt(V);                  //SQRT
                           end;
                      end;
                   end;
                6,7,8,9,10,11,12,13,14,16,17,18,19,20,21,22: Result:=4;
                1,2,3,4,5: begin
                           //если число
                           if B=1 then V:=ConvertBool(Copy(S,1,A shr 8),Result)
                              else if B=2 then V:=ConvertOct(Copy(S,1,A shr 8),Result)
                                   else if B=3 then V:=ConvertInt(Copy(S,1,A shr 8),Result)
                                        else if B=4 then V:=ConvertHex(Copy(S,1,A shr 8),Result)
                                             else if B=5 then V:=ConvertFlt(Copy(S,1,A shr 8),Result);
                           Delete(S,1,A shr 8);
                           end;
                end;
           end;
end;
//Функция возврата типа оператора
function GetOpr(S: String): Byte;
var
   I: Longint;
const
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
begin
GetOpr:=255;
if S<>'' then
   for I:=0 to 32 do
       if (AnsiUpperCase(S)=Oprs[I])and(Length(S)=Length(Oprs[I])) then
          begin
          GetOpr:=I;
          Break;
          end;
end;

//Локальная функция возврата типа слова, расположенного в строке первым
function GetWrdType(S: String): Word;
var
   T: String;
   Lng: Byte;
   Tp: Byte;
   A,B: Longint;
begin
GetWrdType:=0;
if S<>'' then
   begin
   T:=AnsiUpperCase(S);
   while (Ord(T[1])<$21)and(T<>'') do Delete(T,1,1);                //удаление пробелов и символов меньше его
   Lng:=Length(T);
   Tp:=255;
   if Lng>0 then
      begin
      //если строка содержит данные, которые необходимо проверить
      A:=0;
      for B:=1 to Length(T) do
          if (B=1)and(T[B]='-') then A:=A+1
             else if (B>1)and(T[B]='-')and(T[B-1]='E') then A:=A+1
                  else if T[B]='^' then Break
                       else if (T[B]=':')or(T[B]='.') then A:=A+1
                            else if Ord(T[B])>$2F then A:=A+1
                                 else Break;
      T:=Copy(T,1,A);
      Lng:=Length(T);
      if T<>'' then
         if T[Lng]=':' then Tp:=14
            else if (T='BYTE')and(Lng=4) then Tp:=6
                 else if (T='WORD')and(Lng=4) then Tp:=7
                      else if (T='DWORD')and(Lng=5) then Tp:=8
                           else if (T='QWORD')and(Lng=5) then Tp:=9
                                else if (T='EWORD')and(Lng=5) then Tp:=10
                                     else if (T='SINGLE')and(Lng=6) then Tp:=11
                                          else if (T='DOUBLE')and(Lng=6) then Tp:=12
                                               else if (T='EXTENDED')and(lng=8) then Tp:=13
                                                    else if (T='OFFSET')and(Lng=6) then Tp:=16
                                                         else if (T='SELECTOR')and(Lng=8) then Tp:=17
                                                              else if (T='PTR')and(Lng=3) then Tp:=18
                                                                   else if (T='VECTOFFSET')and(Lng=10) then Tp:=19
                                                                        else if (T='VECTPTR')and(Lng=7) then Tp:=20
                                                                             else if (T='DISPLACEMENT')and(Lng=12) then Tp:=21
                                                                                  else if (T='COMMENT')and(Lng=7) then Tp:=22
                                                                                       else if CheckBool(T) then Tp:=1
                                                                                            else if CheckOct(T) then Tp:=2
                                                                                                 else if CheckInt(T) then Tp:=3
                                                                                                      else if CheckHex(T) then Tp:=4
                                                                                                           else if CheckFlt(T) then Tp:=5
                                                                                                                else Tp:=15
      end;
   GetWrdType:=(Lng shl 8)or Tp;
   end;
end;

//Процедура конвертации числа, записанного в двоичной системе
function ConvertBool(S: String; var ECode: Byte): Extended;
var
   A,B: Longint;
   T: String;
begin
A:=0;
T:=S;
if T<>'' then
   begin
   if (T[Length(T)]='B')or(T[Length(T)]='b') then T:=Copy(T,1,Length(T)-1);
   if Length(T)>32 then ECode:=5
      else if T<>'' then
           for B:=1 to Length(T) do
               if T[B]='0' then A:=A shl 1
                           else A:=(A shl 1)or 1;
   end;
ConvertBool:=A;
end;

// Процедура конвертации числа, записанного в восьмиричной системе
function ConvertOct(S: String; var ECode: Byte): Extended;
var
   A,B: Longint;
   T: String;
begin
A:=0;
T:=S;
if T<>'' then
   begin
   if (T[Length(T)]='Q')or(T[Length(T)]='q') then T:=Copy(T,1,Length(T)-1);
   if Length(T)>11 then ECode:=5
      else if T<>'' then
           for B:=1 to Length(T) do A:=(A shl 3)or(Ord(T[B])and 7);
   end;
ConvertOct:=A;
end;

// Процедура конвертации строки, представленной в десятичной системе
function ConvertInt(S: String; var ECode: Byte): Extended;
begin
ConvertInt:=0;
try
ConvertInt:=StrToInt(S);
except
on EConvertError do ECode:=5;
end;
end;

//Функция конвертации строки, представленной в шестнадцатиричной системе
function ConvertHex(S: String; var ECode: Byte): Extended;
var
   A: Int64;
   B: Longint;
   T: String;
begin
A:=0;
T:=S;
if T<>'' then
   begin
   if (T[Length(T)]='H')or(T[Length(T)]='h') then T:=Copy(T,1,Length(T)-1);
   if T<>'' then if T[1]='0' then Delete(T,1,1);
   if Length(T)>16 then ECode:=5
      else if T<>'' then
           for B:=1 to Length(T) do
               if Ord(T[B])>$39 then A:=(A shl 4)or((Ord(T[B])-$37)and $0F)
                                else A:=(A shl 4)or(Ord(T[B])and $0F);
   end;
ConvertHex:=A;
end;

// Функция конвертации числа из строки в формате с плавающей точкой
function ConvertFlt(S: String; var ECode: Byte): Extended;
begin
ConvertFlt:=0;
try
ConvertFlt:=StrToFloat(S);
except
on EConvertError do ECode:=5;
end;
end;

//локальная функция проверки числа на двоичное определение
function CheckBool(S: String): Boolean;
var
   I: Longint;
begin
if Length(S)<2 then CheckBool:=false
   else if (S[Length(S)]<>'B')and(S[Length(S)]<>'b') then CheckBool:=false
        else begin
        CheckBool:=true;
        for I:=1 to Length(S)-1 do
        if (S[I]<>'0')and(S[I]<>'1') then CheckBool:=false;
        end;
end;

//локальная функция проверки определения числа в восьмиричном формате
function CheckOct(S: String): Boolean;
var
   I: Longint;
begin
if Length(S)<2 then CheckOct:=false
   else if (S[Length(S)]<>'Q')and(S[Length(S)]<>'q') then CheckOct:=false
        else begin
        CheckOct:=true;
        for I:=1 to Length(S)-1 do
            if (Ord(S[I])<$30)or(Ord(S[I])>$37) then CheckOct:=false;
        end;
end;

// локальная функция проверки на десятичный формат целого числа
function CheckInt(S: String): Boolean;
var
   I: Longint;
begin
CheckInt:=true;
if S='' then CheckInt:=false
   else begin
   if (S[1]='-')or(S[1]='+') then
      if Length(S)<2 then CheckInt:=false
         else for I:=2 to Length(S) do if (Ord(S[I])<$30)or(Ord(S[I])>$39) then CheckInt:=false;
   if (S[1]<>'-')and(S[1]<>'+') then
      for I:=1 to Length(S) do if (Ord(S[I])<$30)or(Ord(S[I])>$39) then CheckInt:=false;
   end;
end;

// локальная функция проверки строки на определение числа в HEX-коде
function CheckHex(S: String): Boolean;
var
   T: String;
   I: Longint;
begin
CheckHex:=true;
T:=AnsiUpperCase(S);
if Length(T)<2 then CheckHex:=false
   else if (Ord(T[1])<$30)or(Ord(T[1])>$39) then CheckHex:=false
        else if T[Length(T)]<>'H' then CheckHex:=false
             else for I:=1 to Length(T)-1 do
                  if ((Ord(T[I])<$30)or(Ord(T[I])>$39))and((Ord(T[I])<$41)or(Ord(S[I])>$46)) then CheckHex:=false;
end;

// Функция проверки формата на число с плавающей точкой
function CheckFlt(S: String): Boolean;
var
   F: Boolean;
   A: Longint;
begin
Result:=false;
DecimalSeparator:='.';
if S<>'' then
   begin
   // проверка запрещенных символов
   F:=true;
   for A:=1 to Length(S) do
       if ((Ord(S[A])<$30)or(Ord(S[A])>$39))and(S[A]<>'.')and(S[A]<>'-')and(S[A]<>'+')and(S[A]<>'e')and(S[A]<>'E') then
          begin
          F:=false;
          Break;
          end;
   if F then
      try
      StrToFloat(S);
      Result:=true;
      except
      on EConvertError do Result:=false;
      end;
   end;
end;

//------------------------------------------------------------------------------
// Функция проверки строки S на содержание символа
function CheckSymbol(S: String): Longint;
var
   I: Longint;
const
     SymCount: Longint = 8;
     Symbols: array [0..8] of String = (
                                '.',     //0
                                ',',     //1
                                ':',     //2
                                '[',     //3
                                ']',     //4
                                '''',    //5
                                '!',     //6
                                '(',     //7
                                ')'      //8
                                );
begin
Result:=-1;
for I:=0 to SymCount do
    if (S=Symbols[I])and(Length(S)=Length(Symbols[I])) then
       begin
       Result:=I;
       Break;
       end;
end;

//------------------------------------------------------------------------------
// функция проверки слова на определение оператора данных
function CheckDataOperator(S: String): Longint;
var
   I: Longint;
const
     DataOpsCount: Longint=13;
     DataOps: array [0..13] of String = (
                                       'BYTE',     //0
                                       'WORD',     //1
                                       'DWORD',    //2
                                       'QWORD',    //3
                                       'OWORD',    //4
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
begin
Result:=-1;
for I:=0 to DataOpsCount do
    if (S=DataOps[I])and(Length(S)=Length(DataOps[I])) then
       begin
       Result:=I;
       Break;
       end;
end;


//------------------------------------------------------------------------------
// Процедура проверки служебного слова
function CheckReservedWord(S: String): Longint;
var
   I: Longint;
const
     ResWordCount: Longint = 6;
     ResWords: array [0..6] of String = (
                                        'COMMENT',      //0
                                        'ARRAY',        //1
                                        'ALIGN',        //2
                                        'ON',           //3
                                        'FOR',          //4
                                        'IF',           //5
                                        'ORG'           //6
                                        );
begin
Result:=-1;
for I:=0 to ResWordCount do
    if (S=ResWords[I])and(Length(S)=Length(ResWords[I])) then
       begin
       Result:=I;
       Break;
       end;
end;


//------------------------------------------------------------------------------
// функция проверки слова на соответствие адресному оператору
function CheckAddressOperator(S: String): Longint;
var
   I: Longint;
const
     AddrWordsCount: Longint = 5;
     AddrWords: array [0..5] of String = (
                                         'OFFSET',   //0
                                         'SELECTOR', //1
                                         'POINTER',  //2
                                         'VOFFSET',  //3
                                         'VPOINTER', //4
                                         'DISPLACEMENT' //5
                                         );
begin
Result:=-1;
if S<>'' then
   for I:=0 to AddrWordsCount do
       if (S=AddrWords[I])and(Length(S)=Length(AddrWords[I])) then
          begin
          Result:=I;
          Break;
          end;
end;


//------------------------------------------------------------------------------
// функция подсчета размера записи в буфере полей команд
function CalcFieldSize(Bits: Longint): Longint;
begin
if Bits<=0 then Result:=0
   else Result:=((Bits-1)shr 3)+257;
end;

//------------------------------------------------------------------------------
// Процедура добавления записи в буфер описания мнемоник поля команды
procedure AddToFieldBuffer(V: Extended; Vf: Boolean; var FieldName: String; var InstBuffer: TInstructionBuffer; FIndex: Longint; var ECode: Byte);
var
   A,B: Longint;
   Buff: array [0..15] of Byte;
   Sv: Single;
   Dv: Double;
begin
A:=InstBuffer.ISETBuffWidths[FIndex]*(InstBuffer.ISETBuffCounts[FIndex]+1);
ECode:=0;
if A>=InstBuffer.ISETBuffLengths[FIndex] then
   begin
   InstBuffer.ISETBuffLengths[FIndex]:=InstBuffer.ISETBuffWidths[FIndex]*(InstBuffer.ISETBuffCounts[FIndex]+50);
   ReallocMem(InstBuffer.ISETBuffs[FIndex],InstBuffer.ISETBuffLengths[FIndex]);
   end;
A:=InstBuffer.ISETBuffWidths[FIndex]*InstBuffer.ISETBuffCounts[FIndex];
B:=0;
if Vf then   // если операнд был записан как число с плавающей точкой
   if InstBuffer.ISETFieldSizes[FIndex]<>32 then B:=1
      else if InstBuffer.ISETFieldSizes[FIndex]<>64 then B:=2
           else if InstBuffer.ISETFieldSizes[FIndex]<>128 then B:=3
                else ECode:=61;
case B of
     0: if Power(2,InstBuffer.ISETFieldSizes[FIndex])<V then ECode:=39
           else ConvertToIntegerBuffer(V,Buff,ECode);        //для случая с целочисленными данными
     1: begin
        Sv:=V;
        Move(Sv,Buff[0],4);
        end;
     2: begin
        Dv:=V;
        Move(Dv,Buff[0],8);
        end;
     3: ConvertToFloatBuffer(V,Buff);
     end;
// после конвертации установка данных в буфере
FillChar(InstBuffer.ISETBuffs[FIndex][A],256,0);
for B:=1 to Length(FieldName) do InstBuffer.ISETBuffs[FIndex][A+B-1]:=Ord(FieldName[B]);
Move(Buff[0],InstBuffer.ISETBuffs[FIndex][A+256],InstBuffer.ISETBuffWidths[FIndex]-256);
InstBuffer.ISETBuffCounts[FIndex]:=InstBuffer.ISETBuffCounts[FIndex]+1;
end;

//------------------------------------------------------------------------------
// Процедура конвертации числа из расширенного формата в строку байт
procedure ConvertToIntegerBuffer(U: Extended;var Buff: array of Byte; var ECode: Byte);
var
   A,B,C,D: Longint;
begin
ECode:=0;
FillChar(Buff[0],16,#0);
if U<0 then if Abs(U)>(Power(2,127)-1) then ECode:=39;
if U>0 then if U>(Power(2,128)-1) then ECode:=39;
if ECode=0 then
   begin
   if U/Power(2,96)=Power(2,31) then A:=$80000000
                                else A:=Round(U/Power(2,96));
   U:=U-Power(2,96)*(Int(U/Power(2,96)));
   if U/Power(2,64)=Power(2,31) then B:=$80000000
                                else B:=Round(U/Power(2,64));
   U:=U-(Int(U/Power(2,64)))*Power(2,64);
   if U/Power(2,32)=Power(2,31) then C:=$80000000
                                else C:=Round(U/Power(2,32));
   U:=U-(Int(U/Power(2,32)))*Power(2,32);
   if U=Power(2,31) then D:=$80000000
                    else D:=Round(U);
   Buff[0]:=D;
   Buff[1]:=D shr 8;
   Buff[2]:=D shr 16;
   Buff[3]:=D shr 24;
   Buff[4]:=C;
   Buff[5]:=C shr 8;
   Buff[6]:=C shr 16;
   Buff[7]:=C shr 24;
   Buff[8]:=B;
   Buff[9]:=B shr 8;
   Buff[10]:=B shr 16;
   Buff[11]:=B shr 24;
   Buff[12]:=A;
   Buff[13]:=A shr 8;
   Buff[14]:=A shr 16;
   Buff[15]:=A shr 24;
   end;
end;

//------------------------------------------------------------------------------
// Процедура конвертации числа из расширенного формата в строку байт
procedure ConvertToFloatBuffer(V: Extended; var Buff: array of Byte);
var
   U: EXtended;
   Pnt: Pointer;
   W: Word;
   A,B: Longint;
begin
FillChar(Buff[0],16,#0);
U:=V;
Pnt:=Addr(U);
asm
mov  ebx,Pnt
mov  ax,[ebx+8]
mov  W,ax
mov  eax,[ebx]
mov  A,eax
mov  eax,[ebx+4]
mov  B,eax
end;
Buff[6]:=A;
Buff[7]:=A shr 8;
Buff[8]:=A shr 16;
Buff[9]:=A shr 24;
Buff[10]:=B;
Buff[11]:=B shr 8;
Buff[12]:=B shr 16;
Buff[13]:=B shr 24;
Buff[14]:=W;
Buff[15]:=W shr 8;
end;

//------------------------------------------------------------------------------
// Функция подсчета размера записи для мнемоники команды
function CalcMnemonicSize(Bits: Longint): Longint;
begin
if Bits<=0 then Result:=0
   else Result:=((Bits-1)shr 3)+513;
end;

//------------------------------------------------------------------------------
// Процедура удаления последних пробелов из строки
procedure RemoveLastSpaces(var Src: string);
var
   S: String;
   F: Boolean;
begin
S:=Src;
F:=false;
repeat
if Length(S)=0 then F:=true
   else if (S[Length(S)]<>#$20)and(S[Length(S)]<>#9) then F:=true
        else S:=Copy(S,1,Length(S)-1);
until F;
Src:=S;
end;

//------------------------------------------------------------------------------
// Процедура добавления очередной строки описания команды в буфер команд
procedure AddToMnemonicBuffer(V, Alv: Extended; Vf: Boolean;var MnemonicName: String; var FieldName: String; var InstBuffer: TInstructionBuffer; var ECode: Byte);
var
   A,B: Longint;
   Buff: array [0..15] of Byte;
   Sv: Single;
   Dv: Double;
begin
A:=InstBuffer.ISETMnemonicWidth*(InstBuffer.ISETMnemonicCount+1);
ECode:=0;
if A>=InstBuffer.ISETMnemonicLength then
   begin
   InstBuffer.ISETMnemonicLength:=InstBuffer.ISETMnemonicWidth*(InstBuffer.ISETMnemonicCount+50);
   ReallocMem(InstBuffer.ISETMnemonicBuffer,InstBuffer.ISETMnemonicLength);
   end;
A:=InstBuffer.ISETMnemonicWidth*InstBuffer.ISETMnemonicCount;
B:=0;
if Vf then   // если операнд был записан как число с плавающей точкой
   if InstBuffer.ISETMnemonicSize<>32 then B:=1
      else if InstBuffer.ISETMnemonicSize<>64 then B:=2
           else if InstBuffer.ISETMnemonicSize<>128 then B:=3
                else ECode:=61;
case B of
     0: ConvertToIntegerBuffer(V,Buff,ECode);
       //if Power(2,InstBuffer.ISETMnemonicSize)<V then ECode:=39
         //  else ConvertToIntegerBuffer(V,Buff,ECode);        //для случая с целочисленными данными
     1: begin
        Sv:=V;
        Move(Sv,Buff[0],4);
        end;
     2: begin
        Dv:=V;
        Move(Dv,Buff[0],8);
        end;
     3: ConvertToFloatBuffer(V,Buff);
     end;
// после конвертации установка данных в буфере
FillChar(InstBuffer.ISETMnemonicBuffer[A],256,0);
for B:=1 to Length(MnemonicName) do InstBuffer.ISETMnemonicBuffer[A+B-1]:=Ord(MnemonicName[B]);
FillChar(InstBuffer.ISETMnemonicBuffer[A+256],256,0);
for B:=1 to Length(FieldName) do InstBuffer.ISETMnemonicBuffer[A+B+255]:=Ord(FieldName[B]);
Move(Buff[0],InstBuffer.ISETMnemonicBuffer[A+512],16);
// конвертация кода выравнивания
ConvertToIntegerBuffer(Alv,Buff,ECode);
Move(Buff[0],InstBuffer.ISETMnemonicBuffer[A+512+16],16);

InstBuffer.ISETMnemonicCount:=InstBuffer.ISETMnemonicCount+1;
end;


//------------------------------------------------------------------------------
// Процедура записи в файл переменной набора описания систем команд
procedure SaveInstructionsCollection(S: String; var InstCollection: array of TInstructionBuffer);
var
   A,B,C: Longint;
   Buff: array [0..255] of Char;
begin
A:=FileCreate(S);
if A>0 then
   begin
   for B:=0 to 127 do
       begin
       FillChar(Buff[0],256,0);
       StrPCopy(Buff,InstCollection[B].ISETName);
       FileWrite(A,Buff[0],256);                 // запись названия буфера
       Move(InstCollection[B].ISETMnemonicLength,Buff[0],24);
       FileWrite(A,Buff[0],24);                             //запись параметров буфера мнемоники
       if InstCollection[B].ISETMnemonicCount<>0 then
          FileWrite(A,InstCollection[B].ISETMnemonicBuffer^,InstCollection[B].ISETMnemonicWidth*InstCollection[B].ISETMnemonicCount);
       for C:=0 to 127 do
           begin
           FillChar(Buff[0],256,0);
           StrPCopy(Buff,InstCollection[B].ISETFields[C]);
           FileWrite(A,Buff[0],256);
           FileWrite(A,InstCollection[B].ISETFieldLocs[C],4);
           FileWrite(A,InstCollection[B].ISETFieldSizes[C],4);
           FileWrite(A,InstCollection[B].ISETBuffCounts[C],4);
           FileWrite(A,InstCollection[B].ISETBuffWidths[C],4);
           if InstCollection[B].ISETBuffCounts[C]<>0 then
              FileWrite(A,InstCollection[B].ISETBuffs[C]^,InstCollection[B].ISETBuffCounts[C]*InstCollection[B].ISETBuffWidths[C]);
           end;
       end;
   FileClose(A);
   end;
end;


//------------------------------------------------------------------------------
// Процедура добавления записи в кросс-таблицу объекта
procedure AddToCrossBuffer(Indx: Longint; var ObjCollection: TObjectCollection; var Buff: array of Byte; Len: Longint);
begin
if Indx<2048 then
   begin
   if ObjCollection.CrossLengths[Indx]<=ObjCollection.CrossCounts[Indx]+Len then
      begin
      // Переустановка указателя буфера, если нет места
      ObjCollection.CrossLengths[Indx]:=ObjCollection.CrossLengths[Indx]+Len+4096;
      ReallocMem(ObjCollection.CrossDatas[Indx],ObjCollection.CrossLengths[Indx]);
      end;
   Move(Buff[0],ObjCollection.CrossDatas[Indx][ObjCollection.CrossCounts[Indx]],Len);
   ObjCollection.CrossCounts[Indx]:=ObjCollection.CrossCounts[Indx]+Len;
   end;
end;

//------------------------------------------------------------------------------
// Процедура проверки наличия команды, установленной в наборе команд для объекта
function CheckInstruction(var InstName: string; var ObjCollection: TObjectCollection; var InstCollection: array of TInstructionBuffer; ObjIndex: Longint): Boolean;
var
   S: String;
   A,B: Longint;
   Buff: array [0..255] of Char;
begin
Result:=false;
if (ObjIndex<2048)and(InstName<>'') then
   begin
   S:=StrPas(ObjCollection.ObjectSet[ObjIndex]);
   // поиск объекта с набором команд в списке наборов команд
   for A:=0 to 127 do
       if (S=InstCollection[A].ISETName)and(Length(S)=Length(InstCollection[A].ISETName)) then
          begin
          // если описываемый набор команд обнаружен
          S:=InstName;
          for B:=0 to InstCollection[A].ISETMnemonicCount-1 do
              begin
              Move(InstCollection[A].ISETMnemonicBuffer[B*InstCollection[A].ISETMnemonicWidth],Buff[0],256);
              if (S=StrPas(Buff))and(Length(S)=Length(StrPas(Buff))) then
                 begin
                 Result:=true;
                 Break;
                 end;
              end;
          Break;
          end;
   end;
end;

//------------------------------------------------------------------------------
// Процедура получения величины выравнивания
function GetInstructionAlignment(var InstName: string; var ObjCollection: TObjectCollection; var InstCollection: array of TInstructionBuffer; ObjIndex: Longint): Longint;
var
   A,B,C: Longint;
   Buff: array [0..255] of Char;
   S: String;

begin
Result:=0;
if (ObjIndex<2048)and(InstName<>'') then
   begin
   S:=StrPas(ObjCollection.ObjectSet[ObjIndex]);
   // поиск объекта с набором команд в списке наборов команд
   for A:=0 to 127 do
       if (S=InstCollection[A].ISETName)and(Length(S)=Length(InstCollection[A].ISETName)) then
          begin
          // если описываемый набор команд обнаружен
          S:=InstName;
          for B:=0 to InstCollection[A].ISETMnemonicCount-1 do
              begin
              Move(InstCollection[A].ISETMnemonicBuffer[B*InstCollection[A].ISETMnemonicWidth],Buff[0],256);
              if (S=StrPas(Buff))and(Length(S)=Length(StrPas(Buff))) then
                 begin
                 // обработка, если обнаружена мнемоника команды
                 Move(InstCollection[A].ISETMnemonicBuffer[512+16+B*InstCollection[A].ISETMnemonicWidth],C,4);
                 Result:=C;
                 Break;
                 end;
              end;
          Break;
          end;
   end;
end;

//------------------------------------------------------------------------------
// Процедура подсчета размера машинной команды в байтах
function GetInstructionLength(var InstName: string; var ObjCollection: TObjectCollection; var InstCollection: array of TInstructionBuffer; ObjIndex: Longint): Longint;
var
   S,T,U: String;
   A,B,C,M: Longint;
   Buff: array [0..255] of Char;
begin
Result:=0;
if (ObjIndex<2048)and(InstName<>'') then
   begin
   S:=StrPas(ObjCollection.ObjectSet[ObjIndex]);
   // поиск объекта с набором команд в списке наборов команд
   for A:=0 to 127 do
       if (S=InstCollection[A].ISETName)and(Length(S)=Length(InstCollection[A].ISETName)) then
          begin
          // если описываемый набор команд обнаружен
          S:=InstName;
          for B:=0 to InstCollection[A].ISETMnemonicCount-1 do
              begin
              Move(InstCollection[A].ISETMnemonicBuffer[B*InstCollection[A].ISETMnemonicWidth],Buff[0],256);
              if (S=StrPas(Buff))and(Length(S)=Length(StrPas(Buff))) then
                 begin
                 // обработка, если обнаружена мнемоника команды
                 M:=GetInstructionAlignment(InstName, ObjCollection, InstCollection, ObjIndex);
                 if M<>0 then Result:=M
                    else begin
                    // установка максимального значения старшего бита в команде
                    M:=InstCollection[A].ISETMnemonicLoc+InstCollection[A].ISETMnemonicSize;
                    Move(InstCollection[A].ISETMnemonicBuffer[256+B*InstCollection[A].ISETMnemonicWidth],Buff[0],256);
                    T:=StrPas(Buff);
                    while T<>'' do
                       begin
                       RemoveFirstSpaces(T);
                       GetWord(T,U);
                       for C:=0 to 127 do
                           if InstCollection[A].ISETFields[C]='' then Break
                              else if (U=InstCollection[A].ISETFields[C])and(Length(U)=Length(InstCollection[A].ISETFields[C])) then
                                   begin
                                   if M<(InstCollection[A].ISETFieldLocs[C]+InstCollection[A].ISETFieldSizes[C]) then M:=InstCollection[A].ISETFieldLocs[C]+InstCollection[A].ISETFieldSizes[C];
                                   Break;
                                   end;
                       end;
                    Result:=1+((M-1)shr 3);
                    end;
                 Break;
                 end;
              end;
          Break;
          end;
   end;
end;

//------------------------------------------------------------------------------
// Функция возврата типа слова, определенного в строке
function GetCompilerWordType(V: string): Longint;
var
   A: Longint;
   B: Longint;
   S: String;
begin
S:=V;
Result:=-1;
A:=0;                           //проверка сначала среди числовых значений
if CheckBool(S) then B:=0
 else if CheckOct(S) then B:=1
  else if CheckInt(S) then B:=2
   else if CheckHex(S) then B:=3
    else if CheckFlt(S) then B:=4
     else begin
     A:=1;                     //указатель, что это символ
     B:=CheckSymbol(S);
     if B=-1 then
        begin          //если это не число и не символ и не программная точка
        // проверка среди служебных операторов, используемых для определения данных
        A:=2;
        B:=CheckDataOperator(S);
        if B=-1 then
           begin
           // проверка среди служебных слов, используемых в исходных текстах программ
           A:=3;
           B:=CheckReservedWord(S);
           if B=-1 then
              begin
              // проверка на математический оператор
              A:=4;
              B:=GetOpr(S);
              if B=255 then B:=-1;
              if B=-1 then
                 begin
                 A:=6;
                 B:=CheckAddressOperator(S);
                 end;
              end;
           end;
        end;
     end;
if B>=0 then Result:=(A shl 8)or B;
end;

//------------------------------------------------------------------------------
// Процедура возврата смещения метки данных
// или программного кода из кросс-таблицы объекта
function GetLabelOffset(var LName: string; var ObjCollection: TObjectCollection; Indx: Longint): Longint;
var
   A,B: Longint;
   S,T: String;
begin
Result:=-1;
A:=0;
S:=LName;
if S<>'' then
   if Indx<4096 then
      while A<ObjCollection.CrossCounts[Indx] do
            begin
            if (ObjCollection.CrossDatas[Indx][A+4]=1)or(ObjCollection.CrossDatas[Indx][A+4]=2) then
               begin
               T:=StrPas(Addr(ObjCollection.CrossDatas[Indx][A+5]));
               if (T=S)and(Length(S)=Length(T)) then
                  begin
                  Move(ObjCollection.CrossDatas[Indx][A+6+Length(T)],B,4);
                  Result:=B;
                  Break;
                  end;
               end;
            // продвижение указателя
            Move(ObjCollection.CrossDatas[Indx][A],B,4);
            A:=A+B;
            end;
end;

//------------------------------------------------------------------------------
// Функция выравнивания указателя позиции в объекте на фиксированную величину
procedure AlignPointer(var Ptr: Longint; V: Longint);
var
   A: Longint;
begin
if V<>0 then
   if Frac(Ptr/V)<>0 then
      begin
      A:=Ptr div V;
      Inc(A);
      Ptr:=A*V;
      end;
end;

//------------------------------------------------------------------------------
// процедура переустановки счетчика в соответствии с разрядностью элементов данных
procedure IncrementCounter(BuffSize: Longint; DataSize: Longint; var Ptr: Longint);
begin
if Frac(DataSize/BuffSize)<>0.0 then Ptr:=Ptr+Round(Int(DataSize/BuffSize))+1
                                else Ptr:=Ptr+(DataSize div BuffSize);
end;



//------------------------------------------------------------------------------
//   Процедура заполнения массива байт определенным числом
//------------------------------------------------------------------------------
procedure FillByte(Buff: PP; Displ, Cnt: Longint; Dt: Byte);
var
   A: Pointer;
begin
A:=Addr(Buff[0]);
asm
pushad
pushfd
      mov edi,A
      mov eax,Displ
      add edi,eax
      mov ecx,Cnt
      cld
      mov al,Dt
      rep stosb
popfd
popad
end;
end;

//------------------------------------------------------------------------------
//процедура сдвига буфера
procedure ShiftBuffer(var Buff: PP; var Cnt: Longint; var Depth: Longint);
var
   A,B,C,Sz: Longint;
   Msk: Int64;
   BF: array [0..7] of Byte;
begin
Msk:=0;
A:=Depth;
while A<>0 do
      begin
      Msk:=(Msk shl 1) or 1;
      Dec(A);
      end;
Move(Msk,BF,8);
if (Buff<>nil)and(Cnt>0) then
   begin
   Move(Buff[0],Sz,4);
   if Sz>=8 then B:=7
            else B:=Sz-1;
   for A:=0 to B do Buff[4+A]:=Buff[4+A] and BF[A];
   if Sz>0 then
      for A:=1 to Cnt do
          begin
          C:=0;
          for B:=0 to Sz-1 do
              begin
              C:=(C and 1)or(Buff[B+4] shl 1);
              Buff[B+4]:=C and 255;
              C:=C shr 8;
              end;
          end;
   end;
end;


//------------------------------------------------------------------------------
// процедура добавления блока данных в буфер бинарных данных
//------------------------------------------------------------------------------
procedure AddToBinaryBuffer(var Indx,Ptr: Longint; var ObjCollection: TObjectCollection; var Buff: PP; var SrcBuff: TDataBuffer; var Line: LongInt);
var
   A,B: Longint;
   APtr, BPtr: Pointer;
   Strings: TStringList;
   S,T: String;
begin
if Buff<>nil then
   begin
   Move(Buff[0],A,4);
   if A+Ptr>=ObjCollection.BinaryLengths[Indx] then
      begin
      ObjCollection.BinaryLengths[Indx]:=Ptr+A+1024;
      ReallocMem(ObjCollection.BinaryDatas[Indx],ObjCollection.BinaryLengths[Indx]);
      // очистка впереди идущих ячеек
      FillChar(ObjCollection.BinaryDatas[Indx][Ptr],A+1024,0);
      end;
   APtr:=Addr(Buff[0]);
//   BPtr:=Addr(BinCollection.BinaryDatas[Indx][BinCollection.BinaryCounts[Indx]]);
   BPtr:=Addr(ObjCollection.BinaryDatas[Indx][Ptr]);
   asm
      pushad
      mov  esi,APtr
      add  esi,4
      mov  edi,BPtr
      mov  ecx,A
      cld
      rep movsb
      popad
   end;
   ObjCollection.BinaryCounts[Indx]:=Ptr+A;
   // запись данных в блок листинга
   Strings:=TStringList.Create;
   // попытка вычитать имя метки по адресу
   S:=GetLabelNameByAddress(ObjCollection,Indx,Ptr);
   if S<>'' then
      begin
      Strings.Add(' ');
      Strings.Add(S+':');
      end;
   T:=GetSourceLineFromSource(SrcBuff,Line);
   S:=IntToHex(Ptr,8)+'/'+IntToHex(Ptr div ObjCollection.ObjectGran[Indx],8)+'  ';
   B:=0;
   while B<>A do
         begin
         S:=S+IntToHex(Buff[B+4],2)+' ';
         inc(B);
         if (B and 15)=0 then
            begin
            Strings.Add(S+'  '+T);
            S:='                    ';
            T:='';
            end;
         end;
   //S:=S+#13+#10;
   if T<>'' then
      begin
      if Length(S)<70 then for B:=1 to 70-Length(S) do S:=S+' ';
      S:=S+T;
      end;
   Strings.Add(S);
   // подсчет длины получившегося фрагмента текста
   A:=0;
   for B:=0 to Strings.Count-1 do A:=A+Length(Strings[B])+2;
   // проверка размера буфера листинга
   if A+ObjCollection.ListCounts[Indx]>=ObjCollection.ListLengths[Indx] then
      begin
      ObjCollection.ListLengths[Indx]:=ObjCollection.ListLengths[Indx]+A+4096;
      ReallocMem(ObjCollection.ListDatas[Indx],ObjCollection.ListLengths[Indx]);
      end;
   // копирование данных из строк в буфер
   for A:=0 to Strings.Count-1 do
       begin
       S:=Strings[A]+#13+#10;
       for B:=1 to Length(S) do ObjCollection.ListDatas[Indx][ObjCollection.ListCounts[Indx]+B-1]:=Ord(S[B]);
       ObjCollection.ListCounts[Indx]:=ObjCollection.ListCounts[Indx]+Length(S);
       end;
   Strings.Free;
   end;
end;

//------------------------------------------------------------------------------
//Процедура объединения двух буферов по AND
//------------------------------------------------------------------------------
procedure ORBuffer(var Dst: PP; var Src: PP);
var
   A,B: Longint;
begin
Move(Dst[0],A,4);
Move(Src[0],B,4);
if B<A then A:=B;
if A>0 then
   while A<>0 do
         begin
         Dst[3+A]:=Src[3+A] or Dst[3+A];
         Dec(A);
         end;
end;


//------------------------------------------------------------------------------
// Процедура установки величины в буфер
//------------------------------------------------------------------------------
procedure SetValueToBuffer(Buff: PP; I: Longint; Tp: Longint; V: Extended; var ECode: Longint);
var
   A,B,C,D: Longint;
   W: Word;
   U: Extended;
   LI: Int64;
   X: Single;
   Y: Double;
   Pnt: Pointer;
begin
ECode:=-1;
U:=Int(V);
case Tp of
     //для байтового операнда
     0: begin
        Buff[I]:=0;
        Buff[I]:=Round(U)and 255;
        end;
     //для 16-разрядного операнда
     1: begin
        FillChar(Buff[I],2,#0);
        Buff[I]:=Round(U)and 255;
        Buff[I+1]:=(Round(U)shr 8)and 255;
        end;
     //для 32-разрядного операнда
     2: begin
        FillChar(Buff[I],4,#0);
        Buff[I]:=Round(U)and 255;
        Buff[I+1]:=(Round(U)shr 8)and 255;
        Buff[I+2]:=(Round(U)shr 16)and 255;
        Buff[I+3]:=(Round(U)shr 24)and 255;
        end;
     //для 64-разрядного операнда
     3: begin
        Pnt:=Addr(LI);
        LI:=Round(U);
        asm
        mov  ebx,Pnt
        mov  eax,[ebx]
        mov  A,eax
        mov  eax,[ebx+4]
        mov  B,eax
        end;
        Buff[I]:=A and 255;
        Buff[I+1]:=(A shr 8)and 255;
        Buff[I+2]:=(A shr 16)and 255;
        Buff[I+3]:=(A shr 24)and 255;
        Buff[I+4]:=B and 255;
        Buff[I+5]:=(B shr 8)and 255;
        Buff[I+6]:=(B shr 16)and 255;
        Buff[I+7]:=(B shr 24)and 255;

{        FillChar(Buff[I],8,#0);
        if Abs(U)<Power(2,32) then A:=0
           else if U/Power(2,32)=Power(2,31) then A:=$80000000
                else A:=Round(Int(U/Power(2,32)));
        Buff[I]:=Round(U-A*Power(2,32))and 255;
        Buff[I+1]:=(Round(U-(Int(U/Power(2,32)))*Power(2,32))shr 8)and 255;
        Buff[I+2]:=(Round(U-(Int(U/Power(2,32)))*Power(2,32))shr 16)and 255;
        Buff[I+3]:=(Round(U-(Int(U/Power(2,32)))*Power(2,32))shr 24)and 255;
        Buff[I+4]:=A and 255;
        Buff[I+5]:=(A shr 8)and 255;
        Buff[I+6]:=(A shr 16)and 255;
        Buff[I+7]:=(A shr 24)and 255;}
        end;
        //обработка для 128-разрядного операнда
     4: begin
        FillChar(Buff[I],16,#0);
        if U/Power(2,96)=Power(2,31) then A:=$80000000
           else A:=Round(U/Power(2,96));
        U:=U-Power(2,96)*(Int(U/Power(2,96)));
        if U/Power(2,64)=Power(2,31) then B:=$80000000
           else B:=Round(U/Power(2,64));
        U:=U-(Int(U/Power(2,64)))*Power(2,64);
        if U/Power(2,32)=Power(2,31) then C:=$80000000
           else C:=Round(U/Power(2,32));
        U:=U-(Int(U/Power(2,32)))*Power(2,32);
        if U=Power(2,31) then D:=$80000000
           else D:=Round(U);
        Buff[I]:=D and 255;
        Buff[I+1]:=(D shr 8)and 255;
        Buff[I+2]:=(D shr 16)and 255;
        Buff[I+3]:=(D shr 24)and 255;
        Buff[I+4]:=C and 255;
        Buff[I+5]:=(C shr 8)and 255;
        Buff[I+6]:=(C shr 16)and 255;
        Buff[I+7]:=(C shr 24)and 255;
        Buff[I+8]:=B and 255;
        Buff[I+9]:=(B shr 8)and 255;
        Buff[I+10]:=(B shr 16)and 255;
        Buff[I+11]:=(B shr 24)and 255;
        Buff[I+12]:=A and 255;
        Buff[I+13]:=(A shr 8)and 255;
        Buff[I+14]:=(A shr 16)and 255;
        Buff[I+15]:=(A shr 24)and 255;
        end;
     //обработка, если формат 32-разрядный с плавающей точкой
     5: begin
        try
        X:=V;
        except
        on EOverflow do ECode:=43;
        end;
        asm
        mov  eax,X
        mov  A,eax
        end;
        Buff[I]:=A and 255;
        Buff[I+1]:=(A shr 8)and 255;
        Buff[I+2]:=(A shr 16)and 255;
        Buff[I+3]:=(A shr 24)and 255;
        end;
     //обработка, если 64-разрядный формат с плавающей точкой
     6: begin
        try
        Y:=V;
        except
        on EOverflow do ECode:=43;
        end;
        Pnt:=Addr(Y);
        asm
        mov  ebx,Pnt
        mov  eax,[ebx]
        mov  A,eax
        mov  eax,[ebx+4]
        mov  B,eax
        end;
        Buff[I]:=A and 255;
        Buff[I+1]:=(A shr 8)and 255;
        Buff[I+2]:=(A shr 16)and 255;
        Buff[I+3]:=(A shr 24)and 255;
        Buff[I+4]:=B and 255;
        Buff[I+5]:=(B shr 8)and 255;
        Buff[I+6]:=(B shr 16)and 255;
        Buff[I+7]:=(B shr 24)and 255;
        end;
     //Обработка, если формат 128 разрядного с плавающей точкой
     7: begin
        FillChar(Buff[I],16,#0);
        U:=V;
        Pnt:=Addr(U);
        asm
        mov  ebx,Pnt
        mov  ax,[ebx+8]
        mov  W,ax
        mov  eax,[ebx]
        mov  A,eax
        mov  eax,[ebx+4]
        mov  B,eax
        end;
        Buff[I+6]:=A and 255;
        Buff[I+7]:=(A shr 8)and 255;
        Buff[I+8]:=(A shr 16)and 255;
        Buff[I+9]:=(A shr 24)and 255;
        Buff[I+10]:=B and 255;
        Buff[I+11]:=(B shr 8)and 255;
        Buff[I+12]:=(B shr 16)and 255;
        Buff[I+13]:=(B shr 24)and 255;
        Buff[I+14]:=W and 255;
        Buff[I+15]:=(W shr 8)and 255;
        end;
     end;
end;

//------------------------------------------------------------------------------
// Рекурсивная процедура обработки адресной переменной
//------------------------------------------------------------------------------
{function ConvertAddressEquation(var AType: Longint;                    // тип адресного указателя, который требуется обработать
                                    var Equ: String;                   // выражение в текстовой форме
                                    var DBuff: PP;                     // буфер для установки результатов компиляции
                                    var Indx: Longint;                 // Индекс позиции в буфере, для занесения результата компиляции
                                    var Sel: Longint;                  // указатель на буфер в ObjCollection
                                    var Ptr: Longint;                  // указатель данных, для первого байта буфера
                                    var Obj: Longint;                  // индекс в ObjCollection
                                    var ObjCollection: TObjectCollection): Byte;
var
   Eb: Byte;
   A,B,C: Longint;
   S,T: String;
   BBytes: array [0..511] of Byte;
   F: Boolean;
   Ext: Extended;
begin
// Indx всегда указывает на позицию в объекте, начиная с которой требуется
// записывать смещения и приращения адресов
// проверка возможности размещения элемента в буфере данных
Eb:=0;
if DBuff<>nil then
   begin
   A:=4;
   case AType of
        0,1,5: A:=Indx+2;               // 2 байта минимум должно быть или смещение или селектор или относительное смещение
        2,3:   A:=Indx+8;               // 8 байт смещение и селектор
        4:     A:=Indx+12;              // 12 байт для векторного указателя
        end;
   Move(DBuff[0],B,4);              // длина буфера
   if B<A then Eb:=76
      else begin
      // если можно производить обработку
      RemoveFirstSpaces(Equ);
      if Equ='' then Eb:=80
         else case AType of
              // обработка для смещения к метке или переменной
              0: begin
                 GetWord(Equ,S);
                 RemoveFirstSpaces(Equ);
                 // в оставшейся строке могут быть данные, если в S имя объекта
                 A:=Sel;                // начальное значение селектора
                 if Equ[1]=':' then
                    begin
                    // Обработка, если определяется смещение в другом объекте
                    Delete(Equ,1,1);
                    GetWord(Equ,T);
                    // определение значения нового селектора
                    A:=GetCrossTableByObjectName(S,ObjCollection);
                    S:=T;
                    end;
                 if A<0 then Eb:=78
                    else if S='' then Eb:=59
                         else begin
                         // если можно правильно обработать метку
                         B:=GetLabelOffset(S,ObjCollection,A);
                         S:=IntToStr(B)+Equ;
                         Eb:=ConvertExpression(S,Ext);
                         B:=Trunc(Ext/ObjCollection.ObjectGran[Obj]);
                         Move(B,DBuff[4+Indx],4);
                         end;
                 end;
              // обработка для селектора объекта
              1: begin
                 GetWord(Equ,S);
                 RemoveFirstSpaces(Equ);
                 C:=Ptr+Indx;           // точка размещения селектора
                 if S='' then Eb:=59
                    else if Equ<>'' then Eb:=62
                         else begin
                         // если можно обрабатывать селектор
                         T:=S;
                         F:=false;
                         for A:=0 to 2047 do
                             if (T=StrPas(ObjCollection.ObjectName[A]))and(Length(T)=Length(StrPas(ObjCollection.ObjectName[A]))) then
                                begin
                                B:=ObjCollection.ObjectOwner[A];
                                while ObjCollection.ObjectOwner[B]<>-1 do
                                      begin
                                      T:=StrPas(ObjCollection.ObjectName[B])+'/'+T;
                                      B:=ObjCollection.ObjectOwner[B];
                                      end;
                                F:=true;
                                Break;
                                end;
                         if not F then Eb:=78
                            else begin
                            B:=Length(T)+10;
                            FillChar(BBytes[0],B,0);
                            Move(B,BBytes[0],4);
                            StrPCopy(Addr(BBytes[5]),T);
                            Move(C,BBytes[Length(T)+6],4);
                            BBytes[4]:=4;
                            AddToCrossBuffer(Sel,ObjCollection,BBytes,B);
                            end;
                         end;
                 end;
              // обработка для скалярного указателя
              2: begin
                 S:=Equ;
                 if Pos(':',S)=0 then Eb:=80
                    else begin
                    A:=0;
                    Eb:=ConvertAddressEquation(A,S,DBuff,Indx,Sel,Ptr,Obj,ObjCollection);
                    if Eb=0 then
                       begin
                       // вторым шагом - обработка селектора
                       S:=Copy(S,1,Pos(':',S)-1);
                       A:=1;
                       B:=Indx+4;
                       Eb:=ConvertAddressEquation(A,S,DBuff,B,Sel,Ptr,Obj,ObjCollection);
                       end;
                    end;
                 end;
              // Обработка для векторного смещения или векторного указателя
              3,4: begin
                   S:=Equ;
                   if Pos(',',S)=0 then Eb:=80
                      else begin
                      // если есть необходимые части выражения
                      T:=Copy(S,1,Pos(',',S)-1);
                      if AType=3 then A:=0
                                 else A:=2;
                      Eb:=ConvertAddressEquation(A,T,DBuff,Indx,Sel,Ptr,Obj,ObjCollection);
                      if Eb=0 then
                         begin
                         // конвертация приращения адреса
                         Delete(S,1,Pos(',',S));
                         Eb:=ConvertExpression(S,Ext);
                         if Eb=0 then
                            begin
                            if AType=3 then SetValueToBuffer(DBuff,Indx+8,2,Ext,A)
                                       else SetValueToBuffer(DBuff,Indx+12,2,Ext,A);
                            if A<>-1 then Eb:=A;
                            end;
                         end;
                      end;
                   end;
              // обработка для разницы между смещениями
              5: begin
                 S:=Equ;
                 if Pos(',',S)<>0 then T:=Copy(S,1,Pos(',',S)-1)
                                  else T:=S;
                 A:=GetLabelOffset(T,ObjCollection,Sel);
                 if A=-1 then Eb:=79
                    else begin
                    B:=Ptr;
                    if Pos(',',S)<>0 then
                       begin
                       Delete(S,1,Pos(',',S));
                       T:=S;
                       B:=GetLabelOffset(T,ObjCollection,Sel);
                       end;
                    if B=-1 then Eb:=79
                       else begin
                       A:=Trunc((A-B)/ObjCollection.ObjectGran[Obj]);
                       Move(A,DBuff[4+Indx],4);
                       end;
                    end;
                 end;
              end;
      end;
   end;
ConvertAddressEquation:=Eb;
end;}


//------------------------------------------------------------------------------
// Функция возврата номера бинарной таблицы объекта по его имени
//------------------------------------------------------------------------------
function GetCrossTableByObjectName(var Name: String; var ObjCollection: TObjectCollection): Longint;
var
   A: Longint;
begin
Result:=-1;
if Name<>'' then
   for A:=0 to 2047 do
       if (Name=StrPas(ObjCollection.ObjectName[A]))and(Length(Name)=Length(StrPas(ObjCollection.ObjectName[A]))) then
          begin
          // если объект обнаружен
          Result:=A;
          Break;
          end;
end;


//------------------------------------------------------------------------------
// Выборка набора параметров переменной по ее имени из кросс-таблицы
//------------------------------------------------------------------------------
function GetVariableParameters(var VName: string;var ObjCollection: TObjectCollection; var BinIndex: Longint; var VOffset: Longint;var VLength: Longint;var VType: Byte): Boolean;
var
   A,B: Longint;
   S: String;
begin
A:=0;
Result:=false;
while A<>ObjCollection.CrossCounts[BinIndex] do
      begin
      Move(ObjCollection.CrossDatas[BinIndex][A],B,4);  // длина очередной записи
      S:=StrPas(Addr(ObjCollection.CrossDatas[BinIndex][A+5])); // название записи
      if ObjCollection.CrossDatas[BinIndex][A+4]=2 then
         if (S=VName)and(Length(S)=Length(VName)) then
            begin
            // если переменная обнаружена в списке
            Move(ObjCollection.CrossDatas[BinIndex][A+Length(S)+6],VOffset,4);
            Move(ObjCollection.CrossDatas[BinIndex][A+Length(S)+10],VLength,4);
            VType:=ObjCollection.CrossDatas[BinIndex][A+Length(S)+14];
            Result:=true;
            Break;
            end;
      A:=A+B;
      end;
end;


//------------------------------------------------------------------------------
// Получение имени метки по адресу
//------------------------------------------------------------------------------
function GetLabelNameByAddress(var ObjCollection: TObjectCollection; var Indx,Ptr: LongInt): string;
var
   A,B,C,D: Longint;
   S: String;
begin
A:=0;
S:='';
D:=5;
while (A<ObjCollection.CrossCounts[Indx])and(S='') do
      begin
      Move(ObjCollection.CrossDatas[Indx][A],B,4);
      if ObjCollection.CrossDatas[Indx][A+4]=1 then
         begin
         // если найдена метка
         Move(ObjCollection.CrossDatas[Indx][A+B-4],C,4);
         if C=Ptr then
            while ObjCollection.CrossDatas[Indx][A+D]<>0 do
                  begin
                  S:=S+Chr(ObjCollection.CrossDatas[Indx][A+D]);
                  Inc(D);
                  end;
         end;
      A:=A+B;
      end;
result:=S;
end;

end.
