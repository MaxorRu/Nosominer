unit NosoMinerUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, Menus, IdTCPClient, IdGlobal, strutils, nosominerutils,
  lclintf, ComCtrls, Grids, crt;

type

  MinerData = packed record
     address : string[35];
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

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    ComboBox1: TComboBox;
    ComboPool: TComboBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
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
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
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
    procedure Button1Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure ComboPoolChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure MenuItem4Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
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
Procedure SendPoolStep();
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
  DataFileName = 'minerdata.dat';
  PoolListFilename = 'poollist.txt';
  minerversion = '1.63';
  B58Alphabet : string = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  OfficialRelease = true;

var
  Form1: TForm1;
  UserData :MinerData;                    // Data stored of the miner
  Datafile : file of MinerData;           // file with the data
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
  PoolPassword : String = '';

  Reconnecting : boolean = true;
  ReconTime : Integer = 5;


implementation

{$R *.lfm}

{ TForm1 }

// ***FORM 1***

// CREATE
procedure TForm1.FormCreate(Sender: TObject);
var
  contador : integer;
begin
form1.Caption:='Noso Miner '+minerversion;
PanelData.Top:=68;
TimerRecon.Enabled:=false;
TimerClearInfo.Enabled:=false;
if officialrelease then
   begin
   form1.Height:=207;
   form1.Width:=324;
   end;
if not fileexists(PoolListFilename) then CreatePoolList;
LoadPoolList;
label2.Caption:='';
label3.Caption:='0 Kh';
if GetEnvironmentVariable('NUMBER_OF_PROCESSORS') = '' then MaxCPU := 1
else MaxCPU := StrToInt(GetEnvironmentVariable('NUMBER_OF_PROCESSORS'));
setlength(MinerThreads,MaxCPU);
setlength(ArrMinerNums,MaxCPU);
GridCores.RowCount:=MaxCPU+1;
for contador := 1 to MaxCPU do
   ComboBox1.Items.Add(IntToStr(contador));
ComboBox1.ItemIndex:=combobox1.Items.Count-1;
if not fileexists(DataFileName) then CreateDataFile() else LoadDataFile();
CanalPool := TIdTCPClient.Create(form1);
ProcessLines := TStringList.Create;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
if FirstShow then
   begin
   Paneldata.Visible:=false;
   //showmessage('You can support the development of the Noso project (wallet, webpage and miner) joining the DevNoso pool');
   TimerLatido.Enabled:=true;
   end;
FirstShow := false;
end;

// CLOSE QUERY
procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
showinfo('Closing');
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
      ProcessLines.Add('MYSTEP '+Mseed+Mnumber);
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
  Deleted : boolean = false;
  ValidFound: boolean = false;
Begin
if length(arrnext)>0 then
   begin
   Counter := 0;
   While counter < length(arrnext)-1 do
      begin
      deleted := false;
      if arrnext[counter].Chars = Targetchars then
         begin
         ProcessLines.Add('MYSTEP '+arrnext[counter].seed+IntToStr(arrnext[counter].number));
         delete(ArrNext,counter,1);
         Deleted := true;
         ValidFound := true;
         end;
      if not deleted then counter +=1;
      end;
   if validfound then ShowInfo('VALID NEXT STEP SENT');
   end;
End;

// ***************
// ***DATA FILE***
// ***************

// CREATE
Procedure CreateDataFile();
var
  dato: MinerData;
Begin
assignfile(datafile,Datafilename);
rewrite(datafile);
dato.address:='';
UserData := dato;
write(datafile,dato);
closefile(datafile);
End;

// LOAD
Procedure LoadDataFile();
Begin
assignfile(datafile,Datafilename);
reset(datafile);
read(datafile,UserData);
closefile(datafile);
form1.LabeledEdit2.Text:=userdata.address;
End;

// SAVE
Procedure SaveDataFile();
Begin
userdata.address:=form1.LabeledEdit2.Text;
assignfile(datafile,Datafilename);
rewrite(datafile);
write(datafile,UserData);
closefile(datafile);
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
OpenDocument('https://nosocoin.blogspot.com/2021/03/nosominer-faq.html');
end;

// MAIN MENU : CLOSE
procedure TForm1.MenuItem5Click(Sender: TObject);
begin
showinfo('Closing');
Mineron := false;
sleep(100);
application.Terminate;
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
if processlines.Count>0 then
   begin
   ProcessThisLine(Processlines[0]);
   Processlines.Delete(0);
   end;
form1.TrayIcon1.Hint:='Not minning';
label2.Hint:='Blocks until pool payment';
if mineron then
   begin
   //if not canalpool.Connected then ConnectPoolClient();
   esteintervalo := GetMaximunCore div 1000;
   LastIntervalo := (GetTime-BlockSeconds)+1;
   velocidad :=  esteintervalo div LastIntervalo;
   Labvelocidad.Caption:=ShowHashrate(esteintervalo)+slinebreak+inttostr(lastintervalo)+' s';
   if not officialrelease then UpdateMinerNums;
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
      form1.TrayIcon1.Hint:='Minning power: '+IntToStr(velocidad)+' Kh';
   if lastpago > 0 then label2.Hint:='Your payment will be send as soon as you earn something';
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
      label2.Caption := 'Wait';
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
  form1.Memo1.Lines.Add('Reconnecting in '+IntToStr(ReconTime)+' seconds');
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
form1.memo1.Lines.Add('Starting '+inttoStr(Cpusforminning)+' cores');
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
PoolPassword := poolslist[ComboPool.ItemIndex].pass;
if length(userdata.address)<5 then
   begin
   showinfo('Invalid address');
   UnlockCOntrols;
   exit;
   end;
Connectionvalue := ConnectPoolClient();
if Connectionvalue = 0 then
   begin
   showinfo('Unable to connect');
   if checkbox2.Checked then PlayBeep;
   UnlockCOntrols;
   if reconnecting then LaunchReconnection();
   end
else if Connectionvalue = 10 then
   begin
   Showinfo('Connected');
   TimeStartMiner := GetTime;
   SendPoolMessage(PoolPassword+' '+userdata.address+' JOIN '+MinerVersion);
   Showinfo('Join pool request sent');
   Waitingforjoin := 5000;
   end
End;

procedure TForm1.BitBtn2Click(Sender: TObject);
begin
if not reconnecting then TimeStartMiner := 0;
StopMiner();
end;

// TEST BUTTON
procedure TForm1.Button1Click(Sender: TObject);
begin
mineron := false;
delay(100);
mineron := true;
end;

// CLIENTE

function ConnectPoolClient():Integer;
Begin
result := 0;
if canalpool.Connected then exit;
CanalPool.Host:=poolslist[form1.ComboPool.ItemIndex].ip;
CanalPool.Port:=poolslist[form1.ComboPool.ItemIndex].port;
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
   Processlines.Add('Error disconnecting pool client: '+E.Message);
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
   Processlines.Add('Error sending message to pool: '+E.Message);
end;
End;

Procedure SendPoolStep();
Begin
if not canalpool.Connected then ConnectPoolClient();
try
   if CanalPool.Connected then
      SendPoolMessage(PoolPassword+' '+userdata.Address+' STEP '+IntToStr(targetblock)+' '+copy(thisstep,1,9)+' '+copy(thisstep,10,9))
   else Processlines.Add('Can not send solution to pool');
Except On E:Exception do
   Processlines.Add('Error sending solution: '+E.Message);
end;
End;

function PoolRequestPayment():boolean;
Begin
result := false;
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(PoolPassword+' '+userdata.address+' PAYMENT');
      Processlines.Add('Payment request sent');
      result:= true;
      end
   else Processlines.Add('Pool server is not connected');
Except On E:Exception do
   Processlines.Add('Pool payment request error');
end;
End;

Procedure SendPoolPing();
Begin
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(PoolPassword+' '+userdata.address+' PING '+IntToStr(Velocidad));
      end
   else Processlines.Add('Pool server is not connected');
Except On E:Exception do
   Processlines.Add('Pool ping sent error');
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
   ProcessLines.Add('Error receinving pool info');
   DisconnectPoolClient();
   end;
end;
Reading := false;
End;

Procedure ProcessThisLine(Linea:string);
Begin
form1.Memo1.Lines.Add('>>'+linea);
if parameter(linea,0) = 'JOINOK' then
   begin
   Waitingforjoin:=0;
   form1.edit1.text:=parameter(linea,1);
   form1.edit2.text:=parameter(linea,2);
   showinfo('Joined the pool!');
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
   Showinfo('Probably this pool is full.');
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'PAYMENTOK' then
   begin
   showinfo( 'Payment: '+Int2curr(StrToInt64Def(Parameter(linea,1),0)) );
   PaymentRequested := false;
   end
else if parameter(linea,0) = 'PASSFAILED' then
   begin
   ShowInfo('Wrong pool password');
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'POOLSTEPS' then
   begin
   ReadDataFromLine(linea);
   if foundedsteps = 0 then
      begin
      StartMiners();
      end
   //else VerifyNext();
   end
else if parameter(linea,0) = 'PAYMENTFAIL' then
   begin
   PaymentRequested := false;
   end
else if parameter(linea,0) = 'INVALIDADDRESS' then
   begin
   ShowInfo('Your address is not valid');
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'ALREADYCONNECTED' then
   begin
   ShowInfo('Already connected to this pool');
   UnLockControls;
   if reconnecting then LaunchReconnection();
   end
else if parameter(linea,0) = 'MYSTEP' then
   begin
   ThisStep := Parameter(Linea,1);
   SendPoolStep();
   ThisStep := '';
   end
else if parameter(linea,0) = 'NEXTSTEP' then
   begin
   end
else if parameter(linea,0) = 'STEPOK' then
   begin
   TotalFound +=1;
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
End;

END. // END APP

