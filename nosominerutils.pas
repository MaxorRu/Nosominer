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

function IsValidAddress(Address:String):boolean;
Procedure Showinfo(Text:String);
function Int2Curr(Value: int64): string;
function Sha256(StringToHash:string):string;
Function Parameter(LineText:String;ParamNumber:int64):String;
Procedure IncreaseHashSeed();
Procedure CreatePoolList();
Procedure LoadPoolList();
Procedure LoadPool(number:integer);
// MATHS
function BMDecTo58(numero:string):string;
function BMB58resumen(numero58:string):string;
Function BMDividir(Numero1,Numero2:string):DivResult;
function ClearLeadingCeros(numero:string):string;

implementation

Uses
  NosoMinerUnit;

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

Procedure Showinfo(Text:String);
Begin
Form1.TimerClearInfo.Enabled:=false;
form1.panel1.Caption:=text;
form1.Panel1.Width:=(length(text)*8);
form1.Panel1.left := 162 - (form1.Panel1.Width div 2);
form1.Panel1.top := 80;
form1.panel1.BringToFront;
form1.panel1.visible := true;
Form1.TimerClearInfo.Enabled:=true;
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

Procedure IncreaseHashSeed();
var
  LastChar : integer;
  contador: integer;
Begin
LastChar := Ord(MinerSeed[9])+1;
MinerSeed[9] := chr(LastChar);
for contador := 9 downto 1 do
   begin
   if Ord(MinerSeed[contador])>126 then
      begin
      MinerSeed[contador] := chr(33);
      MinerSeed[contador-1] := chr(Ord(MinerSeed[contador-1])+1);
      end;
   end;
End;

Procedure CreatePoolList();
var
  archivo : textfile;
Begin
assignfile(archivo,PoolListFilename);
rewrite(archivo);
writeln(archivo,'DevNoso 23.95.233.179 8082 UnMaTcHeD');
writeln(archivo,'nosopoolDE 199.247.3.186 8082 nosopoolDE');
writeln(archivo,'YZpool 81.68.115.175 8082 YZpool');
writeln(archivo,'sgnosopool sg.nosopool.com 2255 mama2255');
writeln(archivo,'usnosopool us.nosopool.com 2255 mama2255');
writeln(archivo,'YZpool2 148.70.153.167 8082 YZpool');
writeln(archivo,'Hodl 104.168.99.254 8082 Hodler');
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
randompool:=random(length(poolslist));
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

END.

