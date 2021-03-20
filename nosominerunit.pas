unit NosoMinerUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, Menus, IdTCPClient, IdGlobal, strutils, nosominerutils,
  lclintf, ComCtrls, crt;

type

  MinerData = packed record
     address : string[35];
     ip : string[15];
     port: integer;
     password : string[10];
     cpus : integer;
     MineAddress : string[35];
     MinePrefix : string[9];
     CTO:integer;
     RTO:Integer
     end;

  PoolData = Packed record
     name : string[20];
     ip : string[15];
     port : integer;
     pass : string[20];
     end;
  type
  TMyThread = class(TThread)
    procedure Execute; override;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    ComboBox1: TComboBox;
    ComboPool: TComboBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
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
    Panel1: TPanel;
    Timer1: TTimer;
    Timer2: TTimer;
    TimerClearInfo: TTimer;
    TimerReconnect: TTimer;
    TrayIcon1: TTrayIcon;
    procedure BitBtn1Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure ComboPoolChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure MenuItem4Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure TimerClearInfoTimer(Sender: TObject);
    procedure TimerReconnectTimer(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
  private

  public

  end;

Procedure CreateDataFile();
Procedure LoadDataFile();
Procedure SaveDataFile();
Procedure StartMiners();
function ConnectPoolClient(Ip:String;Port:Integer;password:string;address:string):boolean;
Procedure DisconnectPoolClient();
Procedure PoolRequestMyStatus();
function PoolRequestMinerInfo():boolean;
Procedure SendPoolMessage(mensaje:string);
Procedure SendPoolStep();
Procedure SendPoolHashRate();
function PoolRequestPayment():boolean;
Procedure ReadPoolClientLines();
Procedure StopMiner();
Procedure KillMinerThreads();
Procedure LockControls();
Procedure UnLockControls();


Const
  DataFileName = 'minerdata.dat';
  PoolListFilename = 'poollist.txt';
  minerversion = 'M1.4';
  B58Alphabet : string = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

var
  Form1: TForm1;
  UserData :MinerData;
  Datafile : file of MinerData;
  MaxCPU : integer;
  CanalPool : TIdTCPClient;
  balance : int64 = 0;
  lastpago : integer;
  TargetBlock : integer = 0;
    lastblock : integer;
  TargetString: string = '';
  TargetChars: integer = 0;
  LaunchMiners :boolean = false;
  foundedsteps : integer;
  MinerSeed : string;
  MINERON : boolean = false;
  thisstep : string;
  MinerNumber : integer;
  lastintervalo : integer = 100000000;
  esteintervalo, hashes,velocidad : integer;
  minerspeed : integer;
  MinerThreads: array of TMyThread;
  Cpusforminning : integer;
  StopThreads : boolean = false;
  PoolHashRate : int64 = 0;
  Myfoundedsteps : integer = 0;
  reconnecttime : integer = 0;
  DisConx : integer = 0;
  PaymentRequested : boolean = false;
  KillThreads : boolean = false;
  PoolsList : array of pooldata;

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
timer1.Enabled:=false;
timer2.Enabled:=false;
TimerClearInfo.Enabled:=false;
timerreconnect.Enabled:=false;
form1.Height:=207;
if not fileexists(PoolListFilename) then CreatePoolList;
LoadPoolList;
label2.Caption:='';
label3.Caption:='0 Kh';

if GetEnvironmentVariable('NUMBER_OF_PROCESSORS') = '' then MaxCPU := 1
else MaxCPU := StrToInt(GetEnvironmentVariable('NUMBER_OF_PROCESSORS'));
setlength(MinerThreads,MaxCPU);
for contador := 1 to MaxCPU do
   ComboBox1.Items.Add(IntToStr(contador));

ComboBox1.ItemIndex:=combobox1.Items.Count-1;
if not fileexists(DataFileName) then CreateDataFile() else LoadDataFile();
if userdata.MinePrefix<>'' then MenuItem3.Enabled:=true
else MenuItem3.Enabled:=false;
if userdata.MinePrefix<>'' then
   begin
   form1.LabeledEdit1.Enabled:=false;
   form1.LabeledEdit2.Enabled:=false;
   form1.LabeledEdit3.Enabled:=false;
   form1.LabeledEdit4.Enabled:=false;
   form1.combopool.Enabled:=false;
   end;
CanalPool := TIdTCPClient.Create(form1);
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
userdata.cpus := form1.ComboBox1.ItemIndex+1;
SaveDataFile;
end;

// POOL SELECTION CHANGE
procedure TForm1.ComboPoolChange(Sender: TObject);
begin
LoadPool(ComboPool.ItemIndex);
end;

// ***MINER****

// EXECUTE
procedure TMyThread.Execute;
var
  solucion : string = '';
  Mseed,Mnumber : string;
begin
Repeat
InterLockedIncrement(MInerNumber);
if MinerNumber > 999999999 then
   begin
   IncreaseHashSeed;
   MinerNumber := 99999999;
   end;
Mseed := MinerSeed;Mnumber := IntToStr(MinerNumber);
Solucion := Sha256(Mseed+userdata.MineAddress+Mnumber);
if (AnsiContainsStr(Solucion,copy(TargetString,1,Targetchars))) then
   begin
   thisstep := Mseed+Mnumber;
   end;
until Not Mineron;
end;

// ***DATA FILE***

// CREATE
Procedure CreateDataFile();
var
  dato: MinerData;
Begin
assignfile(datafile,Datafilename);
rewrite(datafile);
dato.address:='';
dato.ip:='';
dato.port:=8082;
dato.password:='';
dato.cpus:=1;
dato.MineAddress:='';
dato.MinePrefix:='';
dato.CTO:=1000;
dato.RTO:=200;
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
form1.LabeledEdit1.Text:=userdata.ip;
form1.LabeledEdit3.Text:=IntToStr(userdata.port);
form1.LabeledEdit4.Text:=userdata.password;
if userdata.cpus > form1.ComboBox1.items.Count then form1.ComboBox1.ItemIndex:=form1.ComboBox1.items.Count-1
else form1.ComboBox1.ItemIndex:=userdata.cpus-1;
form1.Edit1.Text:=userdata.MineAddress;
form1.Edit2.Text:=userdata.MinePrefix;
End;

// SAVE
Procedure SaveDataFile();
Begin
userdata.address:=form1.LabeledEdit2.Text;
userdata.ip:=form1.LabeledEdit1.Text;
userdata.port := StrToIntDef(form1.LabeledEdit3.Text,8082);
userdata.password:=form1.LabeledEdit4.Text;
userdata.cpus := form1.ComboBox1.ItemIndex+1;
userdata.MineAddress:=form1.Edit1.Text;
userdata.MinePrefix:=form1.edit2.Text;
assignfile(datafile,Datafilename);
rewrite(datafile);
write(datafile,UserData);
closefile(datafile);
End;

// ***MAIN MENU***

// MAIN MENU : SAVE
procedure TForm1.MenuItem2Click(Sender: TObject);
begin
SaveDataFile();
end;

// MAIN MENU : EXIT POOL
procedure TForm1.MenuItem3Click(Sender: TObject);
begin
if MessageDlg('Warning', 'Are you sure?', mtConfirmation,
   [mbYes, mbNo],0) = mrYes then
   begin
   CreateDataFile();
   LoadDataFile();
   form1.LabeledEdit1.Enabled:=true;
   form1.LabeledEdit2.Enabled:=true;
   form1.LabeledEdit3.Enabled:=true;
   form1.LabeledEdit4.Enabled:=true;
   form1.combopool.Enabled:=true;
   end;
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

// ***TRAYICON***

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

// ***TIMERS***

// TIMER1: MINER INTERVAL (200)
procedure TForm1.Timer1Timer(Sender: TObject);
var
  contador : integer;
begin
timer1.Enabled:=false;
form1.TrayIcon1.Hint:='Not minning';
label2.Hint:='Blocks until pool payment';
if mineron then
   begin
   if not canalpool.Connected then ConnectPoolClient(userdata.ip,userdata.port,userdata.password,userdata.address);
   esteintervalo := MinerNumber;
   if esteintervalo > lastintervalo then hashes := esteintervalo - lastintervalo
   else hashes := esteintervalo + 900000000 - lastintervalo;
   velocidad := abs(hashes div 1000);
   if velocidad > MaxCPU*1000 then velocidad := 0;
   label3.Caption:=inttoStr(velocidad)+' Kh';
   lastintervalo := esteintervalo;
   form1.Label4.Caption:='Block:'+IntToStr(Targetblock)+' Step:'+IntToStr(foundedsteps);{+' Target:'+
   copy(targetstring,1,targetchars)+slinebreak+
   'Chars: '+IntToStr(TargetChars)+' Step:'+IntToStr(foundedsteps)+' Found:'+IntToStr(Myfoundedsteps)+' Disc:'+IntToStr(DisConx); }
   form1.Label5.Caption:= MinerSeed+IntToStr(MinerNumber);
   form1.Label6.Caption:='Pool:'+IntToStr(poolhashrate);
   if TargetBlock = 0 then PoolRequestMinerInfo();
   if form1.TrayIcon1.Visible then
      begin
      form1.TrayIcon1.Hint:='Minning power: '+IntToStr(velocidad)+' Kh';
      end;
   if lastpago > 0 then label2.Hint:='You can request a payment now';
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
edit3.Text:= Int2Curr(balance);
if canalpool.Connected then image1.Visible:=true
else image1.Visible:=false;
ReadPoolClientLines();
if ( (launchminers) and (not mineron) ) then StartMiners();
if thisstep <>'' then
   begin
   memo1.Lines.Add('Step Found');
   mineron := false;
   SendPoolStep;
   Myfoundedsteps +=1;
   thisstep := '';
   for contador := 1 to 10 do
      if PoolRequestMinerInfo() then break
      else
         begin
         StopMiner();
         reconnecttime := 5;
         form1.timerreconnect.Enabled:=true;
         panel1.Caption:='Reconnecting in '+IntToStr(reconnecttime)+' seconds';
         DisConx +=1;
         end;
   end;
timer1.Enabled:=true;
end;

// TIMER2: WAIT FOR NEW DATA (2000)
procedure TForm1.Timer2Timer(Sender: TObject);
begin
form1.Timer2.Enabled:=false;
PoolRequestMyStatus();
PoolRequestMinerInfo();
end;

// TIMERCLEAR INFO: REMOVE INFO PANEL (2000)
procedure TForm1.TimerClearInfoTimer(Sender: TObject);
begin
TimerClearInfo.Enabled:=false;
panel1.Caption:='';
panel1.visible := false;
end;

// TIMERRECONNECT: RECONNECT TO SERVER (1000x5)
procedure TForm1.TimerReconnectTimer(Sender: TObject);
begin
form1.timerreconnect.Enabled:=false;
panel1.Caption:='Reconnecting in '+IntToStr(reconnecttime)+' seconds';
reconnecttime := reconnecttime-1;
if reconnecttime >0 then form1.timerreconnect.Enabled:=true
else
   begin
   panel1.Caption:='';
   panel1.visible := false;
   BitBtn1Click(self);
   end;
end;


Procedure StartMiners();
var
  contador : integer;
Begin
LockControls;
form1.bitbtn1.Caption:='STOP';
form1.BitBtn1.Enabled:=true;
if lastblock <> TargetBlock then MinerNumber := 99999999;
MinerSeed := userdata.MinePrefix;
MINERON := TRUE;
form1.Label4.Caption:='Block:'+IntToStr(Targetblock)+' Step:'+IntToStr(foundedsteps);{+' Target:'+copy(targetstring,1,targetchars)+slinebreak+
   'Chars: '+IntToStr(TargetChars)+' Step:'+IntToStr(foundedsteps)+' Found:'+IntToStr(Myfoundedsteps)+' Disc:'+IntToStr(DisConx);}
Cpusforminning := form1.ComboBox1.ItemIndex+1;
form1.memo1.Lines.Add('Starting '+inttoStr(Cpusforminning)+' cores');
form1.combobox1.Enabled:=false;
mineron := false;
delay(10);
mineron := true;
for contador := 0 to Cpusforminning-1 do
   begin
   if assigned(MinerThreads[contador]) then MinerThreads[contador].Terminate;
   MinerThreads[contador] := TMyThread.Create(true);
   MinerThreads[contador].FreeOnTerminate:=true;
   MinerThreads[contador].Start;
   end;
lastblock := TargetBlock;
launchminers := false;
End;

Procedure StopMiner();
Begin
form1.bitbtn1.Caption:='Mine Noso';
Form1.label3.Caption := '0 Kh';
velocidad := 0;
mineron := false;
delay(10);
If canalpool.Connected then DisconnectPoolClient;
UnLockControls;
form1.BitBtn1.Enabled:=true;
End;

Procedure KillMinerThreads();
Begin

End;

Procedure LockControls();
Begin
form1.LabeledEdit1.Enabled:=false;
form1.LabeledEdit2.Enabled:=false;
form1.LabeledEdit3.Enabled:=false;
form1.LabeledEdit4.Enabled:=false;
form1.Label2.Visible:=true;
form1.Label3.Visible:=true;
form1.Label4.Visible:=true;
form1.Label6.Visible:=true;
form1.Edit3.Visible:=true;
form1.combobox1.Enabled:=false;
form1.combopool.Enabled:=false;
End;

Procedure UnLockControls();
Begin
if not (userdata.MineAddress<>'') then
   begin
   form1.LabeledEdit1.Enabled:=true;
   form1.LabeledEdit2.Enabled:=true;
   form1.LabeledEdit3.Enabled:=true;
   form1.LabeledEdit4.Enabled:=true;
   form1.combopool.Enabled:=true;
   end;
form1.Label2.Visible:=false;
form1.Label3.Visible:=false;
form1.Label4.Visible:=false;
form1.Label6.Visible:=false;
form1.Edit3.Visible:=false;
form1.combobox1.Enabled:=true;
End;

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
BitBtn1.Enabled:=false;
application.ProcessMessages;
if not mineron then
   begin
   userdata.address:=labelededit2.Text;
   UserData.ip:= labelededit1.Text;
   USerData.port := StrToIntDef(labelededit3.Text,8082);
   UserData.password:=labelededit4.Text;
   if length(userdata.address)<5 then
      begin
      showinfo('Invalid address');
      BitBtn1.Enabled:=true;
      exit;
      end;
   if not ConnectPoolClient(UserData.ip,USerData.port,UserData.password,UserData.address) then
      begin
      showinfo('Unable to connect');
      if checkbox2.Checked then beep;
      BitBtn1.Enabled:=true;
      end
   else Showinfo('Connected');
   if canalpool.Connected then
      begin
      timer1.Enabled:=true;
      if not IsValidAddress(userdata.MineAddress) then
         begin
         SendPoolMessage(userdata.password+' '+userdata.address+' JOIN');
         Showinfo('Join pool request sent');
         end
      else
         begin
         PoolRequestMyStatus();
         PoolRequestMinerInfo();
         end;
      end
   end
else
   begin
   StopMiner();
   end;
End;

// CLIENTE

function ConnectPoolClient(Ip:String;Port:Integer;password:string;address:string):boolean;
Begin
result := true;
if canalpool.Connected then exit;
CanalPool.Host:=Ip;
CanalPool.Port:=Port;
canalpool.ConnectTimeout:=UserData.CTO;
try
   canalpool.Connect;
   canalpool.IOHandler.WriteLn(password+' '+address);
Except on E:Exception do
   begin
   result := false;
   showinfo('Unable to connect to pool server');
   if form1.checkbox2.Checked then beep;
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
   form1.Memo1.Lines.Add('Error disconnecting pool client: '+E.Message);
   end;
END;
End;

Procedure PoolRequestMyStatus();
Begin
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(userdata.Password+' '+userdata.address+' STATUS');
      form1.Memo1.Lines.Add('Pool status request sent')
      end
   else form1.Memo1.Lines.Add('Can not connect to pool server');
Except On E:Exception do
   form1.Memo1.Lines.Add('Error pool status request: '+E.Message);
end;
End;

function PoolRequestMinerInfo():boolean;
Begin
result := false;
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(userdata.Password+' '+userdata.address+' MINERREQUEST '+minerversion);
      form1.Memo1.Lines.Add('Miner info requested');
      result := true
      end
   else form1.Memo1.Lines.Add('Can not request miner info');
Except On E:Exception do
   form1.Memo1.Lines.Add('Error pool requesting miner info: '+E.Message);
end;
End;

Procedure SendPoolMessage(mensaje:string);
Begin
try
   if canalpool.Connected then
      begin
      canalpool.IOHandler.WriteLn(mensaje);
      end;
Except On E:Exception do
   form1.memo1.Lines.Add('Error sending message to pool: '+E.Message);
end;
End;

Procedure SendPoolStep();
Begin
if not canalpool.Connected then ConnectPoolClient(userdata.ip,userdata.port,userdata.password,userdata.address);
try
   if CanalPool.Connected then
      SendPoolMessage(userdata.Password+' '+userdata.Address+' STEP '+IntToStr(targetblock)+' '+copy(thisstep,1,9)+' '+copy(thisstep,10,9))
   else form1.Memo1.Lines.Add('Can not send solution to pool');
Except On E:Exception do
   form1.Memo1.Lines.Add('Error sending solution: '+E.Message);
end;
End;

Procedure SendPoolHashRate();
Begin
try
   if CanalPool.Connected then
      SendPoolMessage(userdata.Password+' '+userdata.Address+' HASHRATE '+IntToStr(velocidad)+' '+minerversion)
   else form1.Memo1.Lines.Add('Can not send hashrate to pool');
Except On E:Exception do
   form1.Memo1.Lines.Add('Error sending pool hashrate: '+E.Message);
end;
End;

function PoolRequestPayment():boolean;
Begin
result := false;
try
   if CanalPool.Connected then
      begin
      SendPoolMessage(userdata.password+' '+userdata.address+' PAYMENT');
      Showinfo('Payment request sent');
      result:= true;
      end
   else Showinfo('Pool server is not connected');
Except On E:Exception do
   Showinfo('Pool payment request error');
end;
End;

Procedure ReadPoolClientLines();
var
  linea : string;
Begin
if not canalpool.Connected then exit;
try
   if canalpool.IOHandler.InputBufferIsEmpty then
      begin
      canalpool.IOHandler.CheckForDataOnSource(userdata.RTO);
      if canalpool.IOHandler.InputBufferIsEmpty then
         begin
         Exit;
         end;
      end;
   While not canalpool.IOHandler.InputBufferIsEmpty do
      begin
      TRY
         canalpool.ReadTimeout:=userdata.RTO;
         Linea := canalpool.IOHandler.ReadLn(IndyTextEncoding_UTF8);
         if canalpool.IOHandler.ReadLnTimedout then exit;
      EXCEPT on E:Exception do
         begin
         form1.Memo1.Lines.Add('Timeout error??');
         end;
      END;
      form1.memo1.Lines.Add(linea);
      if parameter(linea,0) = 'JOINOK' then
         begin
         form1.edit1.text:=parameter(linea,1);
         form1.edit2.text:=parameter(linea,2);
         showinfo('Joined the pool!');
         SaveDataFile();
         LoadDataFile();
         Form1.MenuItem3.Enabled:=true;
         PoolRequestMyStatus();
         PoolRequestMinerInfo();
         end
      else if parameter(linea,0) = 'JOINFAILED' then
         begin
         Showinfo('Probably this pool is full.');
         form1.BitBtn1.Enabled:=true;
         end
      else if parameter(linea,0) = 'JOINDONE' then
         begin
         form1.Memo1.Lines.Add('You are already registered in this pool.');
         end
      else if parameter(linea,0) = 'STATUSOK' then
         begin
         if Parameter(Linea,1) = userdata.address then
            begin
            balance := StrToInt64(parameter(linea,2));
            LastPago:= StrToInt64(parameter(linea,3));
            end;
         end
      else if parameter(linea,0) = 'STATUSFAILED' then
         begin
         form1.Memo1.Lines.Add('Critical error:STATUSFAILED');
         //DisconnectPoolClient();
         end
      else if parameter(linea,0) = 'MINERINFO' then
         begin
         form1.Memo1.Lines.Add('Pool info received');
         TargetBlock := StrToIntDef(parameter(linea,1),0);
         TargetString:= parameter(linea,2);
         TargetChars:= StrToIntDef(parameter(linea,3),0);
         foundedsteps := StrToIntDef(parameter(linea,4),0);
         if foundedsteps < 10 then LaunchMiners := true
         else
            begin
            mineron := false;
            form1.Timer2.Enabled:=true;
            end;
         end
      else if parameter(linea,0) = 'PAYMENTOK' then
         begin
         showinfo( 'Payment: Nos '+Int2curr(StrToIntDef(Parameter(linea,1),0)) );
         PoolRequestMyStatus();
         PaymentRequested := false;
         end
      else if parameter(linea,0) = 'PASSFAILED' then
         begin
         ShowInfo('Wrong pool password');
         form1.BitBtn1.Enabled:=true;
         end
      else if parameter(linea,0) = 'POOLSTEPS' then
         begin
         TargetBlock := StrToIntDef(parameter(linea,2),0);
         TargetString:= parameter(linea,3);
         TargetChars:= StrToIntDef(parameter(linea,4),0);
         foundedsteps := StrToIntDef(parameter(linea,1),0);
         if foundedsteps = 10 then
            begin
            mineron := false;
            form1.Timer2.Enabled:=true;
            end;
         if foundedsteps = 0 then
            begin
            mineron := false;
            form1.Timer2.Enabled:=false;
            StartMiners();
            end;
         end
      else if parameter(linea,0) = 'PAYMENTFAIL' then
         begin

         end
      else if parameter(linea,0) = 'HASHRATE' then
         begin
         PoolHashRate := StrToIntDef(parameter(Linea,1),0);
         balance := StrToInt64Def(parameter(linea,2),0);
         LastPago:= StrToInt64Def(parameter(linea,3),0);
         SendPoolHashRate();
         end
      else if parameter(linea,0) = 'INVALIDADDRESS' then
         begin
         ShowInfo('Your address is not valid');
         form1.BitBtn1.Enabled:=true;
         end
      else if parameter(linea,0) = 'ALREADYCONNECTED' then
         begin
         ShowInfo('Already connected to this pool');
         form1.BitBtn1.Enabled:=true;
         end
      else Showinfo('Unknown messsage from pool server');
      end;
Except On E:Exception do
   begin
   form1.Memo1.Lines.Add('Error receinving pool info');
   //DisconnectPoolClient();
   end;
end;
End;
//N3KghZ9cRasYyB7B2AuvuxWHf4gmoFL
END.

