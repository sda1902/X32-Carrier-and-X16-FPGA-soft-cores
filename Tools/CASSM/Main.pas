unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, ExtCtrls, CompMsg, Structures, Subprog, IniFiles;

type
  TMainForm = class(TForm)
    Panel1: TPanel;
    Label1: TLabel;
    SourceBtn: TButton;
    MsgBox: TListBox;
    RunBtn: TButton;
    StopBtn: TButton;
    MainStatus: TStatusBar;
    MainTimer: TTimer;
    OpenDlg: TOpenDialog;
    SourceEdit: TComboBox;
    procedure FormResize(Sender: TObject);
    procedure SourceEditChange(Sender: TObject);
    procedure SourceBtnClick(Sender: TObject);
    procedure RunBtnClick(Sender: TObject);
    procedure OutMessage(MsgType: Byte;   // идентификатор типа сообщения
                    MsgIndex: Byte;   // идентификатор самого сообщения
                    SrcLineId: LongInt; // номер строки текста в буфере исходного текста
                    MsgText: String;
                    var EFlag: Boolean);
    function LoadSrcLines(SrcFileName: String): Boolean;
    procedure RdString(Buff: PP; BLength: Longint; var BPtr: Longint; var S: String; var Lnum: Longint);
    function ExtractObjects: Boolean;
    function ProcessDefinitions: Boolean;
    function LoadInstructionReferences: Boolean;
    function CrossProcessor: Boolean;
    function AssmProcessor: Boolean;
    procedure InitDataBuffers;
    procedure FormCreate(Sender: TObject);
    function CompileInstruction(var V: String;var Obj: Longint;var Sel: Longint;var Buff: PP;var Lnumber: Longint;var Ptr: Longint): Boolean;
    function CompileDatas(var SLine: Longint; var ObjIndex: Longint; var Buff: PP; var Ptr: Longint): Boolean;
    function CreateSoftObjectFiles: Boolean;
    procedure MainTimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

  SrcBuffer:  TDataBuffer;          // буфер строк исходного текста
  ObjectCollection: TObjectCollection;  //список созданных объектов
  InstCollection: array [0..127] of TInstructionBuffer; //список объектов описания системы команд

  FileList: TStringList;           // список прочитанных файлов

  EFlag: Boolean;

implementation

{$R *.dfm}


// Изменение размеров окна
procedure TMainForm.FormResize(Sender: TObject);
begin
SourceBtn.Left:=Width-196;
RunBtn.Left:=Width-164;
StopBtn.Left:=Width-92;
SourceEdit.Width:=Width-275;
end;

// обработка изменения состояния имени файла
procedure TMainForm.SourceEditChange(Sender: TObject);
begin
RunBtn.Enabled:=SourceEdit.Text<>'';
end;

// Обработка окрытия диалога для выбора файла
procedure TMainForm.SourceBtnClick(Sender: TObject);
begin
if OpenDlg.Execute then SourceEdit.Text:=OpenDlg.FileName;
SourceEditChange(Sender);
end;


// Обработка запуска процесса компиляции
procedure TMainForm.RunBtnClick(Sender: TObject);
var
   A,B: Longint;
   F: Boolean;
   S: String;
begin
Screen.Cursor:=crHourGlass;
StopBtn.Enabled:=true;
StopBtn.Tag:=0;
MainTimer.Tag:=0;
MainTimer.Enabled:=true;
MsgBox.Clear;
// проверка наличия строки в списке
F:=false;
if SourceEdit.Items.Count<>0 then
   for A:=0 to SourceEdit.Items.Count-1 do
       if (Pos(SourceEdit.Text, SourceEdit.Items[A])=1)and(Length(SourceEdit.Text)=Length(SourceEdit.Items[A])) then F:=true;
if not F then SourceEdit.Items.Add(SourceEdit.Text);

EFlag:=false;
OutMessage(0,0,-1,'',EFlag);
S:=SourceEdit.Text;
B:=0;
for A:=1 to Length(S) do if S[A]='\' then B:=A;
if B<>0 then
   begin
   S:=Copy(S,1,B-1);
   SetCurrentDir(S);
   end;

// инициализация буферов данных
SrcBuffer.BuffPtr:=nil;
SrcBuffer.BuffLength:=0;
SrcBuffer.BuffCount:=0;
StrPCopy(SrcBuffer.BuffName,SourceEdit.Text);

// инициализация списка файлов
FileList:=TStringList.Create;

InitDataBuffers;

// запуск процедуры загрузки исходных строк текста
if not LoadSrcLines(SourceEdit.Text) then OutMessage(3,4,-1,'',EFlag)
   else if not ProcessDefinitions then OutMessage(3,3,-1,'',EFlag)
        else if not ExtractObjects then OutMessage(3,3,-1,'',EFlag)
             else if not LoadInstructionReferences then OutMessage(3,3,-1,'',EFlag)
                  else if not CrossProcessor then OutMessage(3,3,-1,'',EFlag)
                       else if not AssmProcessor then OutMessage(3,3,-1,'',EFlag)
                            else begin
                            CreateSoftObjectFiles;
                            // запись списка выделенных объектов
                            S:=ChangeFileExt(SourceEdit.Text,'.obj');
                            SaveObjects(ObjectCollection,S);
                            // тестовая запись файла определения системы команд
                            //SaveInstructionsCollection('instcollection.INST',InstCollection);
                            // тестовая запись исходных строк в файл
                            //SaveDataBuffer(SrcBuffer,'src.dat');
                            end;

// запись в файл списка сообщений компилятора
S:=ChangeFileExt(SourceEdit.Text,'.log');
MsgBox.Items.SaveToFile(S);

//SaveSourceBuffer(SrcBuffer,'src.txt');
// Завершение работы компилятора
//ShutdownDataBuffers(ProgCtrl,DTCollection,BinaryCollection);
//FreeBPDLCollection(BPDLCollection);

if SrcBuffer.BuffLength>0 then FreeMem(SrcBuffer.BuffPtr);
//MessageSystemShutdown(MsgBuffer);
InitDataBuffers;

OutMessage(0,5,-1,'',EFlag);
FileList.Free;
MainTimer.Enabled:=False;
MainStatus.Panels[0].Text:='';
StopBtn.Enabled:=false;
Screen.Cursor:=crDefault;
end;


//
//    Обработка вывода сообщения в список
//
procedure TMainForm.OutMessage(MsgType: Byte; MsgIndex: Byte; SrcLineId: LongInt; MsgText: String; var EFlag: Boolean);
var
   A: LongInt;
  S: String;
begin
// вывод типа сообщения
S:=TypeStrings[MsgType and 3];
// вывод расшифровки сообщения
case (MsgType and 3) of
    0: S:=S+InfoStrings[MsgIndex];
    1: S:=S+WarningStrings[MsgIndex];
    2: S:=S+ErrorStrings[MsgIndex];
    3: S:=S+FatalStrings[MsgIndex];
    end;
// вывод имени файла исходного текста
if SrcLineId>=0 then
   begin
   Move(SrcBuffer.BuffPtr[SrcLineId shl 8],A,4);
   S:=S+' '+FileList.Strings[A shr 24]+' Line:'+IntToStr(A and $0FFFFFF);
   end;
// вывод номера строки исходного текста
// добавление строки в список
MsgBox.Items.Add(S+' '+MsgText);
MsgBox.Refresh;
EFlag:=EFlag or ((MsgType and 3)>1);
end;


//
//    Обработка загрузки строк исходного текста в буфер
//
function TMainForm.LoadSrcLines(SrcFileName: String): Boolean;
var
  A, B, D, I, LNum: Longint;
  FileIndex: Byte;
  TmpBuff: PP;
  S, InFile: String;
  SrcString: array [0..255] of Byte;
  F: Boolean;
begin
LNum:=0;
A:=FileOpen(SrcFileName,fmOpenRead);
if A<=0 then OutMessage(3,0,-1,SrcFileName,EFlag) // если файл нормально не открылся
  else begin
  OutMessage(0,1,-1,SrcFileName,EFlag);               // сообщение о начале загрузки файла
  FileList.Add(SrcFileName);
  FileIndex:=FileList.Count-1;
  // вычитывание параметров файла и распределение буфера
  B:=FileSeek(A,0,2);
  GetMem(TmpBuff,B+16);
  FileSeek(A,0,0);
  if B<>FileRead(A,TmpBuff^,B)
    then begin
         OutMessage(3,1,-1,SrcFileName,EFlag);
         FileClose(A);
         end
    // если файл нормально прочелся
    else begin
         FileClose(A);
         A:=0;              // указатель чтения буфера исходного файла
         D:=0;
         while A<B do
               begin
               Application.ProcessMessages;
               if StopBtn.Tag<>0 then break;
               // Обработка формирования строк исходного текста
               RdString(TmpBuff,B,A,S,LNum);
               if Length(S)>1 then
                  begin
                  if Length(S)>250 then OutMessage(2,23,LNum,SrcFileName,EFlag) // вывод сообщения о недопустимой длине строки
                     else if Pos('INCLUDE ',S)<>1
                             then begin
                                  // обработка установки строки в буфере
                                  FillChar(SrcString,256,0);
                                  SrcString[0]:=LNum;
                                  SrcString[1]:=LNum shr 8;
                                  SrcString[2]:=LNum shr 16;
                                  SrcString[3]:=FileIndex;
                                  SrcString[4]:=$FF;
                                  SrcString[5]:=$FF;
                                  for I:=1 to Length(S) do SrcString[I+5]:=Ord(S[I]);
                                  AddToSourceBuffer(SrcString,SrcBuffer,F);
                                  Inc(D);
                                  if F then
                                     begin
                                     OutMessage(4,6,-1,'',EFlag);
                                     Break;
                                     end;
                                  end
                             else begin
                                  // Обработка, если декларировано вложение файла
                                  Delete(S,1,Pos(' ',S));
                                  if Length(S)<=1 then OutMessage(2,65,LNum,SrcFileName,EFlag)
                                     else begin
                                     S:=S+',';
                                     while S<>'' do
                                           begin
                                           InFile:='';
                                           while S[1]=' ' do Delete(S,1,1);
                                           if FileExists(Copy(S,1,Pos(',',S)-1)) then InFile:=Copy(S,1,Pos(',',S)-1)
                                                                                 else OutMessage(3,15,-1,Copy(S,1,Pos(',',S)-1),EFlag); // указанный файл не обнаружен
                                           if InFile<>'' then
                                              begin
                                              LoadSrcLines(InFile);
                                              //OutMessage(0,2,-1,SrcFileName,EFlag);
                                              end;
                                           Delete(S,1,Pos(',',S));
                                           end;
                                     end;
                                  end;
                  end;
               end;
         if D=0 then OutMessage(1,0,-1,SrcFileName,EFlag)
                else OutMessage(0,11,-1,IntToStr(D),EFlag);
         end;
  FreeMem(TmpBuff);
  end;
Result:=not EFlag;
end;

// Процедура загрузки строки текста из буфера исходного файла
procedure TMainForm.RdString(Buff: PP; BLength: Longint; var BPtr: Longint; var S: String; var Lnum: Longint);
var
   A: Longint;
   F: Boolean;
   T: String;
begin
S:='';
F:=true;
while (BPtr<BLength)and(F) do
      begin
      if Buff[Bptr]=13 then F:=false;
      if F then S:=S+Chr(Buff[BPtr])
         else begin
         Inc(Bptr);
         Inc(LNum);
         end;
      Inc(Bptr);
      end;
if Pos(';',S)<>0 then S:=Copy(S,1,Pos(';',S)-1);
A:=1;
F:=true;
if S<>'' then
   while A<Length(S) do
         if (S[A]=' ')or(S[A]=#9)
            then begin
                 if F then Delete(S,A,1)
                    else begin
                    F:=true;
                    S[A]:=' ';
                    Inc(A);
                    end;
                 end
            else begin
                 Inc(A);
                 F:=false;
                 end;
F:=false;
T:='';
while S<>'' do
      if Pos('''',S)=0
         then begin
              T:=T+AnsiUpperCase(S);
              S:='';
              end
         else if not F
                 then begin
                      T:=T+AnsiUpperCase(Copy(S,1,Pos('''',S)));
                      Delete(S,1,Pos('''',S));
                      F:=true;
                      end
                 else begin
                      T:=T+Copy(S,1,Pos('''',S));
                      Delete(S,1,Pos('''',S));
                      F:=false;
                      end;
S:=T;
while Length(S)<>0 do
      if (S[Length(S)]=' ')or(S[Length(S)]=#9) then S:=Copy(S,1,Length(S)-1)
                                               else break;
end;

//------------------------------------------------------------------------------
// Процедура выделения объектов и контроля правильности их вложения
//------------------------------------------------------------------------------
function TMainForm.ExtractObjects: Boolean;
var
   A,B,ObjStr: Longint;
   CurOwner: Longint;
   S,T,Prop, V, U: String;
   CurName: String;
   F: Boolean;
begin
OutMessage(0,8,-1,'',EFlag);
// инициализация параметров перед обработкой
CurOwner:=-1;                       // указатель на первый объект в рамках исходного текста
CurName:='';                        //текущее название объекта
A:=0;
while A<>SrcBuffer.BuffCount do
    begin
    Application.ProcessMessages;
    if (StopBtn.Tag<>0) or EFlag then Break;
    V:=GetSourceLineFromSource(SrcBuffer,A); //- строка исходного текста
    if V<>'' then
       begin
       //Поиск определений объектов в текущей прочитанной строке
       GetWord(V,U);
       RemoveFirstSpaces(V);
       S:=V;
       if (U='ENDOF')and(Length(U)=5) then
          begin
          if S='' then OutMessage(2,20,A,'',EFlag) // если завершение неизвестно чего
             else begin
             // Если определено завершение какого либо объекта
             if (CurName<>S)or(Length(S)<>Length(CurName)) then OutMessage(2,10,A,'',Eflag) // если закрывается неизвестный объект
                else begin
                // если правильное закрытие объекта
                SetOwnerInSource(A,CurOwner,SrcBuffer);
                CurOwner:=ObjectCollection.ObjectOwner[CurOwner]; //восстановление предыдущего хозяина
                if CurOwner>=0 then CurName:=StrPas(ObjectCollection.ObjectName[CurOwner])
                               else CurName:='';
                RemoveStringFromSource(A, SrcBuffer);
                end;
             end;
          end
          else begin
          // если это не завершение объекта
          B:=GetKeyWordType(U);
          if (B=0)and(ObjectCollection.ObjectType[CurOwner]=0) then OutMessage(2,21,A,'',EFlag) // Обработка, если не найдено совпадений
             else begin
             // если тип слова определенный или определен объект
             if B=0 then SetOwnerInSource(A,CurOwner,SrcBuffer) //установка принадлежности строки
                else begin
                // если декларация объекта внутри текущего объекта
                if not CheckOwnerShip(CurOwner,B,ObjectCollection) then OutMessage(2,16,A,'',EFlag) // если недопустимое вложение
                   else begin
                   // если новый объект можно вложить в текущий
                   case B of
                        1: // обработка вложения OBJECT
                           if S='' then OutMessage(2,7,A,'',EFlag) // если слово обнаружено, но нет названия
                              else begin
                              // Обработка, если можно создавать объект
                              ObjStr:=A;
                              V:=S;                              //установка строки для вычитывания имени
                              GetWord(V,U);                      //вычитывание имени объекта
                              // попытка вычитывания параметров объекта
                              RemoveFirstSpaces(V);    //удаление пробелов в исходной строке
                              Prop:=V;
                              if Prop='' then OutMessage(2,25,A,'',EFlag)
                              else if (Prop[1]<>'(') or (Prop[Length(Prop)]<>')') then OutMessage(2,25,A,'',EFlag)
                                 else begin
                                 Prop:=Copy(Prop,2,Length(Prop)-2)+',';
                                 RemoveStringFromSource(A,SrcBuffer);
                                 CurName:=U;                   //установка имени объекта
                                 CreateObjectInCollection(U,1,ObjectCollection,F,CurOwner);
                                 if not F then StrPCopy(ObjectCollection.ObjectSet[CurOwner],'DEFAULT');
                                 if F then OutMessage(4,9,-1,'',EFlag)
                                 else while Prop<>'' do // обработка формирования строки параметров объекта
                                      begin
                                      // установка названия блока описания команд по умолчанию
                                      T:=Copy(Prop,1,Pos(',',Prop));
                                      Delete(Prop,1,Pos(',',Prop));
                                      V:=T;
                                      GetWord(V,U);
                                      T:=V;
                                      if T[1]=' ' then Delete(T,1,1);
                                      if T[1]<>'=' then OutMessage(2,29,ObjStr,'',EFlag) // если неправильное определение свойств
                                         else begin
                                         Delete(T,1,1);
                                         T:=Copy(T,1,Pos(',',T)-1);
                                         if T<>'' then
                                            if T[1]=' ' then Delete(T,1,1);
                                         if T='' then OutMessage(2,28,ObjStr,'',EFlag)
                                            else case GetObjectPropWordType(U) of
                                                      0: OutMessage(2,27,ObjStr,'Word : "'+T+'"',EFlag); //недействительное слово свойств
                                                      1: StrPCopy(ObjectCollection.ObjectSet[CurOwner],T); // для набора команд
                                                      2: ObjectCollection.ObjectGran[CurOwner]:=StrToIntDef(T,1);
                                                      end;
                                         end;
                                      end;
                                 end;
                              end;
                        // Обработка для вложения описания системы команд ISET
                        3: if S='' then OutMessage(2,7,A,'',EFlag) // если слово обнаружено, но нет названия
                              else begin
                               V:=S;
                               GetWord(V,U);
                               T:=U;
                               S:=V;
                               if Length(S)>1 then OutMessage(2,68,A,'',EFlag)
                                  else if T='' then OutMessage (2,69,A,'',EFlag)
                                       else begin
                                       CurName:=T;
                                       CreateObjectInCollection(U,B,ObjectCollection,F,CurOwner);
                                       if F then OutMessage(3,9,-1,'',EFlag);
                                       RemoveStringFromSource(A,SrcBuffer);
                                       end;
                              end;
                        // Обработка, если декларируется поле команды или
                        // набор мнемоник команд или макрокоманда
                        // FIELD, INSTRUCTIONS, MACRO
                        2,4,5: if S='' then OutMessage(2,7,A,'',EFlag) // если слово обнаружено, но нет названия
                                  else begin
                                  V:=S;
                                  GetWord(V,U);
                                  T:=U;
                                  RemoveFirstSpaces(V);
                                  S:=V;
                                  if Length(S)<2 then OutMessage(2,80,A,'',EFlag)
                                     else if T='' then OutMessage (2,69,A,'',EFlag)
                                          else begin
                                          CurName:=T;
                                          CreateObjectInCollection(U,B,ObjectCollection,F,CurOwner);
                                          if F then OutMessage(3,9,-1,'',EFlag);
                                          ReplaceStringInSource(V,A,SrcBuffer);
                                          SetOwnerInSource(A,CurOwner,SrcBuffer);
                                          end;
                                  end;
                        end;
                   end;
                end;
             end;
          end;
       end;
    Inc(A);
    end;
if ObjectCollection.ObjectOwner[CurOwner]<>-1 then OutMessage(3,7,-1,'',EFlag);
Result:=not EFlag;
end;


//------------------------------------------------------------------------------
// Процедура выделения и последующей подстановки константных выражений
//------------------------------------------------------------------------------
function TMainForm.ProcessDefinitions: Boolean;
var
   DBuff: TDataBuffer;
   A,C,E: Longint;
   EFlag: Boolean;
   Buff: PP;
   S,T,V,U: string;
begin
OutMessage(0,7,-1,'',EFlag);
Buff:=Nil;
DBuff.BuffPtr:=nil;
DBuff.BuffLength:=0;
DBuff.BuffCount:=0;
A:=0;
EFlag:=false;
// Сканирование исходного текста в поисках определения констант
while (A<SrcBuffer.BuffCount)and(not EFlag)and(StopBtn.Tag=0) do
      begin
      Application.ProcessMessages;
      V:=GetSourceLineFromSource(SrcBuffer,A);
      GetWord(V,U);
      if CompareStr('TIMESTAMP',U)=0 then
         begin
         U:='DEFINE';
         V:=V+'='+''''+DateToStr(Date)+' '+TimeToStr(Time)+'''';
         end;
      if (U='DEFINE')and(Length(U)=6) then
         if Pos('=',V)=0 then OutMessage(2,5,A,'',EFlag)
              else begin
              RemoveFirstSpaces(V);
              S:=Copy(V,1,Pos('=',V)-1);                       // S - имя константы
              Delete(V,1,Pos('=',V));                          // V - ее значение
              if CheckConstantInBuffer(S,DBuff) then OutMessage(2,6,A,'',EFlag)
                 else begin
                 // обработка установки эквивалента константы в буфере
                 if DBuff.BuffLength<DBuff.BuffCount+1024 then
                    begin
                    DBuff.BuffLength:=DBuff.BuffCount+32768;
                    ReallocMem(DBuff.BuffPtr,DBuff.BuffLength);
                    end;
                 FillChar(DBuff.BuffPtr[DBuff.BuffCount],256,0);
                 for E:=1 to Length(S) do DBuff.BuffPtr[E-1+DBuff.BuffCount]:=Ord(S[E]);
                 for E:=1 to Length(V) do DBuff.BuffPtr[E-1+DBuff.BuffCount+128]:=Ord(V[E]);
                 DBuff.BuffCount:=DBuff.BuffCount+256;
                 // удаление исходной строки из буфера исходного текста
                 RemoveStringFromSource(A,SrcBuffer);
                 end;
              end;
      Inc(A);
      end;
// тестовая запись результирующего файла выражений
//if DBuff.BuffCount<>0 then SaveDataBuffer(DBuff,'define.def');

// сканирование исходного текста в поисках выполнения возможных подстановок
if (not EFlag) and (DBuff.BuffCount<>0) then
   for A:=0 to SrcBuffer.BuffCount-1 do
       begin
       //B:=GetOwnerFromSource(A,SrcBuffer);
       V:=GetSourceLineFromSource(SrcBuffer,A);
       S:=V;
       if S<>'' then
          begin
          C:=0;
          while C<DBuff.BuffCount do
             begin
             if Pos(StrPas(Addr(DBuff.BuffPtr[C])),S)<>0 then
                begin
                // если возможно необходимо выполнить подстановку константы в строку
                T:=StrPas(Addr(DBuff.BuffPtr[C]));
                V:=GetSourceLineFromSource(SrcBuffer,A);
                while V<>'' do
                      begin
                      GetWord(V,U);
                      if (U=T)and(Length(U)=Length(T)) then
                         begin
                         // если действительно требуется выполнить подстановку
                         E:=Length(V)+Length(U); //начальная позиция записи
                         U:=GetSourceLineFromSource(SrcBuffer,A);
                         T:=StrPas(Addr(DBuff.BuffPtr[C+128])); //величина константы
                         V:=Copy(U,1,Length(U)-E)+T+V;
                         T:=StrPas(Addr(DBuff.BuffPtr[C]));  //название константы
                         ReplaceStringInSource(V,A,SrcBuffer);
                         end;
                      end;
                end;
             C:=C+256;
             end;
          end;
       end;

if Buff<>nil then FreeMem(Buff);
if DBuff.BuffPtr<>nil then FreeMem(DBuff.BuffPtr);

Result:=not EFlag;
end;


//------------------------------------------------------------------------------
// Процедура формирования буферов описания систем команд
//------------------------------------------------------------------------------
function TMainForm.LoadInstructionReferences: Boolean;
var
   Par: String;
   T,R, V,U,Als: String;
   A,B,C,D: Longint;
   F: Boolean;
   Sz,Ps,Alv,ACode: Extended;
   Eb: Byte;
begin
OutMessage(0,16,-1,'',EFlag);
A:=0;
while (ObjectCollection.ObjectType[A]<>255)and(StopBtn.Tag=0)and(not EFlag) do
      begin
      Application.ProcessMessages;
      if ObjectCollection.ObjectType[A]=3 then
         for B:=0 to 127 do             // Обработка, если найдено очередное описание набора команд
             if InstCollection[B].ISETName='' then
                begin
                // если найден буфер для создания набора команд
                InstCollection[B].ISETName:=StrPas(ObjectCollection.ObjectName[A]);

                // сканирование, пока идут блоки описания полей и мнемоник
                Inc(A);
                while (ObjectCollection.ObjectType[A]=4)or(ObjectCollection.ObjectType[A]=5) do
                      begin
                      C:=0;
                      F:=false;
                      while not F do
                            if C=SrcBuffer.BuffCount then Break
                               else if A=GetOwnerFromSource(C,SrcBuffer) then F:=true
                                    else Inc(C);
                      if not F then OutMessage(1,10,-1,StrPas(ObjectCollection.ObjectName[A]),EFlag)
                         else begin
                         //попытка вычитать параметры поля команды или мнемоники команды
                         Par:=GetSourceLineFromSource(SrcBuffer,C);
                         RemoveFirstSpaces(Par);
                         if (Par[1]<>'(')and(Par[Length(Par)]<>')') then OutMessage(2,53,C,'',EFlag)
                            else begin
                            Par:=Copy(Par,2,Length(Par)-2)+',';
                            // Обработка полученной строки параметров
                            Sz:=0.33;
                            Ps:=0.33;
                            ACode:=0;
                            while Par<>'' do
                                  begin
                                  T:=Copy(Par,1,Pos(',',Par)-1);
                                  Delete(Par,1,Pos(',',Par));
                                  RemoveFirstSpaces(Par);
                                  if (Pos('SIZE=',T)<>1)and(Pos('POSITION=',T)<>1)and(Pos('ALIGNCODE=',T)<>1) then OutMessage(2,54,C,'',EFlag)
                                     else if Pos('SIZE=',T)=1
                                          then begin  // обработка параметра размерности поля
                                               Delete(T,1,5);
                                               RemoveFirstSpaces(T);
                                               Eb:=ConvertExpression(T,Sz);
                                               if Eb<>0 then OutMessage(2,34+Eb,C,'',EFlag);
                                               end
                                          else if Pos('POSITION=',T)=1
                                               then begin  // обработка параметра позиции поля
                                                    Delete(T,1,9);
                                                    RemoveFirstSpaces(T);
                                                    Eb:=ConvertExpression(T,Ps);
                                                    if Eb<>0 then OutMessage(2,34+Eb,C,'',EFlag);
                                                    end
                                               else begin
                                                    // обработка кода выравнивания
                                                    Delete(T,1,10);
                                                    RemoveFirstSpaces(T);
                                                    Eb:=ConvertExpression(T,ACode);
                                                    if Eb<>0 then OutMessage(2,34+Eb,C,'',EFlag);
                                                    end;
                                  end;
                            if (Frac(Sz)<>0)or(Frac(Ps)<>0) then OutMessage(2,58,C,'',EFlag)
                               else if ObjectCollection.ObjectType[A]=4                   // когда параметры установлены, поиск места для создания буфера мнемоник полей
                                    then begin                    // обработка для поля
                                         for D:=0 to 127 do if InstCollection[B].ISETFields[D]='' then
                                             begin
                                             InstCollection[B].ISETFields[D]:=StrPas(ObjectCollection.ObjectName[A]);
                                             InstCollection[B].ISETFieldLocs[D]:=Round(Int(Ps));
                                             InstCollection[B].ISETFieldSizes[D]:=Round(Int(Sz));
                                             InstCollection[B].ISETBuffWidths[D]:=CalcFieldSize(InstCollection[B].ISETFieldSizes[D]);
                                             GetMem(InstCollection[B].ISETBuffs[D],50*InstCollection[B].ISETBuffWidths[D]);
                                             InstCollection[B].ISETBuffLengths[D]:=50*InstCollection[B].ISETBuffWidths[D];
                                             InstCollection[B].ISETBuffCounts[D]:=0;
                                             Inc(C);
                                             //обработка списка полей команды до ьех пор, пока есть исходные строки
                                             while GetOwnerFromSource(C,SrcBuffer)=A do
                                                   begin
                                                   V:=GetSourceLineFromSource(SrcBuffer,C);
                                                   T:=V;
                                                   if Length(T)>0 then
                                                      if Pos('=',T)<2 then OutMessage(2,59,C,'',EFlag)
                                                         else begin
                                                         T:=Copy(T,1,Pos('=',T)-1);
                                                         if T[Length(T)]=' ' then T:=Copy(T,1,Length(T)-1);
                                                         U:=T;    //символьное обозначение величины
                                                         T:=V;
                                                         Delete(T,1,Pos('=',T));
                                                         V:=T;
                                                         RemoveFirstSpaces(V);
                                                         T:=V;
                                                         Eb:=ConvertExpression(T,Sz);
                                                         if Eb<>0 then OutMessage(2,34+Eb,C,'',EFlag);
                                                         F:=Pos('.',V)<>0;
                                                         AddToFieldBuffer(Sz,F,U,InstCollection[B],D,Eb);
                                                         if Eb<>0 then OutMessage(2,Eb,C,'',EFlag);
                                                         end;
                                                   Inc(C);
                                                   if C=SrcBuffer.BuffCount then break;
                                                   end;
                                             Break;
                                             end;
                                         end
                                    else begin                    // обработка для мнемоники
                                         InstCollection[B].ISETMnemonicLoc:=Round(Int(Ps));
                                         InstCollection[B].ISETMnemonicSize:=Round(Int(Sz));
                                         InstCollection[B].ISETMnemonicWidth:=640;
                                         InstCollection[B].ISETAlignCode:=Round(Int(ACode));
                                         //InstCollection[B].ISETMnemonicWidth:=CalcMnemonicSize(InstCollection[B].ISETMnemonicSize);
                                         GetMem(InstCollection[B].ISETMnemonicBuffer,50*InstCollection[B].ISETMnemonicWidth);
                                         InstCollection[B].ISETMnemonicLength:=50*InstCollection[B].ISETMnemonicWidth;
                                         InstCollection[B].ISETMnemonicCount:=0;
                                         Inc(C);
                                         while GetOwnerFromSource(C,SrcBuffer)=A do
                                               begin
                                               V:=GetSourceLineFromSource(SrcBuffer,C);
                                               T:=V;
                                               if Length(T)>0 then
                                                  begin
                                                  GetWord(V,U);
                                                  R:=U;
                                                  RemoveFirstSpaces(V);
                                                  T:=V;
                                                  if Pos('=',T)=0 then OutMessage(2,50,C,'',EFlag)
                                                     else begin
                                                          U:='';
                                                          if Pos('=',T)<>1 then
                                                             begin
                                                             // обработка, если есть мнемоника полей команд
                                                             U:=Copy(T,1,Pos('=',T)-1);
                                                             RemoveLastSpaces(U);
                                                             end;
                                                          Delete(T,1,Pos('=',T));
                                                          Alv:=0;
                                                          RemoveFirstSpaces(T);
                                                          // проверка наличия величины выравнивания
                                                          if Pos(' ',T)<>0 then
                                                             begin
                                                             // если есть код выравнивания
                                                             Als:=Copy(T,Pos(' ',T)+1, Length(T)-Pos(' ',T));
                                                             T:=Copy(T,1,Pos(' ',T)-1);
                                                             ConvertExpression(Als,Alv);
                                                             end;
                                                          Eb:=ConvertExpression(T,Sz);
                                                          if Eb<>0 then OutMessage(2,34+Eb,C,'',EFlag)
                                                             else begin
                                                             // если правильно конвертирован код операции.
                                                             F:=Pos('.',V)<>0;
                                                             V:=R;
                                                             AddToMnemonicBuffer(Sz,Alv,F,V,U,InstCollection[B],Eb);
                                                             if Eb<>0 then OutMessage(2,Eb,C,'',EFlag);
                                                             end;
                                                          end;
                                                  end;
                                               Inc(C);
                                               end;
                                         end;
                            end;
                         end;
                      Inc(A);
                      end;
                Break;
                end;
      Inc(A);
      end;
Result:=not EFlag;
end;

//------------------------------------------------------------------------------
// Процедура создания кросс таблиц, и подсчета размеров программного кода
//------------------------------------------------------------------------------
function TMainForm.CrossProcessor: Boolean;
var
   A,B,C,E,G: Longint;
   S,V,U: String;
   Buff: array [0..4095] of Byte;
   Ptr,DPtr,Alg: Longint;          //указатель текущей позиции в объекте и приращение указателя
   VarData: String;            //название переменной
   Eb: Byte;
   Vv: Extended;
begin
OutMessage(0,14,-1,'',EFlag);
A:=0;
while (ObjectCollection.ObjectType[A]<>255)and(StopBtn.Tag=0) do
      begin
      Application.ProcessMessages;
      Case ObjectCollection.ObjectType[A] of
           1: begin // Обработка, если попался объект
              // Обработка начальной инициализации кросс таблицы для объекта
              // установка названия объекта в кросс-таблице
              // инициализация кросс-таблицы и установка записи объекта
              ObjectCollection.CrossLengths[A]:=0;
              C:=6+Length(StrPas(ObjectCollection.ObjectName[A]));  //длина записи
              Move(C,Buff[0],4);
              Buff[4]:=0;
              Move(ObjectCollection.ObjectName[A][0],Buff[5],C-5);
              AddToCrossBuffer(A,ObjectCollection,Buff,C);
              // обработка исходного текста объекта
              B:=0;
              Ptr:=0;
              while B<SrcBuffer.BuffCount do
                    if GetOwnerFromSource(B,SrcBuffer)=A then Break
                                                         else Inc(B);
              if B=SrcBuffer.BuffCount then OutMessage(1,11,-1,'',EFlag)
                 else while (GetOwnerFromSource(B,SrcBuffer)=A) and (B<SrcBuffer.BuffCount)and(StopBtn.Tag=0) do
                      begin
                      Application.ProcessMessages;
                      // Обработка, если есть строки текста
                      V:=GetSourceLineFromSource(SrcBuffer,B);
                      while V<>'' do
                            begin
                            RemoveFirstSpaces(V);
                            // проверка наличия в строке метки
                            GetWord(V,U);
                            if Pos(':',V)=1
                               then begin
                                    // обработка установки программной метки в кросс-таблицу
                                    Delete(V,1,1);
                                    RemoveFirstSpaces(V);
                                    // установка обновленной строки в буфере исходного текста
                                    ReplaceStringInSource(V,B,SrcBuffer);
                                    //проверка наличия программной метки в кросс-таблице
                                    if GetLabelOffset(U,ObjectCollection,A)>=0 then OutMessage(2,70,B,'',EFlag)
                                       else begin
                                       // установка названия программной метки в кросс-таблице
                                       C:=Length(U)+10;  //длина записи
                                       Move(C,Buff[0],4);
                                       Buff[4]:=1;
                                       Move(U[1],Buff[5],Length(U));
                                       Buff[5+Length(U)]:=0;
                                       Move(Ptr,Buff[C-4],4);
                                       AddToCrossBuffer(A,ObjectCollection,Buff,C);
                                       end;
                                    end
                               else begin
                                    if CheckInstruction(U,ObjectCollection,InstCollection,A)
                                       then begin
                                            // обработка, если это машинная команда
                                            //  AlignPointer(Ptr,4);   //выравнивание указателя на границу 32-разрядного слова
                                            Alg:=GetInstructionAlignment(U,ObjectCollection,InstCollection,A);
                                            if Alg<>0 then
                                               if Frac(Ptr/Alg)<>0 then Ptr:=Alg*(1+(Ptr div Alg));
                                            Ptr:=Ptr+GetInstructionLength(U,ObjectCollection,InstCollection,A);
                                            V:='';
                                            end
                                       else begin
                                            C:=GetCompilerWordType(U);
                                            if C=-1 then begin V:=''; OutMessage(2,33,B,'',EFlag); end
                                               else case (C shr 8)and 255 of
                                                    0: begin V:=''; OutMessage(2,34,B,'',EFlag); end; //если число
                                                    1: begin V:=''; OutMessage(2,22,B,'',EFlag); end; //если служебный символ
                                                    2: begin
                                                       //если это определение слова данных (оператор в начале строки)
                                                       DPtr:=-1;
                                                       case C and 255 of
                                                            0: DPtr:=1; //множитель для количества элементов данных
                                                            1: DPtr:=2; //для Word
                                                            2: DPtr:=4; // dword
                                                            3: DPtr:=8; // qword
                                                            4: DPtr:=16; // eword
                                                            5: DPtr:=4;  // single
                                                            6: DPtr:=8;  // double
                                                            7: DPtr:=16; // extended
                                                            8,9,10,11,12,13: OutMessage(2,71,B,'',EFlag);
                                                            end;
                                                       if DPtr>0 then
                                                          begin
                                                          //AlignPointer(Ptr,DPtr);
                                                          //       вычитывание названия переменной
                                                          RemoveFirstSpaces(V);
                                                          VarData:=V+',';
                                                          // когда формирование строки данных завершено, выполнение подсчета элементов данных
                                                          G:=0;                                          //количество элементов данных
                                                          while VarData<>'' do
                                                                begin
                                                                V:=Copy(VarData,1,Pos(',',VarData)-1);
                                                                RemoveFirstSpaces(V);
                                                                GetWord(V,U);
                                                                E:=GetCompilerWordType(U);
                                                                if E=-1 then Inc(G)
                                                                   else case (E shr 8)and 255 of
                                                                             0: Inc(G);  //если число
                                                                             1: if U[1]<>'''' then Inc(G)
                                                                                   else begin
                                                                                        S:=V;
                                                                                        if S[Length(S)]<>'''' then OutMessage(2,67,B,'',EFlag)
                                                                                                              else G:=G+Length(S)-1;
                                                                                        end;
                                                                             2: OutMessage(2,81,B,'',EFlag); //если оператор данных
                                                                             3: if (E and 255)<>1 then OutMessage(2,84,B,'',EFlag)
                                                                                   else begin
                                                                                        // если определен массив
                                                                                        RemoveFirstSpaces(V);
                                                                                        S:=V;
                                                                                        if StrToIntDef(S,-1)<0 then OutMessage(2,84,B,'',EFlag)
                                                                                                               else G:=G+StrToInt(S);
                                                                                        end;
                                                                             4: OutMessage(2,38,B,'',EFlag);
                                                                             // если адресный оператор
                                                                             6: case E and 255 of
                                                                                     0: IncrementCounter(DPtr,Dptr,G); // Offset
                                                                                     1: IncrementCounter(DPtr,4,G); // selector
                                                                                     2: IncrementCounter(DPtr,8,G); // pointer
                                                                                     3: IncrementCounter(DPtr,8,G); // voffset
                                                                                     4: IncrementCounter(DPtr,12,G); //vpointer;
                                                                                     5: IncrementCounter(Dptr,Dptr,G); //displacement
                                                                                     end;
                                                                             end;
                                                                Delete(VarData,1,Pos(',',VarData));
                                                                end;
                                                          if G=0 then OutMessage(1,6,B,'',EFlag)
                                                                 else Ptr:=Ptr+G*DPtr;
                                                          end;
                                                       V:='';
                                                       end;
                                                    3: case C and 255 of
                                                            0,1: begin
                                                                 OutMessage(2,33,B,'',EFlag);
                                                                 V:='';
                                                                 end;
                                                            2: begin //обработка для команды выравнивания
                                                               RemoveFirstSpaces(V);
                                                               S:=V;
                                                               if Length(S)=0 then OutMessage(2,18,B,'',EFlag)
                                                                  else begin
                                                                  Eb:=ConvertExpression(S,Vv);
                                                                  if Eb<>0 then OutMessage(2,Eb+34,B,'',EFlag)
                                                                     else AlignPointer(Ptr,Round(Int(Vv)));
                                                                  end;
                                                               V:='';
                                                               end;
                                                            6: begin // обработка для переустановки адресного указателя
                                                               RemoveFirstSpaces(V);
                                                               S:=V;
                                                               if Length(S)=0 then OutMessage(2,18,B,'',EFlag)
                                                                  else begin
                                                                  Eb:=ConvertExpression(S,Vv);
                                                                  if Eb<>0 then OutMessage(2,Eb+34,B,'',EFlag)
                                                                           else Ptr:=Round(Int(Vv));
                                                                  end;
                                                               V:='';
                                                               end;
                                                            end;
                                                    4: begin V:=''; OutMessage(2,41,B,'',EFlag); end; //если это математический оператор
                                                    end;
                                            end;
                                    end;
                            end;
                      Inc(B);
                      end;
              end;
           end;
      Inc(A);
      end;
Result:=not EFlag;
end;


//------------------------------------------------------------------------------
// Процедура генерации двоичного кода программных объектов
//------------------------------------------------------------------------------
function TMainForm.AssmProcessor: Boolean;
var
   Val: Extended;
   A,B,C,D,E,F,Ptr,NPtr: Longint;
   Buff: PP;
   S,T,V,U: String;
   Eb: Byte;
begin
OutMessage(0,20,-1,'',EFlag);
Buff:=nil;
GetMem(Buff,4096);
A:=0;
while (ObjectCollection.ObjectType[A]<>255) and (StopBtn.Tag=0) do
      begin
      Case ObjectCollection.ObjectType[A] of
           // если попался объект, который необходимо компилировать
           1: begin
              B:=0;
              Ptr:=0;
              // определение набора команд, с которым компилируется объект
              E:=-1;
              S:=StrPas(ObjectCollection.ObjectSet[A]);
              for D:=0 to 127 do
                  if (S=InstCollection[D].ISETName)and(Length(S)=Length(InstCollection[D].ISETName)) then
                     begin
                     E:=D;
                     Break;
                     end;
              if E<0 then OutMessage(2,74,-1,'',EFlag)
                 else begin
                 // вычитывание указателя на позицию в BinCollection из дескриптора
                 while B<SrcBuffer.BuffCount do
                       if GetOwnerFromSource(B,SrcBuffer)=A then Break
                                                            else Inc(B);
                 if B<SrcBuffer.BuffCount then
                    while (GetOwnerFromSource(B,SrcBuffer)=A) and (StopBtn.Tag=0) do
                          begin
                          Application.ProcessMessages;
                          // вычитывание очередной строки текста
                          V:=GetSourceLineFromSource(SrcBuffer,B);
                          if V<>'' then RemoveFirstSpaces(V);
                          while V<>'' do
                                begin
                                // обработка прочитанной строки текста
                                GetWord(V,U);
                                if CheckInstruction(U,ObjectCollection,InstCollection,A)
                                   then begin
                                        // обработка, если это машинная команда
                                        FillChar(Buff[0],1024,0);
                                        V:=GetSourceLineFromSource(SrcBuffer,B);
                                        if CompileInstruction(V,A,E,Buff,B,Ptr) then AddToBinaryBuffer(A,Ptr,ObjectCollection,Buff,SrcBuffer,B)
                                           else EFlag:=true;
                                        Move(Buff[0],C,4);
                                        Ptr:=Ptr+C;
                                        V:='';
                                        end
                                   else if Length(V)>0 then
                                        begin
                                        C:=GetCompilerWordType(U);
                                        if C=-1 then OutMessage(2,64,B,'',EFlag)
                                           else case C shr 8 of
                                                     // если число
                                                     0: begin
                                                        OutMessage(2,34,B,'',EFlag);
                                                        V:='';
                                                        end;
                                                     // если символы
                                                     1: begin
                                                        OutMessage(2,62,B,'',EFlag);
                                                        V:='';
                                                        end;
                                                     // если определение данных
                                                     2: if (C and 255)>7 then OutMessage(2,41,B,'',EFlag)
                                                           else begin
                                                           if CompileDatas(B,A,Buff,Ptr) then AddToBinaryBuffer(A,Ptr,ObjectCollection,Buff,SrcBuffer,B)
                                                              else EFlag:=true;
                                                           Move(Buff[0],C,4);
                                                           Ptr:=Ptr+C;
                                                           V:='';
                                                           end;
                                                     // если служебное слово
                                                     3: begin
                                                        if (C and 255)=2
                                                           then begin
                                                                // если выравнивание
                                                                RemoveFirstSpaces(V);
                                                                ConvertExpression(V,Val);
                                                                AlignPointer(Ptr,Round(Int(Val)));
                                                                end
                                                        else if (C and 255)<>6 then OutMessage(2,83,B,'',EFlag)
                                                           else begin
                                                           // обработка, если это ORG
                                                           RemoveFirstSpaces(V);
                                                           T:=V;
                                                           Eb:=ConvertExpression(T,Val);
                                                           if Eb<>0 then OutMessage(2,Eb+34,B,'',EFlag)
                                                                    else begin
                                                                         NPtr:=Round(Int(Val));
                                                                         if Ptr<Nptr then
                                                                            begin
                                                                            FillChar(Buff[0],1024,0);
                                                                            while Ptr<>NPtr do
                                                                                  begin
                                                                                  if Nptr-Ptr>1020 then F:=1020
                                                                                                   else F:=Nptr-Ptr;
                                                                                  Move(F,Buff[0],4);
                                                                                  AddToBinaryBuffer(A,Ptr,ObjectCollection,Buff,SrcBuffer,B);
                                                                                  Ptr:=Ptr+F;
                                                                                  end;
                                                                            end;
                                                                         Ptr:=Nptr;
                                                                         end;
                                                           end;
                                                        V:='';
                                                        end;
                                                     // если определен математический оператор слово
                                                     4,5,6: begin
                                                            OutMessage(2,41,B,'',EFlag);
                                                            V:='';
                                                            end;
                                                     end;
                                        end;
                                end;
                          Inc(B);
                          if B>=SrcBuffer.BuffCount then break;
                          end;
                 end;
              end;
           end;
      Inc(A);
      end;
if Buff<>nil then FreeMem(Buff);
Result:=not EFlag;
end;


//------------------------------------------------------------------------------
// инициализация буферов данных перед началом компиляции
procedure TMainForm.InitDataBuffers;
var A,I: LongInt;
begin
FillChar(ObjectCollection.ObjectName[0][0],2048*256,0);
FillChar(ObjectCollection.ObjectSet[0][0],2048*256,0);
FillChar(ObjectCollection.ObjectType[0],2048,255);
FillChar(ObjectCollection.ObjectOwner[0],2048*4,-1);
FillChar(ObjectCollection.ObjectGran[0],2048,1);

for I:=0 to 2047 do
    begin
    if ObjectCollection.BinaryDatas[I]<>nil then FreeMem(ObjectCollection.BinaryDatas[I]);
    if ObjectCollection.CrossDatas[I]<>nil then FreeMem(ObjectCollection.CrossDatas[I]);
    if ObjectCollection.ListDatas[I]<>nil then FreeMem(ObjectCollection.ListDatas[I]);
    ObjectCollection.BinaryDatas[I]:=nil;
    ObjectCollection.CrossDatas[I]:=nil;
    ObjectCollection.ListDatas[I]:=nil;
    end;
FillChar(ObjectCollection.BinaryLengths[0],2047*4,0);
FillChar(ObjectCollection.BinaryCounts[0],2047*4,0);
FillChar(ObjectCollection.CrossLengths[0],2047*4,0);
FillChar(ObjectCollection.CrossCounts[0],2047*4,0);
FillChar(ObjectCollection.ListLengths[0],2047*4,0);
FillChar(ObjectCollection.ListCounts[0],2047*4,0);

for I:=0 to 127 do
    begin
    InstCollection[I].ISETName:='';
    FillChar(InstCollection[I].ISETFieldLocs[0],128*4,0);
    FillChar(InstCollection[I].ISETFieldSizes[0],4*128,0);
    FillChar(InstCollection[I].ISETBuffLengths[0],128*4,0);
    FillChar(InstCollection[I].ISETBuffCounts[0],128*4,0);
    if InstCollection[I].ISETMnemonicBuffer<>nil then
       begin
       FreeMem(InstCollection[I].ISETMnemonicBuffer);
       InstCollection[I].ISETMnemonicBuffer:=nil;
       end;
    InstCollection[I].ISETMnemonicLength:=0;
    InstCollection[I].ISETMnemonicCount:=0;
    InstCollection[I].ISETAlignCode:=0;
    for A:=0 to 127 do
        begin
        InstCollection[I].ISETFields[A]:='';
        if InstCollection[I].ISETBuffs[A]<>nil then FreeMem(InstCollection[I].ISETBuffs[A]);
        InstCollection[I].ISETBuffs[A]:=nil;
        end;
    end;

end;


// обработка запуска программы
procedure TMainForm.FormCreate(Sender: TObject);
var
   I,K: LongInt;
   INI: TIniFile;
   F: Boolean;
   S: String;
begin
INI:=TiniFile.Create(extractfilepath(paramstr(0))+'CAssm.ini');
if INI<>nil then
   begin
   I:=0;
   F:=true;
   while F do
         begin
         S:=INI.ReadString('History','File'+IntToStr(I),'');
         if Length(S)<>0 then SourceEdit.Items.Add(S)
                         else F:=false;
         Inc(I);
         end;
   INI.Free;
   end;
for I:=0 to 2047 do
    begin
    ObjectCollection.BinaryDatas[I]:=nil;
    ObjectCollection.CrossDatas[I]:=nil;
    ObjectCollection.ListDatas[I]:=nil;
    end;
for I:=0 to 127 do
    begin
    InstCollection[I].ISETMnemonicBuffer:=nil;
    for K:=0 to 127 do InstCollection[I].ISETBuffs[K]:=nil;
    end;
// check command line
S:=ParamStr(1);
if Length(S)<>0 then
   begin
   SourceEdit.Text:=S;
   RunBtnClick(Sender);
   Application.Terminate;
   end;
end;


//------------------------------------------------------------------------------
// процедура компиляции строки с машинной командой.
function TMainForm.CompileInstruction(var V: String;var Obj: Longint;var Sel: Longint;var Buff: PP;var Lnumber: Longint;var Ptr: Longint): Boolean;
var
   TmpB: array [0..255] of Char;
   F,EFlag: Boolean;
   S,T,U,Vv,Uu: String;
   A,B,C,D,E,Alg,ACode: Longint;
   APtr,BPtr: Pointer;
   BBuff: PP;
   SrcList,FieldList: TStringList;
   Ext: Extended;
   Eb: Byte;
begin
BBuff:=nil;
if InstCollection[Sel].ISETMnemonicCount>0 then
   begin
   // подготовка данных перед началом компиляции команды
   SrcList:=TStringList.Create;
   FieldList:=TStringList.Create;
   // формирование кода операции по мнемонике команды
   RemoveFirstSpaces(V);
   GetWord(V,U);
   RemoveFirstSpaces(V);
   B:=GetInstructionLength(U,ObjectCollection,InstCollection,Obj);
   Alg:=GetInstructionAlignment(U,ObjectCollection,InstCollection,Obj);
   C:=B;
   ReallocMem(BBuff,B+4);
   Move(B,BBuff[0],4);
   Move(B,Buff[0],4);    // длина блока данных
   // обработка мнемокода команды
   S:=U;
   // поиск мнемоники в буфере
   for A:=0 to InstCollection[Sel].ISETMnemonicCount-1 do
       begin
       T:=StrPas(Addr(InstCollection[Sel].ISETMnemonicBuffer[A*InstCollection[Sel].ISETMnemonicWidth]));
       if (S=T)and(Length(S)=Length(T)) then
          begin
          // если команда обнаружена по мнемонике
          FillByte(Buff,4,B,0);
          // установка кода операции в буфере команды
          APtr:=Addr(InstCollection[Sel].ISETMnemonicBuffer[A*InstCollection[Sel].ISETMnemonicWidth+512]);
          BPtr:=Addr(Buff[0]);
          //C:=InstCollection[Sel].ISETMnemonicWidth-512;
          asm
          pushad
          mov  esi,APtr
          mov  edi,BPtr
          add  edi,4
          mov  ecx,C
          cld
          rep movsb
          popad
          end;
          ShiftBuffer(Buff,InstCollection[Sel].ISETMnemonicLoc,InstCollection[Sel].ISETMnemonicSize);
          // обработка операндов команды, если таковые имеются
          if StrPas(Addr(InstCollection[Sel].ISETMnemonicBuffer[256+A*InstCollection[Sel].ISETMnemonicWidth]))<>'' then
             begin
             // вычитывание эталонной строки операндов и формирование списка строк
             Move(InstCollection[Sel].ISETMnemonicBuffer[256+A*InstCollection[Sel].ISETMnemonicWidth],TmpB,256);
             Vv:=StrPas(TmpB);
             SrcList.Clear;
             FieldList.Clear;
             while Vv<>'' do
                   begin
                   RemoveFirstSpaces(Vv);
                   GetWord(Vv,Uu);
                   if Uu<>'' then FieldList.Add(Uu);
                   end;
             FieldList.Add('!');
             // разделение исходной строки операндов на соответствующие позиции
             S:=V;  //строка операндов
             S:=Copy(S,1,Length(S))+'!';
             for B:=0 to FieldList.Count-1 do
                 begin
                 Vv:=FieldList[B];
                 C:=GetCompilerWordType(Vv);
                 if C<>-1 then
                    if (C shr 8)=1 then
                       if Pos(FieldList[B],S)<>0 then
                          begin
                          SrcList.Add(Copy(S,1,Pos(FieldList[B],S)-1));
                          Delete(S,1,Pos(FieldList[B],S));
                          SrcList.Add('');
                          FieldList[B]:='';
                          end;
                 end;
             if SrcList.Count<>FieldList.Count then OutMessage(2,59,LNumber,'',EFlag)
                else while FieldList.Count<>0 do
                     if FieldList[0]=''
                        then begin
                             // если разделительная строка
                             FieldList.Delete(0);
                             SrcList.Delete(0);
                             end
                        else begin
                             // если поле команды, которое требуется обработать
                             S:=FieldList[0];
                             T:=SrcList[0];
                             // поиск описания поля среди мнемоник возможных операндов команды
                             F:=false;
                             for B:=0 to 127 do
                                 if (S=InstCollection[Sel].ISETFields[B])and(Length(S)=Length(InstCollection[Sel].ISETFields[B])) then
                                    begin
                                    F:=true;
                                    Break;
                                    end;
                             if F
                                then begin
                                     // если поле обнаружено в спике
                                     // сканирование в поисках мнемоники поля команды
                                     F:=false;
                                     for C:=0 to InstCollection[Sel].ISETBuffCounts[B]-1 do
                                         begin
                                         S:=StrPas(Addr(InstCollection[Sel].ISETBuffs[B][C*InstCollection[Sel].ISETBuffWidths[B]]));
                                         if (T=S)and(Length(S)=Length(T)) then
                                            begin
                                            F:=true;
                                            Break;
                                            end;
                                         end;
                                     if F
                                        then begin
                                             // обработка, если мнемоника поля обнаружена
                                             Move(BBuff[0],D,4);
                                             FillByte(BBuff,4,D,0);
                                             APtr:=Addr(InstCollection[Sel].ISETBuffs[B][256+C*InstCollection[Sel].ISETBuffWidths[B]]);
                                             BPtr:=Addr(BBuff[0]);
                                             D:=InstCollection[Sel].ISETBuffWidths[B]-256;
                                             asm
                                                pushad
                                                mov  esi,APtr
                                                mov  edi,BPtr
                                                add  edi,4
                                                mov  ecx,D
                                                cld
                                                rep movsb
                                                popad
                                             end;
                                             ShiftBuffer(BBuff,InstCollection[Sel].ISETFieldLocs[B],InstCollection[Sel].ISETFieldSizes[B]);
                                             ORBuffer(Buff,BBuff);
                                             end
                                        else begin
                                             // если мнемоника не обнаружена в списке, то
                                             // попытка определить операнд по другому
                                             Move(BBuff[0],D,4);
                                             FillByte(BBuff,4,D,0);
                                             // попытка найти в строке операторы адресной информации и заменить их на числа
                                             U:='';
                                             while T<>'' do
                                                   begin
                                                   if T[1]=' ' then U:=U+' ';
                                                   GetWord(T,Uu);
                                                   if (Uu='OFFSET') and (Length(Uu)=6)
                                                      then begin
                                                           // если смещение
                                                           GetWord(T,Uu);
                                                           C:=-1;
                                                           if Uu<>'' then C:=GetLabelOffset(Uu,ObjectCollection,Obj);
                                                           if C<0 then OutMessage(2,79,LNumber,'',EFlag);
                                                           Uu:='0'+IntToHex(C div ObjectCollection.ObjectGran[Obj],8)+'H';
                                                           end
                                                      else if (Uu='DISPLACEMENT') and (Length(Uu)=12)
                                                           then begin
                                                                // если относительное смещение
                                                                GetWord(T,Uu);
                                                                C:=-1;
                                                                if Uu<>'' then C:=GetLabelOffset(Uu,ObjectCollection,Obj);
                                                                if C<0 then OutMessage(2,79,LNumber,'',EFlag);
                                                                if (Alg=0) or (Frac(Ptr/Alg)=0) then E:=0
                                                                                                else E:=Alg*(1+(Ptr div Alg))-Ptr;
                                                                Uu:='0'+IntToHex((C-(Ptr+E)) div ObjectCollection.ObjectGran[Obj],8)+'H';
                                                                end;
                                                   U:=U+Uu;
                                                   end;
                                             Eb:=ConvertExpression(U,Ext);
                                             if Eb=0
                                                then begin
                                                     // если выражение успешно конвертировалось
                                                     // проверка формата, в котором требуется выдать результат в строку байт
                                                     if (Pos('.',T)<>0)and((InstCollection[Sel].ISETFieldSizes[B]=32)or(InstCollection[Sel].ISETFieldSizes[B]=64)or(InstCollection[Sel].ISETFieldSizes[B]=128))
                                                        then begin
                                                             // если число с плавающей точкой необходимо вывести в буфер
                                                             if InstCollection[Sel].ISETFieldSizes[B]=32 then SetValueToBuffer(BBuff,4,5,Ext,D)
                                                                else if InstCollection[Sel].ISETFieldSizes[B]=64 then SetValueToBuffer(BBuff,4,6,Ext,D)
                                                                     else SetValueToBuffer(BBuff,4,7,Ext,D);
                                                             if D<>-1 then OutMessage(2,D,LNumber,'',EFlag)
                                                                else begin
                                                                // обработка установки полученного числа в буфер команды
                                                                ShiftBuffer(BBuff,InstCollection[Sel].ISETFieldLocs[B],InstCollection[Sel].ISETFieldSizes[B]);
                                                                ORBuffer(Buff,BBuff);
                                                                end;
                                                             end
                                                        else begin
                                                             // если только целочисленные операции или не соответствующая длина поля
                                                             if InstCollection[Sel].ISETFieldSizes[B]<=8 then SetValueToBuffer(BBuff,4,0,Ext,D)
                                                                else if InstCollection[Sel].ISETFieldSizes[B]<=16 then SetValueToBuffer(BBuff,4,1,Ext,D)
                                                                     else if InstCollection[Sel].ISETFieldSizes[B]<=32 then SetValueToBuffer(BBuff,4,2,Ext,D)
                                                                          else if InstCollection[Sel].ISETFieldSizes[B]<=64 then SetValueToBuffer(BBuff,4,3,Ext,D)
                                                                               else SetValueToBuffer(BBuff,4,4,Ext,D);
                                                             if D<>-1 then OutMessage(2,D,LNumber,'',EFlag)
                                                                else begin
                                                                ShiftBuffer(BBuff,InstCollection[Sel].ISETFieldLocs[B],InstCollection[Sel].ISETFieldSizes[B]);
                                                                ORBuffer(Buff,BBuff);
                                                                end;
                                                             end;
                                                     end
                                                else OutMessage(2,33,LNumber,'',EFlag);
                                             end;
                                     end
                                // если это слово или символ, который должен присутствовать обязательно
                                else if (T<>S)or(Length(T)<>Length(S)) then
                                     begin
                                     OutMessage(2,75,LNumber,'',EFlag);
                                     Vv:='';
                                     end;
                             FieldList.Delete(0);
                             SrcList.Delete(0);
                             end;
             end;
          Break;
          end;
       end;
   FieldList.Free;
   SrcList.Free;
   // выравнивание кода операции
   if Alg<>0 then
      if Frac(Ptr/Alg)<>0 then
         begin
         // если нужно выравнивание
         A:=Alg*(1+(Ptr div Alg))-Ptr;                                 // число байт, которые нужно вставить
         ACode:=InstCollection[Sel].ISETAlignCode;                     // код выравнивания
         Move(Buff[0],B,4);
         C:=4;
         Move(Buff[C],BBuff[0],B);                                     // временное копирование компилированной команды
         C:=0;
         while C<>A do
               begin
               Buff[4+C]:=(ACode shr ((C and 3)*8)) and 255;
               Inc(C);
               end;
         Move(BBuff[0],Buff[4+A],B);
         B:=B+A;
         Move(B,Buff[0],4);
         end;
   end;
if BBuff<>nil then FreeMem(BBuff);
CompileInstruction:=not EFlag;
end;


//------------------------------------------------------------------------------
// процедура компиляции строки данных
//------------------------------------------------------------------------------
function TMainForm.CompileDatas(var SLine: Longint; var ObjIndex: Longint; var Buff: PP; var Ptr: Longint): Boolean;
var
   VLength: Longint;
   VType: Byte;
   A,C,B,D,Ad: Longint;
   S,VarData, V,U,Uu: String;
   EFlag: Boolean;
   EB: Byte;
   Ext: Extended;
begin
// вычитывание названия переменной
V:=GetSourceLineFromSource(SrcBuffer,SLine);
GetWord(V,U);  // оператор данных
A:=GetCompilerWordType(U);
if (A shr 8)=2 then
   begin
   // установка длины элементов данных в байтах
   VType:=A;
   case (A and 255) of
        0: B:=1;     // BYTE
        1: B:=2;     // WORD
        2: B:=4;     // 'DWORD',    //2
        3: B:=8;     // 'QWORD',    //3
        4: B:=16;    // 'OWORD',    //4
        5: B:=4;     // 'SINGLE',   //5
        6: B:=8;     // 'DOUBLE',   //6
        7: B:=16;    // 'EXTENDED', //7
        else B:=0;
        end;
   // определение количества элементов данных
   S:=V;
   V:=V+',';
   VarData:=V;                         // копируем для будущей разборки строки
   C:=0;                               // число элементов данных
   while V<>'' do
         begin
         S:=Copy(V,1,Pos(',',V)-1);
         RemoveFirstSpaces(S);
         if (S[1]='''')and(S[Length(S)]='''') then C:=C+Length(S)-2
            else begin
                 GetWord(S,U);
                 if U='ARRAY'
                    then begin
                    // если определен массив
                    RemoveFirstSpaces(S);
                    if S='' then OutMessage(2,47,SLine,'',EFlag)
                       else if StrToIntDef(S,-1)<0 then OutMessage(2,47,SLine,'',EFlag)
                                                   else C:=C+StrToInt(S);
                    end
                    else Inc(C);
                 end;
         Delete(V,1,Pos(',',V));
         end;
   if C<>0 then
      begin
      VLength:=C*B;                     // длина данных
      A:=Ptr;
//      AlignPointer(A,B);
      D:=A-Ptr+4;                // смещение первого байта данных для размещения данных
      A:=VLength+(A-Ptr);
      ReallocMem(Buff,A+1024);
      FillChar(Buff[0],A+4,0);
      Move(A,Buff[0],4);       // длина буфера данных
      // D - текущий указатель позиции в буфере данных
      // B - количество байт, занимаемых одним элементом данных
      while VarData<>'' do
            begin
            // обработка по числу элементов данных
            V:=Copy(VarData,1,Pos(',',VarData)-1);
            RemoveFirstSpaces(V);
            if (V[1]='''')and(V[Length(V)]='''')
               then begin
                    V:=Copy(V,2,Length(V)-2);
                    while Length(V)<>0 do
                          begin
                          Buff[D]:=Ord(V[1]);
                          Delete(V,1,1);
                          Inc(D);
                          end;
                    end
            else if Pos('ARRAY ',V)=1
               then begin
                    Delete(V,1,Pos(' ',V));
                    D:=D+(B*StrToInt(V));
                    end
               else begin
                    // попытка найти в строке операторы адресной информации и заменить их на числа
                    U:='';
                    while V<>'' do
                          begin
                          if V[1]=' ' then U:=U+' ';
                          GetWord(V,Uu);
                          if (Uu='OFFSET') and (Length(Uu)=6)
                             then begin
                                  //  если смещение
                                  GetWord(V,Uu);
                                  Ad:=-1;
                                  if Uu<>'' then Ad:=GetLabelOffset(Uu,ObjectCollection,ObjIndex);
                                  if Ad<0 then OutMessage(2,79,SLine,'',EFlag);
                                  Uu:='0'+IntToHex(Ad div ObjectCollection.ObjectGran[ObjIndex],8)+'H';
                                  end
                             else if (U='DISPLACEMENT') and (Length(U)=12)
                                  then begin
                                       // если относительное смещение
                                       GetWord(V,Uu);
                                       Ad:=-1;
                                       if Uu<>'' then Ad:=GetLabelOffset(Uu,ObjectCollection,ObjIndex);
                                       if Ad<0 then OutMessage(2,79,SLine,'',EFlag);
                                       Uu:='0'+IntToHex((Ad-Ptr) div ObjectCollection.ObjectGran[ObjIndex],8)+'H';
                                       end;
                          U:=U+Uu;
                          end;
                    V:=U;
                    Eb:=ConvertExpression(V,Ext);
                    if Eb<>0 then OutMessage(2,33,SLine,'',EFlag)
                       else begin
                            // если было определено выражение
                            SetValueToBuffer(Buff,D,VType,Ext,A);
                            if A<>-1 then OutMessage(2,A,SLine,'',EFlag);
                            D:=D+B;
                            end;
                    end;
            Delete(VarData,1,Pos(',',VarData));
            end;
      end;
   end;
Result:=not EFlag;
end;

//------------------------------------------------------------------------------
// Формирование бинарных файлов
//------------------------------------------------------------------------------
function TMainForm.CreateSoftObjectFiles: Boolean;
var
   EFlag: Boolean;
   ProjDir: String;
   S: String;
   A,B,C: Longint;
   CrossList: TStringList;
begin
OutMessage(0,13,-1,'',EFlag);
EFlag:=false;
ProjDir:=SourceEdit.Text;
CrossList:=TStringList.Create;
if Pos('\',S)=0 then ProjDir:=''
   else begin
   B:=1;
   for A:=1 to Length(ProjDir) do if ProjDir[A]='\' then B:=A;
   ProjDir:=Copy(ProjDir,1,B);
   end;
for B:=0 to 2047 do
    case ObjectCollection.ObjectType[B] of
         // для объекта
         1: begin
            // запись двоичного объекта
            S:=ProjDir+StrPas(ObjectCollection.ObjectName[B])+'.BIN';
            C:=FileCreate(S);
            if C<=0
               then begin
                    OutMessage(3,21,-1,'',EFlag);
                    Break;
                    end
               else begin
                    FileWrite(C,ObjectCollection.BinaryDatas[B]^,ObjectCollection.BinaryCounts[B]);
                    FileClose(C);
                    end;
            // запись блока листинга
            S:=ProjDir+StrPas(ObjectCollection.ObjectName[B])+'.LST';
            C:=FileCreate(S);
            if C>0 then
               begin
               FileWrite(C,ObjectCollection.ListDatas[B]^,ObjectCollection.ListCounts[B]);
               FileClose(C);
               end;
            end;
         end;
CrossList.Free;
Result:=not EFlag;
end;

// отсчет времени компиляции
procedure TMainForm.MainTimerTimer(Sender: TObject);
begin
MainTimer.Tag:=MainTimer.Tag+1;
MainStatus.Panels[0].Text:=IntToStr(MainTimer.Tag)+' sec.';
MainStatus.Repaint;
end;

// close assembler
procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
   A,B: Longint;
   INI: TIniFile;
begin
INI:=TiniFile.Create(extractfilepath(paramstr(0))+'CAssm.ini');
if INI<>nil then
   begin
   A:=SourceEdit.Items.Count;
   if A>0 then
      for B:=0 to A-1 do INI.WriteString('History','File'+IntToStr(B),SourceEdit.Items[B]);
   INI.Free;
   end;
end;

end.
