unit NosoMinerUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, Menus, IdTCPClient,IdGlobal, strutils, DCPsha256, nosominerutils,lclintf;

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

  type
  TMyThread = class(TThread)
    procedure Execute; override;
  end;



  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    CheckBox1: TCheckBox;
    ComboBox1: TComboBox;
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
Procedure ResetMinerData();
Procedure IncreaseHashSeed();
function ConnectPoolClient(Ip:String;Port:Integer;password:string;address:string):boolean;
Procedure DisconnectPoolClient();
Procedure PoolRequestMyStatus();
function PoolRequestMinerInfo():boolean;
Procedure SendPoolMessage(mensaje:string);
Procedure SendPoolStep();
Procedure SendPoolHashRate();
function PoolRequestPayment():boolean;
Procedure ReadPoolClientLines();
Function Parameter(LineText:String;ParamNumber:int64):String;
function Int2Curr(Value: int64): string;
function Sha256(StringToHash:string):string;
Procedure StopMiner();
Procedure Showinfo(Text:String);

Const
  DataFileName = 'minerdata.dat';
  minerversion = 'M1.3';
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

implementation

{$R *.lfm}

{ TForm1 }

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

// DATA FILE

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
dato.CTO:=500;
dato.RTO:=200;
UserData := dato;
write(datafile,dato);
closefile(datafile);
End;

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

procedure TForm1.MenuItem2Click(Sender: TObject);
begin
SaveDataFile();
end;

procedure TForm1.MenuItem3Click(Sender: TObject);
begin
if MessageDlg('Warning', 'Are you sure?', mtConfirmation,
   [mbYes, mbNo],0) = mrYes then
   begin
   CreateDataFile();
   LoadDataFile();
   end;
end;

procedure TForm1.MenuItem4Click(Sender: TObject);
begin
OpenDocument('https://nosocoin.blogspot.com/2021/03/nosominer-faq.html');
end;

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
showinfo('Closing');
Mineron := false;
sleep(100);
application.Terminate;
end;

Procedure SaveDataFile();
Begin
userdata.address:=form1.LabeledEdit2.Text;
userdata.ip:=form1.LabeledEdit1.Text;
userdata.port := StrToIntDef(form1.LabeledEdit3.Text,8082);
userdata.password:=form1.LabeledEdit4.Text;
userdata.cpus := form1.ComboBox1.ItemIndex+1;
assignfile(datafile,Datafilename);
rewrite(datafile);
write(datafile,UserData);
closefile(datafile);
End;

procedure TForm1.ComboBox1Change(Sender: TObject);
begin
userdata.cpus := form1.ComboBox1.ItemIndex+1;
SaveDataFile;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
showinfo('Closing');
Mineron := false;
sleep(100);
application.Terminate;
end;

// START

procedure TForm1.FormCreate(Sender: TObject);
var
  contador : integer;
begin
timer1.Enabled:=false;
timer2.Enabled:=false;
TimerClearInfo.Enabled:=false;
timerreconnect.Enabled:=false;
form1.Height:=207;
label2.Caption:='??';
label3.Caption:='0 Kh';
form1.Caption:='Noso Miner '+minerversion;
if GetEnvironmentVariable('NUMBER_OF_PROCESSORS') = '' then MaxCPU := 1
else MaxCPU := StrToInt(GetEnvironmentVariable('NUMBER_OF_PROCESSORS'));
setlength(MinerThreads,MaxCPU);
for contador := 1 to MaxCPU do
   begin
   ComboBox1.Items.Add(IntToStr(contador));
   end;
ComboBox1.ItemIndex:=combobox1.Items.Count-1;
if not fileexists(DataFileName) then CreateDataFile() else LoadDataFile();
if userdata.MinePrefix<>'' then MenuItem3.Enabled:=true
else MenuItem3.Enabled:=false;
CanalPool := TIdTCPClient.Create(form1);
end;

// EMPEZAR A MINAR

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
   velocidad := hashes*5 div 1000;
   label3.Caption:=inttoStr(velocidad)+' Kh';
   lastintervalo := esteintervalo;
   form1.Label4.Caption:='Block:'+IntToStr(Targetblock);{+' Target:'+copy(targetstring,1,targetchars)+slinebreak+
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
   if ((not PaymentRequested) and (PoolRequestPayment)) then
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
   resetminerdata();
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

procedure TForm1.Timer2Timer(Sender: TObject);
begin
form1.Timer2.Enabled:=false;
PoolRequestMyStatus();
PoolRequestMinerInfo();
end;

procedure TForm1.TimerClearInfoTimer(Sender: TObject);
begin
TimerClearInfo.Enabled:=false;
panel1.Caption:='';
panel1.visible := false;
end;

procedure TForm1.TimerReconnectTimer(Sender: TObject);
begin
form1.timerreconnect.Enabled:=false;
panel1.Caption:='Reconnecting in '+IntToStr(reconnecttime)+' seconds';
reconnecttime := reconnecttime-1;
if reconnecttime >0 then form1.timerreconnect.Enabled:=true
else
   begin
   panel1.Caption:='';
   BitBtn1Click(self);
   end;
end;

Procedure ResetMinerData();
Begin

End;

Procedure StartMiners();
var
  contador : integer;
Begin
form1.bitbtn1.Caption:='STOP';
if lastblock <> TargetBlock then MinerNumber := 99999999;
MinerSeed := userdata.MinePrefix;
MINERON := TRUE;
form1.Label4.Caption:='Block:'+IntToStr(Targetblock);{+' Target:'+copy(targetstring,1,targetchars)+slinebreak+
   'Chars: '+IntToStr(TargetChars)+' Step:'+IntToStr(foundedsteps)+' Found:'+IntToStr(Myfoundedsteps)+' Disc:'+IntToStr(DisConx);}
Cpusforminning := form1.ComboBox1.ItemIndex+1;
form1.memo1.Lines.Add('Starting '+inttoStr(Cpusforminning)+' cores');
form1.combobox1.Enabled:=false;
for contador := 0 to Cpusforminning-1 do
   begin
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
If canalpool.Connected then DisconnectPoolClient;
form1.combobox1.Enabled:=true;
End;

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
if not mineron then
   begin
   if not isvalidaddress(labelededit2.Text) then
      begin
      showinfo('Invalid Noso Address');
      exit;
      end;
   if not ConnectPoolClient(labelededit1.Text,StrToIntDef(labelededit3.Text,8082),labelededit4.Text,labelededit2.Text) then memo1.Lines.Add('Unable to connect')
   else Showinfo('Connected');
   if canalpool.Connected then
      begin
      timer1.Enabled:=true;
      if userdata.MineAddress = '' then
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

// MINER

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
      if parameter(linea,0) = 'JOINOK' then
         begin
         userdata.MineAddress:=parameter(linea,1);
         userdata.MinePrefix:=parameter(linea,2);
         showinfo('Joined the pool!');
         SaveDataFile();
         LoadDataFile();
         Form1.MenuItem3.Enabled:=true;
         PoolRequestMyStatus();
         PoolRequestMinerInfo();
         end
      else if parameter(linea,0) = 'JOINFAILED' then
         begin
         Showinfo('Probably the pool is full.');
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
         form1.Memo1.Lines.Add('Seems that your not registered in this pool.');
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
      else if parameter(linea,0) = 'UNREGISTERED' then
         begin

         end
      else form1.Memo1.Lines.Add('Unknown messsage from pool server: '+Linea);
      end;
Except On E:Exception do
   begin
   form1.Memo1.Lines.Add('Error reading pool client: '+E.Message);
   //DisconnectPoolClient();
   end;
end;
End;

// OTHER

// Devuelve un parametro del texto
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

Procedure Showinfo(Text:String);
Begin
form1.panel1.Caption:=text;
form1.Panel1.Width:=(length(text)*8);
form1.Panel1.left := 162 - (form1.Panel1.Width div 2);
form1.panel1.BringToFront;
form1.panel1.visible := true;
Form1.TimerClearInfo.Enabled:=true;
End;

// TRAY ICON

procedure TForm1.TrayIcon1DblClick(Sender: TObject);
begin
TrayIcon1.visible:=false;
Form1.WindowState:=wsNormal;
Form1.Show;
end;

procedure TForm1.FormWindowStateChange(Sender: TObject);
begin
if checkbox1.Checked then
   if Form1.WindowState = wsMinimized then
      begin
      TrayIcon1.visible:=true;
      form1.hide;
      end;
end;


END.

