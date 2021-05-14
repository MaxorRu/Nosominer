unit NosoMinerUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, Menus, IdTCPClient, IdGlobal, strutils, nosominerutils,
  lclintf, ComCtrls, Grids, crt, NosoMinerlanguage, UTF8Process;

type

  MinerData = packed record
     address : string[35];
     autocon : boolean;
     cpus : integer;
     sound : boolean;
     language : integer;
     end;

  PoolData = Packed record
     name : string[20];
     ip : string[15];
     port : integer;
     pass : string[20];
     end;

  NextStep = Packed Record
     Chars : integer;
     seed : string[9];
     number : integer;
     end;

  ThreadData = Packed Record
     seed : string[9];
     number : int64;
     increases : int64;
     end;

  TThreadMiner = class(TThread)
    procedure Execute; override;
  end;

  TThreadReadPool = class(TThread)
    procedure Execute; override;
  end;

  TCredentials = Packed record
     ip : string[15];
     Port : integer;
     pass : string[20];
     end;

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBoxMode: TCheckBox;
    ComboBox1: TComboBox;
    ComboPool: TComboBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    LabelEarned: TLabel;
    labvelocidad: TLabel;
    LabelTotal: TLabel;
    labeldebug: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    LabelInfo: TLabel;
    LabeledEdit1: TLabeledEdit;
    LabeledEdit2: TLabeledEdit;
    LabeledEdit3: TLabeledEdit;
    LabeledEdit4: TLabeledEdit;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    PanelData: TPanel;
    PanelInfo: TPanel;
    DataGrid: TStringGrid;
    GridCores: TStringGrid;
    TextBalance: TStaticText;
    TimerLatido: TTimer;
    TimerClearInfo: TTimer;
    TimerRecon: TTimer;
    TrayIcon1: TTrayIcon;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure CheckBox2Change(Sender: TObject);
    procedure CheckBox3Change(Sender: TObject);
    procedure CheckBoxModeChange(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure ComboPoolChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
    procedure MenuItem11Click(Sender: TObject);
    procedure MenuItem12Click(Sender: TObject);
    procedure MenuItem13Click(Sender: TObject);
    procedure MenuItem14Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure MenuItem4Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure MenuItem7Click(Sender: TObject);
    procedure MenuItem8Click(Sender: TObject);
    procedure MenuItem9Click(Sender: TObject);
    procedure TimerLatidoTimer(Sender: TObject);
    procedure TimerClearInfoTimer(Sender: TObject);
    procedure TimerReconTimer(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
  private

  public

  end;

Procedure CreateDataFile();
Procedure LoadDataFile();
Procedure SaveDataFile();
Procedure StartMiners();
function ConnectPoolClient():integer;
Procedure DisconnectPoolClient();

Procedure SendPoolMessage(mensaje:string);
Procedure SendPoolStep(lengthstep:integer);
function PoolRequestPayment():boolean;
Procedure SendPoolPing();

Procedure StopMiner();
Procedure LockControls();
Procedure UnLockControls();
Procedure AddNextStep(thisSeed:String;ThisNumber, chars:integer);
Procedure VerifyNext();
Procedure ProcessThisLine(Linea:string);
Procedure ReadDataFromLine(Linea:string);

Const
  DataFileName = 'config.txt';
  PoolListFilename = 'poollist.txt';
  minerversion = '1.70';
  B58Alphabet : string = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  B16Alphabet : string = '0123456789ABCDEF';
  OfficialRelease = true;

var
  Form1: TForm1;
  UserData :MinerData;                    // Data stored of the miner
  MaxCPU : integer;                       // maximun number of cpus allowed
  CanalPool : TIdTCPClient;               // the channel to connect with the server
  balance : int64 = 0;                    // the user balance in th the pool
  lastpago : integer;                     // time to next payment
  TargetBlock : integer = 0;              // target block for miner
    lastblock : integer;                  // last block mined
  TargetString: string = '';              // string for solution
  TargetChars: integer = 0;
  TargetDiff : integer = 0;
  foundedsteps : integer;
  MinerSeed : string;
  MINERON : boolean = false;
  thisstep : string;
  esteintervalo,lastintervalo,velocidad : int64;
  TotalHashes, BlockSeconds : int64;
  MinerThreads: array of TThreadMiner;
  ArrMinerNums : array of ThreadData;
    TCounter : integer;
  ReadPool : TThreadReadPool;
    Reading : boolean = false;
  Cpusforminning : integer;
  PoolHashRate : int64 = 0;
  PaymentRequested : boolean = false;
  PoolsList : array of pooldata;
  ConData : TCredentials;
  Earned : int64 = 0;
  LangLine : TStringList;
  CurrLang : integer = 0;

  Lastpingsend : int64 = 0;
  Lastpingreceived : int64 = 0;
  TotalFound : integer = 0;
  ProcessLines: TstringList;
  ArrNext : Array of NextStep;

  lastbuttonclick : int64;

  FirstShow : boolean = true;
  TimeStartMiner : int64;
  ConnectTry : Boolean = false;
  Waitingforjoin : integer = 0;

  MinerAddress : String = '';
  MinerPrefix : String = '';

  Reconnecting : boolean = false;
  ReconTime : Integer = 5;

  Launching : boolean = true;
  PooDeepSteps : integer = 3;


implementation

{$R *.lfm}

{ TForm1 }

// ***FORM 1***

// CREATE
procedure TForm1.FormCreate(Sender: TObject);
var
  contador : integer;
begin
LangLine := TstringList.Create;
PanelData.Top:=68;
CanalPool := TIdTCPClient.Create(form1);
ProcessLines := TStringList.Create;
TimerRecon.Enabled:=false;
TimerClearInfo.Enabled:=false;
form1.Height:=207;
form1.Width:=324;
if not fileexists(PoolListFilename) then CreatePoolList;
LoadPoolList;
MaxCPU:= {$IFDEF UNIX}GetSystemThreadCount{$ELSE}GetCPUCount{$ENDIF};
setlength(MinerThreads,MaxCPU);
setlength(ArrMinerNums,MaxCPU);
GridCores.RowCount:=MaxCPU+1;
for contador := 1 to MaxCPU do
   ComboBox1.Items.Add(IntToStr(contador));
if fileexists(DataFileName) then LoadDataFile() else CreateDataFile();
LoadLanguage(userdata.language);
form1.Caption:=LangLine[0]+minerversion;
label3.Caption:=langLine[1];
ComboBox1.ItemIndex:=Userdata.cpus-1;
checkbox3.Checked:=userdata.autocon;
checkbox2.Checked:=userdata.sound;
Launching := false;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
if FirstShow then
   begin
   Paneldata.Visible:=false;
   TimerLatido.Enabled:=true;
   end;
FirstShow := false;
if userdata.autocon then LaunchReconnection();
end;

// CLOSE QUERY
procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
showinfo(LangLine[2]);
Mineron := false;
sleep(100);
application.Terminate;
end;

// CPU NUMBER CHANGE
procedure TForm1.ComboBox1Change(Sender: TObject);
begin

end;

// POOL SELECTION CHANGE
procedure TForm1.ComboPoolChange(Sender: TObject);
begin
LoadPool(ComboPool.ItemIndex);
end;

// ************
// ***MINER****
// ************

// EXECUTE
procedure TThreadMiner.Execute;
var
  solucion : string = '';
  Mseed,Mnumber : string;
  TNumber : integer;
  TSeed : String;
  ThreadNumber : integer;
begin
ThreadNumber := TCounter;
TNumber := ArrMinerNums[ThreadNumber].number;
TSeed := ArrMinerNums[ThreadNumber].seed;
Repeat
   //TotalHashes +=1;
   if TNumber > 999999999 then
      begin
      TSeed := IncreaseHashSeed(TSeed);
      TNumber := TNumber-900000000;
      ArrMinerNums[ThreadNumber].increases+=1;
      end;
   ArrMinerNums[ThreadNumber].number := TNumber;
   ArrMinerNums[ThreadNumber].seed := TSeed;
   Mseed := TSeed;
   Mnumber := IntToStr(TNumber);
   Solucion := Sha256(Mseed+MinerAddress+Mnumber);
   if (AnsiContainsStr(Solucion,copy(TargetString,1,Targetchars))) then
      ProcessLines.Add('MYSTEP '+Mseed+Mnumber)
   else if (AnsiContainsStr(Solucion,copy(TargetString,1,Targetchars-1))) then
      ProcessLines.Add('MYSTEP '+Mseed+Mnumber+' '+IntToStr(Targetchars-1))
   else if (AnsiContainsStr(Solucion,copy(TargetString,1,Targetchars-2))) then
      ProcessLines.Add('MYSTEP '+Mseed+Mnumber+' '+IntToStr(Targetchars-2))
   else if (AnsiContainsStr(Solucion,copy(TargetString,1,Targetchars-3))) then
      ProcessLines.Add('MYSTEP '+Mseed+Mnumber+' '+IntToStr(Targetchars-3));
   TNumber := TNumber+Cpusforminning;
until Not Mineron;
end;

Procedure AddNextStep(thisSeed:String;ThisNumber,chars:integer);
var
  dato :NextStep;
Begin
if chars < (TargetDiff div 10) then exit;
Dato.seed:=thisseed;
Dato.number:=thisnumber;
Dato.Chars:=Chars;
Insert(dato,ArrNext,length(ArrNext));
Processlines.Add('NEXTSTEP: '+IntToStr(Dato.Chars)+' '+thisseed+IntToStr(thisnumber));
End;

Procedure VerifyNext();
var
  counter : integer;
  founded : boolean = false;
Begin
if length(arrnext)>0 then
   begin
   for counter := 0 to length(arrnext)-1 do
      begin
      if arrnext[counter].Chars = Targetchars then
         begin
         ProcessLines.Add('MYSTEP '+arrnext[counter].seed+IntToStr(arrnext[counter].number));
         founded := true;
         end;
      end;
   end;
if founded then Setlength(arrnext,0);
End;

// ***************
// ***DATA FILE***
// ***************

// CREATE
Procedure CreateDataFile();
var
  thisfile: textfile;
Begin
assignfile(thisfile,Datafilename);
rewrite(thisfile);
writeln(thisfile,'address ');
writeln(thisfile,'autocon false');
writeln(thisfile,'cpus 1');
writeln(thisfile,'sound false');
writeln(thisfile,'lang 0');
writeln(thisfile,'condata ');
closefile(thisfile);
userdata.address:='';
userdata.autocon:=false;
userdata.cpus:=1;
userdata.sound:=false;
userdata.language:=0;
End;

// LOAD
Procedure LoadDataFile();
var
  thisfile: textfile;
  linea : string;
Begin
assignfile(thisfile,Datafilename);
reset(thisfile);
while not eof(thisfile) do
   begin
   readln(thisfile,linea);
   if parameter(linea,0) = 'address' then userdata.address := parameter(linea,1);
   if parameter(linea,0) = 'autocon' then userdata.autocon := StrToBoolDef(parameter(linea,1),false);
   if parameter(linea,0) = 'cpus' then userdata.cpus := StrToIntDef(parameter(linea,1),1);
   if parameter(linea,0) = 'sound' then userdata.sound := StrToBooldef(parameter(linea,1),false);
   if parameter(linea,0) = 'lang' then userdata.language := StrToIntDef(parameter(linea,1),0);
   if parameter(linea,0) = 'condata' then
      begin
      form1.LabeledEdit1.Text:=parameter(linea,1);
      form1.LabeledEdit3.Text:=parameter(linea,2);
      form1.LabeledEdit4.Text:=parameter(linea,3);
      end;
   end;
closefile(thisfile);
form1.LabeledEdit2.Text:=userdata.address;
form1.ComboBox1.ItemIndex:=userdata.cpus-1;
form1.CheckBox2.Checked:=userdata.sound;
End;

// SAVE
Procedure SaveDataFile();
var
  thisfile: textfile;
Begin
assignfile(thisfile,Datafilename);
rewrite(thisfile);
writeln(thisfile,'address '+userdata.address);
writeln(thisfile,'autocon '+booltostr(form1.CheckBox3.Checked));
writeln(thisfile,'cpus '+IntToStr(form1.ComboBox1.ItemIndex+1));
writeln(thisfile,'sound '+booltostr(form1.CheckBox2.Checked));
writeln(thisfile,'lang '+IntToStr(userdata.language));
writeln(thisfile,'condata '+form1.LabeledEdit1.Text+' '+form1.LabeledEdit3.Text+' '+form1.LabeledEdit4.Text);
closefile(thisfile);
End;

// ***************
// ***MAIN MENU***
// ***************

// MAIN MENU : SAVE
procedure TForm1.MenuItem2Click(Sender: TObject);
begin
SaveDataFile();
end;

// MAIN MENU : EXIT POOL
procedure TForm1.MenuItem3Click(Sender: TObject);
begin

end;

// MAIN MENU : HELP
procedure TForm1.MenuItem4Click(Sender: TObject);
begin
OpenDocument('http://nosocoin.com/NOSOMINER-FAQ.html');
end;

// MAIN MENU : CLOSE
procedure TForm1.MenuItem5Click(Sender: TObject);
begin
showinfo(LangLine[2]);
Mineron := false;
sleep(100);
application.Terminate;
end;

// MAIN MENU : ENGLISH
procedure TForm1.MenuItem7Click(Sender: TObject);
begin
if CurrLAng <> 0 then LoadLanguage(0);
SaveDataFile();
end;

// MAIN MENU : ESPAÑOL
procedure TForm1.MenuItem8Click(Sender: TObject);
begin
if CurrLAng <> 1 then LoadLanguage(1);
SaveDataFile();
end;

procedure TForm1.MenuItem9Click(Sender: TObject);
begin
if CurrLAng <> 2 then LoadLanguage(2);
SaveDataFile();
end;

procedure TForm1.MenuItem10Click(Sender: TObject);
begin
if CurrLAng <> 3 then LoadLanguage(3);
SaveDataFile();
end;

procedure TForm1.MenuItem11Click(Sender: TObject);
begin
if CurrLAng <> 4 then LoadLanguage(4);
SaveDataFile();
end;

procedure TForm1.MenuItem12Click(Sender: TObject);
begin
if CurrLAng <> 5 then LoadLanguage(5);
SaveDataFile();
end;

procedure TForm1.MenuItem13Click(Sender: TObject);
begin
if CurrLAng <> 6 then LoadLanguage(6);
SaveDataFile();
end;

procedure TForm1.MenuItem14Click(Sender: TObject);
begin
if CurrLAng <> 7 then LoadLanguage(7);
SaveDataFile();
end;

// **************
// ***TRAYICON***
// **************

// RESTORE FROM TRAY
procedure TForm1.TrayIcon1DblClick(Sender: TObject);
begin
TrayIcon1.visible:=false;
Form1.WindowState:=wsNormal;
Form1.Show;
end;

// MINIMIZE TO TRAY
procedure TForm1.FormWindowStateChange(Sender: TObject);
begin
if checkbox1.Checked then
   if Form1.WindowState = wsMinimized then
      begin
      TrayIcon1.visible:=true;
      form1.hide;
      end;
end;

// ************
// ***TIMERS***
// ************

// TimerLatido: MINER INTERVAL (200)
procedure TForm1.TimerLatidoTimer(Sender: TObject);
begin
UpdateDataGrid();
TimerLatido.Enabled:=false;
if Waitingforjoin>0 then
   begin
   Waitingforjoin := Waitingforjoin-200;
   if Waitingforjoin <= 0 then
      begin // cancel connection procedure

      end;
   end;
While processlines.Count>0 do
   begin
   ProcessThisLine(Processlines[0]);
   Processlines.Delete(0);
   end;
if mineron then
   begin
   //if not canalpool.Connected then ConnectPoolClient();
   esteintervalo := GetMaximunCore div 1000;
   LastIntervalo := (GetTime-BlockSeconds)+1;
   velocidad :=  (esteintervalo div LastIntervalo) * 2;
   Labvelocidad.Caption:=ShowHashrate(velocidad)+slinebreak+inttostr(lastintervalo)+' s';
   if form1.checkboxMode.Checked then UpdateMinerNums;
   if lastpingsend+5<GetTime then
      begin
      LastPingSend := GetTime;
      SendPoolPing();
      end;
   if lastpingreceived+20<GetTime then
      begin
      BitBtn2Click(BitBtn2);
      LaunchReconnection();
      end;
   label3.Caption:=inttoStr(velocidad)+' Kh';
   form1.Label5.Caption:= MinerPrefix+slinebreak+copy(MinerAddress,1,6)+'...';
   form1.Label6.Caption:=ShowHashrate(poolhashrate);
   if form1.TrayIcon1.Visible then
      form1.TrayIcon1.Hint:=LangLine[63]+IntToStr(velocidad)+' Kh';
   if lastpago > 0 then label2.Hint:=LangLine[62];
   end
else                         // NOT MINERON
   begin
   form1.TrayIcon1.Hint:=LangLine[3];
   label2.Hint:=LangLine[4];
   end;
if lastpago<=0 then
   begin
   label2.Caption:=IntToStr(lastpago);
   PaymentRequested := false;
   end
else
   begin
   if ((not PaymentRequested) and (balance>0) and (PoolRequestPayment)) then
      begin
      PaymentRequested := true;
      label2.Caption := LangLine[5];
      end;
   end;
TextBalance.Caption:= Int2Curr(balance);
if canalpool.Connected then image1.Visible:=true
else image1.Visible:=false;
if ( (canalpool.Connected) and (not Reading) ) then
   begin
   ReadPool := TThreadReadPool.Create(true);
   ReadPool.FreeOnTerminate:=true;
   ReadPool.Start;
   end;
TimerLatido.Enabled:=true;
end;

// TIMERCLEAR INFO: REMOVE INFO PANEL (2000)
procedure TForm1.TimerClearInfoTimer(Sender: TObject);
begin
TimerClearInfo.Enabled:=false;
PanelInfo.Top:=80;
PanelInfo.Height:=37;
LabelInfo.Caption:='';
PanelInfo.visible := false;
end;

// TIMER RECONNECT
procedure TForm1.TimerReconTimer(Sender: TObject);
begin
TimerRecon.Enabled:=false;
ReconTime := ReconTime-1;
if ((ReconTime = 0) and (Reconnecting)) then form1.BitBtn1Click(BitBtn1)
else
  begin
  form1.Memo1.Lines.Add(LangLine[6]+IntToStr(ReconTime)+LangLine[7]);
  TimerRecon.Enabled:=true;
  end;
end;

Procedure StartMiners();
Begin
mineron := false;
delay(100);
mineron := true;
if lastblock <> TargetBlock then
   begin
   ResetThreads;
   end;
lastblock := TargetBlock;
UpdateDataGrid();
Cpusforminning := form1.ComboBox1.ItemIndex+1;
form1.memo1.Lines.Add(LangLine[8]+inttoStr(Cpusforminning)+LangLine[9]);
form1.combobox1.Enabled:=false;

for TCounter := 0 to Cpusforminning-1 do
   begin
   MinerThreads[TCounter] := TThreadMiner.Create(true);
   MinerThreads[TCounter].FreeOnTerminate:=true;
   MinerThreads[TCounter].Start;
   Delay(25);
   end;

End;

Procedure StopMiner();
Begin
if assigned(ReadPool) then
   begin
   Readpool.Terminate;
   reading := false;
   end;
Reconnecting := false;
Form1.TimerRecon.Enabled:=false;
ResetData;
mineron := false;
delay(10);
If canalpool.Connected then DisconnectPoolClient;
UnLockControls;
End;

Procedure LockControls();
Begin
ConnectTry := true;
form1.bitbtn1.visible:=false;
form1.bitbtn2.visible:=true;
form1.LabeledEdit1.Enabled:=false;
form1.LabeledEdit2.Enabled:=false;
form1.LabeledEdit3.Enabled:=false;
form1.LabeledEdit4.Enabled:=false;
form1.Label2.Visible:=true;
form1.Label3.Visible:=true;
form1.Label6.Visible:=true;
form1.TextBalance.Visible:=true;
form1.TextBalance.Visible:=true;
form1.combobox1.Enabled:=false;
form1.combopool.visible:=false;
Form1.PanelData.Visible:=true;
if form1.PanelInfo.Visible then form1.PanelInfo.BringToFront;
End;

Procedure UnLockControls();
Begin
ConnectTry := false;
form1.bitbtn1.visible:=true;
form1.bitbtn2.visible:=false;
form1.LabeledEdit1.Enabled:=true;
form1.LabeledEdit2.Enabled:=true;
form1.LabeledEdit3.Enabled:=true;
form1.LabeledEdit4.Enabled:=true;
form1.combopool.visible:=true;
form1.Label2.Visible:=false;
form1.Label3.Visible:=false;
form1.Label6.Visible:=false;
form1.TextBalance.Visible:=false;
form1.TextBalance.Visible:=false;
form1.combobox1.Enabled:=true;
Form1.PanelData.Visible:=false;
End;

// ***************
// *** BUTTONS ***
// ***************

procedure TForm1.BitBtn1Click(Sender: TObject);
var
  Connectionvalue : integer = 0;
begin
if lastbuttonclick = GetTime then exit;
lastbuttonclick := GetTime;
LockControls;
userdata.address:=labelededit2.Text;
condata.ip := labelededit1.Text;
condata.port := StrToIntDef(labelededit3.Text,8082);
condata.pass:= labelededit4.Text;
if length(userdata.address)<5 then
   begin
   showinfo(LangLine[10]);
   UnlockCOntrols;
   exit;
   end;
Connectionvalue := ConnectPoolClient();
if Connectionvalue = 0 then
   begin
   showinfo(LangLine[11]);
   if checkbox2.Checked then PlayBeep;
   UnlockCOntrols;
   if reconnecting then LaunchReconnection();
   end
else if Connectionvalue = 10 then
   begin
   Showinfo(LangLine[12]);
   TimeStartMiner := GetTime;
   SendPoolMessage(condata.pass+' '+userdata.address+' JOIN '+MinerVersion);
   Showinfo(LangLine[13]);
   Waitingforjoin := 5000;
   end
End;

procedure TForm1.BitBtn2Click(Sender: TObject);
begin
if not reconnecting then TimeStartMiner := 0;
Reconnecting := false;
StopMiner();
end;

procedure TForm1.CheckBox2Change(Sender: TObject);
begin
if not Launching then SaveDatafile();
end;

procedure TForm1.CheckBox3Change(Sender: TObject);
begin
if not Launching then SaveDatafile();
end;

// Change showmode
procedure TForm1.CheckBoxModeChange(Sender: TObject);
begin
if checkboxmode.Checked then
   begin
   form1.Width:=555;
   form1.Height:=500;
   end
else
   begin
   form1.Height:=207;
   form1.Width:=324;
   end;
end;

// CLIENTE

function ConnectPoolClient():Integer;
Begin
result := 0;
if canalpool.Connected then exit;
CanalPool.Host:=condata.ip;
CanalPool.Port:=condata.port;
canalpool.ConnectTimeout:=2000;
try
   canalpool.Connect;
   Result := 10;
Except on E:Exception do
   begin
   result := 0;
   Processlines.Add('EXCEP-01:'+E.Message);
   if form1.checkbox2.Checked then Playbeep;
   end;
end;
End;

Procedure DisconnectPoolClient();
Begin
TRY
   canalpool.IOHandler.InputBuffer.Clear;
   canalpool.Disconnect;
EXCEPT on E:Exception do
   begin
   Processlines.Add(langline[14]+E.Message);
   end;
END;
End;

Procedure SendPoolMessage(mensaje:string);
Begin
try
   if canalpool.Connected then
      begin
      canalpool.IOHandler.WriteLn(mensaje);
      end;
Except On E:Exception do
   Processlines.Add(LangLine[15]+E.Message);
end;
End;

Procedure SendPoolStep(lengthstep:integer);
Begin
try
if not canalpool.Connected then ConnectPoolClient();
   if CanalPool.Connected then
      SendPoolMessage(condata.pass+' '+userdata.Address+' STEP '+IntToStr(targetblock)+' '+copy(thisstep,1,9)+' '+copy(thisstep,10,9)+' '+IntToStr(lengthstep))
   else Processlines.Add(LangLine[16]);
Except On E:Exception do
   Processlines.Add(LangLine[17]+E.Message);
end;
End;

function PoolRequestPayment():boolean;
Begin
result := false;
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(condata.pass+' '+userdata.address+' PAYMENT');
      Processlines.Add(LangLine[18]);
      result:= true;
      end
   else Processlines.Add(LangLine[19]);
Except On E:Exception do
   Processlines.Add(LangLine[20]);
end;
End;

Procedure SendPoolPing();
Begin
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(condata.pass+' '+userdata.address+' PING '+IntToStr(Velocidad));
      end
   else Processlines.Add(LangLine[19]);
Except On E:Exception do
   Processlines.Add(LangLine[21]);
end;
End;

Procedure TThreadReadPool.Execute();
var
  linea : string;
Begin
Reading := true;
if not canalpool.Connected then exit;
try
   if canalpool.IOHandler.InputBufferIsEmpty then
      begin
      canalpool.IOHandler.CheckForDataOnSource(10);
      if canalpool.IOHandler.InputBufferIsEmpty then
         begin
         Reading := false;
         Exit;
         end;
      end;
   While not canalpool.IOHandler.InputBufferIsEmpty do
      begin
      TRY
         canalpool.ReadTimeout:=2000;
         Linea := canalpool.IOHandler.ReadLn(IndyTextEncoding_UTF8);
         if canalpool.IOHandler.ReadLnTimedout then
            begin
            Reading := false;
            Form1.BitBtn2Click(Form1.BitBtn2);
            LaunchReconnection();
            exit;
            end;
      EXCEPT on E:Exception do
         begin
         Reading := false;
         Form1.BitBtn2Click(Form1.BitBtn2);
         LaunchReconnection();
         exit;
         end;
      END;
      ProcessLines.Add(linea);
      LastPingReceived := GetTime;
      end;
Except On E:Exception do
   begin
   Reading := false;
   Form1.BitBtn2Click(Form1.BitBtn2);
   LaunchReconnection();
   end;
end;
Reading := false;
End;

Procedure ProcessThisLine(Linea:string);
var
  steplength : integer;
  StepValue : integer;
Begin
if form1.checkboxMode.Checked then form1.Memo1.Lines.Add('>>'+linea);
if parameter(linea,0) = 'JOINOK' then
   begin
   Waitingforjoin:=0;
   form1.edit1.text:=parameter(linea,1);
   form1.edit2.text:=parameter(linea,2);
   showinfo(LangLine[22]);
   SaveDataFile;
   MinerAddress := parameter(linea,1);
   MinerPrefix := parameter(linea,2);
   ReadDataFromLine(linea);
   Reconnecting := false;
   StartMiners;
   end
else if parameter(linea,0) = 'PONG' then
   begin
   ReadDataFromLine(linea);
   end
else if parameter(linea,0) = 'JOINFAILED' then
   begin
   Showinfo(LangLine[23]);
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'PAYMENTOK' then
   begin
   showinfo( LangLine[24]+Int2curr(StrToInt64Def(Parameter(linea,1),0)) );
   earned := earned+StrToInt64Def(Parameter(linea,1),0);
   PaymentRequested := false;
   end
else if parameter(linea,0) = 'PASSFAILED' then
   begin
   ShowInfo(LangLine[25]);
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'POOLSTEPS' then
   begin
   ReadDataFromLine(linea);
   if foundedsteps = 0 then
      begin
      StartMiners();
      Setlength(arrnext,0)
      end
   else VerifyNext();
   end
else if parameter(linea,0) = 'PAYMENTFAIL' then
   begin
   PaymentRequested := false;
   end
else if parameter(linea,0) = 'INVALIDADDRESS' then
   begin
   ShowInfo(LangLine[64]);
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'ALREADYCONNECTED' then
   begin
   ShowInfo(LangLine[26]);
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'MYSTEP' then
   begin
   ThisStep := Parameter(Linea,1);
   StepLength := StrToIntDef(Parameter(Linea,2),-1);
   SendPoolStep(StepLength);
   ThisStep := '';
   end
else if parameter(linea,0) = 'NEXTSTEP' then
   begin
   end
else if parameter(linea,0) = 'STEPOK' then
   begin
   StepValue := StrToIntDef( parameter(linea,1),1);
   TotalFound := TotalFound+StepValue;
   PlayBeep;
   end
else //Showinfo('Unknown messsage from pool server');
   begin

   end;
end;

Procedure ReadDataFromLine(Linea:string);
var
  Nuevalinea : string = '';
  StartPos : integer = 0;
Begin
StartPos := Pos('PoolData',Linea);
Nuevalinea := Copy(Linea,Startpos,length(linea));
TargetBlock := StrToIntDef(Parameter(Nuevalinea,1),0);
TargetString := Parameter(Nuevalinea,2);
TargetChars := StrToIntDef(Parameter(Nuevalinea,3),0);
FoundedSteps := StrToIntDef(Parameter(Nuevalinea,4),0);
TargetDiff := StrToIntDef(Parameter(Nuevalinea,5),0);
balance := StrToInt64Def(Parameter(Nuevalinea,6),0);
lastpago := StrToIntDef(Parameter(Nuevalinea,7),0);
poolhashrate := StrToIntDef(Parameter(Nuevalinea,8),0);
PooDeepSteps := StrToIntDef(Parameter(Nuevalinea,9),3);
End;

END. // END APP

