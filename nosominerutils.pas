unit nosominerutils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,strutils,DCPsha256;

Type
    DivResult = packed record
     cociente : string[255];
     residuo : string[255];
     end;

Procedure LaunchReconnection();
Procedure PlayBeep();
function GetTime():int64;
function IsValidAddress(Address:String):boolean;
function ShowHashrate(hashrate:int64):string;
Procedure UpdateDataGrid();
Procedure Showinfo(Texto:String);
function Int2Curr(Value: int64): string;
function Sha256(StringToHash:string):string;
Function Parameter(LineText:String;ParamNumber:int64):String;
function IncreaseHashSeed(Seed:string):string;
Procedure CreatePoolList();
Procedure LoadPoolList();
Procedure LoadPool(number:integer);
Procedure ResetData();
// MATHS
function BMDecTo58(numero:string):string;
function BMB58resumen(numero58:string):string;
Function BMDividir(Numero1,Numero2:string):DivResult;
function ClearLeadingCeros(numero:string):string;
// NEW
Procedure ResetThreads();
Procedure UpdateMinerNums();
function GetMaximunCore():int64;
function SecondsToTime(seconds:integer):string;

implementation

Uses
  NosoMinerUnit;

Procedure LaunchReconnection();
Begin
Reconnecting := true;
ReconTime := 5;
Form1.TimerRecon.Enabled:=true;
End;

Procedure PlayBeep();
Begin
If form1.CheckBox2.Checked then beep;
End;

function GetTime():int64;
Begin
result := (Trunc((Now - EncodeDate(1970, 1 ,1)) * 24 * 60 * 60));
end;

function IsValidAddress(Address:String):boolean;
var
  OrigHash : String;
  Clave:String;
Begin
OrigHash := Copy(Address,2,length(address)-3);
Clave := BMDecTo58(BMB58resumen(OrigHash));
OrigHash := 'N'+OrigHash+clave;
If OrigHash = Address then result := true else result := false;
End;

// display a hasrate in the correct way
function ShowHashrate(hashrate:int64):string;
var
  divisions : integer = 0;
  HRStr : string;
Begin
if hashrate >= 10000 then
   begin
   repeat
      Hashrate := Hashrate div 1000;
      divisions +=1;
   until hashrate < 10000;
   end;
if divisions = 0 then HRstr := ' Kh/s'
else if divisions = 1 then HRstr := ' Mh/s'
else if divisions = 2 then HRstr := ' Gh/s'
else if divisions = 3 then HRstr := ' Th/s'
else if divisions = 4 then HRstr := ' Ph/s';
result := InttoStr(Hashrate)+ HRstr;
End;

Procedure UpdateDataGrid();
Begin
form1.DataGrid.Cells[1,0]:=IntToStr(Targetblock);
form1.DataGrid.Cells[1,1]:=IntToStr(TargetDiff);
form1.DataGrid.Cells[1,2]:=IntToStr(foundedsteps);
form1.DataGrid.Cells[1,3]:=IntToStr(TargetChars);
form1.DataGrid.Cells[1,4]:=IntToStr(GetTime-LastPingReceived);
form1.DataGrid.Cells[1,5]:=IntToStr(Length(ArrNext));
if TimeStartMiner>0 then Form1.labeldebug.Caption:=SecondsToTime(GetTime-TimeStartMiner)
else Form1.labeldebug.Caption:='00:00:00';
Form1.LabelTotal.Caption:=IntToStr(TotalFound);
Form1.LabelEarned.Caption:=int2curr(Earned);
End;

Procedure Showinfo(Texto:String);
Begin
form1.PanelInfo.BringToFront;
form1.PanelInfo.Top:=80;
Form1.TimerClearInfo.Enabled:=false;
if form1.LabelInfo.Caption<>'' then
   begin
   form1.LabelInfo.Caption := form1.LabelInfo.Caption+slinebreak+texto;
   form1.PanelInfo.Height:=form1.PanelInfo.Height+10;
   form1.PanelInfo.top := form1.PanelInfo.top-5;
   end
else form1.LabelInfo.Caption := texto;
form1.PanelInfo.visible := true;
Form1.TimerClearInfo.Enabled:=true;
if not OfficialRelease then form1.Memo1.Lines.Add(texto);
End;

function Int2Curr(Value: int64): string;
begin
Result := IntTostr(Abs(Value));
result :=  AddChar('0',Result, 9);
Insert('.',Result, Length(Result)-7);
If Value <0 THen Result := '-'+Result;
end;

function Sha256(StringToHash:string):string;
var
  Hash: TDCP_sha256;
  Digest: array[0..31] of byte;  // sha256 produces a 256bit digest (32bytes)
  Source: string;
  i: integer;
  str1: string;
begin
Source:= StringToHash;  // here your string for get sha256
if Source <> '' then
   begin
   Hash:= TDCP_sha256.Create(nil);  // create the hash
   Hash.Init;                        // initialize it
   Hash.UpdateStr(Source);
   Hash.Final(Digest);               // produce the digest
   str1:= '';
   for i:= 0 to 31 do
   str1:= str1 + IntToHex(Digest[i],2);
   Result:=UpperCase(str1);         // display the digest in capital letter
   Hash.Free;
   end;
end;

Function Parameter(LineText:String;ParamNumber:int64):String;
var
  Temp : String = '';
  ThisChar : Char;
  Contador : int64 = 1;
  WhiteSpaces : int64 = 0;
  parentesis : boolean = false;
Begin
while contador <= Length(LineText) do
   begin
   ThisChar := Linetext[contador];
   if ((thischar = '(') and (not parentesis)) then parentesis := true
   else if ((thischar = '(') and (parentesis)) then
      begin
      result := '';
      exit;
      end
   else if ((ThisChar = ')') and (parentesis)) then
      begin
      if WhiteSpaces = ParamNumber then
         begin
         result := temp;
         exit;
         end
      else
         begin
         parentesis := false;
         temp := '';
         end;
      end
   else if ((ThisChar = ' ') and (not parentesis)) then
      begin
      WhiteSpaces := WhiteSpaces +1;
      if WhiteSpaces > Paramnumber then
         begin
         result := temp;
         exit;
         end;
      end
   else if ((ThisChar = ' ') and (parentesis) and (WhiteSpaces = ParamNumber)) then
      begin
      temp := temp+ ThisChar;
      end
   else if WhiteSpaces = ParamNumber then temp := temp+ ThisChar;
   contador := contador+1;
   end;
if temp = ' ' then temp := '';
Result := Temp;
End;

function IncreaseHashSeed(Seed:string):string;
var
  LastChar : integer;
  contador: integer;
Begin
LastChar := Ord(Seed[9])+1;
Seed[9] := chr(LastChar);
for contador := 9 downto 1 do
   begin
   if Ord(Seed[contador])>126 then
      begin
      Seed[contador] := chr(33);
      Seed[contador-1] := chr(Ord(Seed[contador-1])+1);
      end;
   end;
result := StringReplace(seed,'(','~',[rfReplaceAll, rfIgnoreCase])
End;

Procedure CreatePoolList();
var
  archivo : textfile;
Begin
assignfile(archivo,PoolListFilename);
rewrite(archivo);
writeln(archivo,'DevNoso 23.95.233.179 8084 UnMaTcHeD');
writeln(archivo,'nosopoolDE 199.247.3.186 8082 nosopoolDE');
writeln(archivo,'YZpool 81.68.115.175 8082 YZpool');
writeln(archivo,'Hodl 104.168.99.254 8082 Hodler');
writeln(archivo,'DogFaceDuke noso.dukedog.io 8082 duke');
closefile(archivo);
End;

Procedure LoadPoolList();
var
  archivo : textfile;
  Linea, name,ip,port,pass : String;
  randompool : integer;
Begin
Form1.ComboPool.Enabled:=true;
setlength(poolslist,0);
assignfile(archivo,PoolListFilename);
reset(archivo);
while not eof(archivo) do
   begin
   readln(archivo,linea);
   name := parameter(linea,0);
   ip := parameter(linea,1);
   port := parameter(linea,2);
   pass := parameter(linea,3);
   setlength(poolslist,length(poolslist)+1);
      poolslist[length(poolslist)-1].name:=name;
      poolslist[length(poolslist)-1].ip:=ip;
      poolslist[length(poolslist)-1].port:=StrToIntDef(port,8082);
      poolslist[length(poolslist)-1].pass:=pass;
      Form1.ComboPool.Items.Add(name);
   end;
closefile(archivo);
randompool:=0;//random(length(poolslist));
if length(poolslist)> 0 then loadpool(randompool)
else
   begin
   Form1.ComboPool.Items.Add('No pools');
   Form1.ComboPool.Enabled:=false;
   end;
Form1.ComboPool.ItemIndex:=randompool;
End;

Procedure LoadPool(number:integer);
Begin
form1.labelededit1.Text:=poolslist[number].ip;
form1.labelededit3.Text:=IntToStr(poolslist[number].port);
form1.labelededit4.Text:=poolslist[number].pass;
End;

Procedure ResetData();
Begin
Velocidad := 0;
Balance := 0;
PoolHashRate := 0;
lastpago := 0;
esteintervalo := 0;
Lastintervalo := 0;
End;


// ***MATHS***

// CONVERTS A DECIMAL VALUE TO A BASE58 STRING
function BMDecTo58(numero:string):string;
var
  decimalvalue : string;
  restante : integer;
  ResultadoDiv : DivResult;
  Resultado : string = '';
Begin
decimalvalue := numero;
while length(decimalvalue) >= 2 do
   begin
   ResultadoDiv := BMDividir(decimalvalue,'58');
   DecimalValue := Resultadodiv.cociente;
   restante := StrToInt(ResultadoDiv.residuo);
   resultado := B58Alphabet[restante+1]+resultado;
   end;
if StrToInt(decimalValue) >= 58 then
   begin
   ResultadoDiv := BMDividir(decimalvalue,'58');
   DecimalValue := Resultadodiv.cociente;
   restante := StrToInt(ResultadoDiv.residuo);
   resultado := B58Alphabet[restante+1]+resultado;
   end;
if StrToInt(decimalvalue) > 0 then resultado := B58Alphabet[StrToInt(decimalvalue)+1]+resultado;
result := resultado;
End;

function BMB58resumen(numero58:string):string;
var
  counter, total : integer;
Begin
total := 0;
for counter := 1 to length(numero58) do
   begin
   total := total+Pos(numero58[counter],B58Alphabet)-1;
   end;
result := IntToStr(total);
End;

Function BMDividir(Numero1,Numero2:string):DivResult;
var
  counter : integer;
  cociente : string = '';
  long : integer;
  Divisor : Int64;
  ThisStep : String = '';
Begin
long := length(numero1);
Divisor := StrToInt64(numero2);
for counter := 1 to long do
   begin
   ThisStep := ThisStep + Numero1[counter];
   if StrToInt(ThisStep) >= Divisor then
      begin
      cociente := cociente+IntToStr(StrToInt(ThisStep) div Divisor);
      ThisStep := (IntToStr(StrToInt(ThisStep) mod Divisor));
      end
   else cociente := cociente+'0';
   end;
result.cociente := ClearLeadingCeros(cociente);
result.residuo := ClearLeadingCeros(thisstep);
End;

function ClearLeadingCeros(numero:string):string;
var
  count : integer = 0;
  movepos : integer = 0;
Begin
result := '';
if numero[1] = '-' then movepos := 1;
for count := 1+movepos to length(numero) do
   begin
   if numero[count] <> '0' then result := result + numero[count];
   if ((numero[count]='0') and (length(result)>0)) then result := result + numero[count];
   end;
if result = '' then result := '0';
if ((movepos=1) and (result <>'0')) then result := '-'+result;
End;

// *** NEW FUNCTIONS ***

Procedure ResetThreads();
var
  counter : integer;
Begin
for counter := 0 to Maxcpu-1 do
   begin
   ArrMinerNums[counter].seed := MinerPrefix;
   ArrMinerNums[counter].number := 100000000+counter;
   ArrMinerNums[counter].increases:=0;
   end;
SetLength(ArrNext,0);
Velocidad := 0;
TotalHashes := 0;
Esteintervalo := 0;
Lastintervalo := 0;
BlockSeconds := GetTime;
End;

Procedure UpdateMinerNums();
var
  counter : integer;
Begin
for counter := 0 to Maxcpu-1 do
   begin
   Form1.GridCores.Cells[0,counter+1]:= ArrMinerNums[counter].seed;
   Form1.GridCores.Cells[1,counter+1]:= IntToStr(ArrMinerNums[counter].number);
   end;
End;

function GetMaximunCore():int64;
var
  counter : integer;
  Thiscore : int64;
Begin
result := 0;
for counter := 0 to Cpusforminning-1 do
   begin
   thiscore := (ArrMinerNums[counter].increases*900000000)+(ArrMinerNums[counter].number-100000000);
   if thiscore > result then
      result := thiscore;
   end;
End;

function SecondsToTime(seconds:integer):string;
var
  Thishours,thisminutes,thisseconds,remaining : integer;
Begin
thishours := seconds div 3600;
remaining := seconds mod 3600;
thisminutes := remaining div 60;
thisseconds := remaining mod 60;
result := AddChar('0',IntToStr(Thishours),2)+':'+AddChar('0',IntToStr(thisminutes),2)+
   ':'+AddChar('0',IntToStr(thisseconds),2);
End;

END.

