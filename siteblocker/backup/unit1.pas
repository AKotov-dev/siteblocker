unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Buttons, Menus, XMLPropStorage,
  ComCtrls, Process, EditBtn, DefaultTranslator, LCLTranslator;

type

  { TMainForm }

  TMainForm = class(TForm)
    DictionaryCheck: TCheckBox;
    WorkLabel: TLabel;
    RestartBtn: TBitBtn;
    GroupBox3: TGroupBox;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    LanEdit: TEdit;
    GroupBox2: TGroupBox;
    OnlyWebCheck: TCheckBox;
    OpenDialog1: TOpenDialog;
    RestoreBtn: TBitBtn;
    SaveDialog1: TSaveDialog;
    StartTime: TTimeEdit;
    StaticText1: TStaticText;
    StopTime: TTimeEdit;
    WanEdit: TEdit;
    TuesdayCheck: TCheckBox;
    WednesdayCheck: TCheckBox;
    ThursdayCheck: TCheckBox;
    FridayCheck: TCheckBox;
    SaturdayCheck: TCheckBox;
    SundayCheck: TCheckBox;
    MondayCheck: TCheckBox;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    ListBox1: TListBox;
    AddItem: TMenuItem;
    RemoveItem: TMenuItem;
    LoadFromFileItem: TMenuItem;
    SaveToFileItem: TMenuItem;
    N2: TMenuItem;
    Panel1: TPanel;
    Panel2: TPanel;
    PopupMenu1: TPopupMenu;
    Splitter1: TSplitter;
    MainFormStorage: TXMLPropStorage;
    procedure AddItemClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RestartBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LoadFromFileItemClick(Sender: TObject);
    procedure MondayCheckChange(Sender: TObject);
    procedure RemoveItemClick(Sender: TObject);
    procedure RestoreBtnClick(Sender: TObject);
    procedure SaveToFileItemClick(Sender: TObject);
    procedure DaysCheck;
    procedure StartSpinEditKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure StartProcess(command: string);
    procedure CreateServices;
    procedure CreateCrontab;
    procedure RestoreCheck;

  private

  public

  end;

//Ресурсы перевода
resourcestring
  SDeleteConfiguration = 'Delete this record (s)?';
  SAppendRecord = 'Append a website';
  SRootRequires = 'Requires running from SuperUser!' + #13#10 + #13#10 +
    'Mageia Linux: su/password' + #13#10 + 'Linux Mint: sudo su/password';
  SNoPing = 'No Internet! PING is not responding!';
  STimeWrong = 'Wrong time range!';

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }


//Общая процедура запуска команд
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
    Screen.Cursor := crDefault;
  end;
end;

//Проверка /etc/crontab-orig и сервиса systemd
procedure TMainForm.RestoreCheck;
begin
  //Проверка созданных файлов
  if FileExists('/etc/systemd/system/site-blocker.service') or
    FileExists('/var/spool/cron/root') or
    FileExists('/var/spool/cron/crontabs/root') then
    RestoreBtn.Enabled := True
  else
    RestoreBtn.Enabled := False;
end;

//Делаем создаём сервис /etc/systemd/system/site-blocker.service
procedure TMainForm.CreateServices;
var
  S: TStringList;
begin
  try
    S := TStringList.Create;

    //Если нет, создаём и активируем сервис /etc/systemd/system/site-blocker.service
    if not FileExists('/etc/systemd/system/site-blocker.service') then
    begin
      S.Add('[Unit]');
      S.Add('Description=IPTables SiteBlocker Unit');
      S.Add('After=network-online.target');
      S.Add('Wants=network-online.target');
      S.Add('');
      S.Add('[Service]');
      S.Add('Type=oneshot');
      S.Add('ExecStart=/usr/local/bin/site-blocker.sh');
      S.Add('');
      S.Add('[Install]');
      S.Add('WantedBy=multi-user.target');
      S.SaveToFile('/etc/systemd/system/site-blocker.service');
      StartProcess('systemctl enable site-blocker.service');
    end;

    //Проверка состояния кнопки Restore
    RestoreCheck;

  finally
    S.Free;
  end;
end;

//Делаем план Crontab и активируем
procedure TMainForm.CreateCrontab;
var
  Days: string;
  S: TStringList;
begin
  try
    //Строка дней блокировки
    if MondayCheck.Checked then
      Days := Days + '1,';
    if TuesdayCheck.Checked then
      Days := Days + '2,';
    if WednesdayCheck.Checked then
      Days := Days + '3,';
    if ThursdayCheck.Checked then
      Days := Days + '4,';
    if FridayCheck.Checked then
      Days := Days + '5,';
    if SaturdayCheck.Checked then
      Days := Days + '6,';
    if SundayCheck.Checked then
      Days := Days + '7,';

    //Убираем последнюю запятую
    Days := Copy(Days, 1, Length(Days) - 1);

    //Пишем /var/spool/cron/root
    S := TStringList.Create;
    S.Add('SHELL=/bin/bash');
    S.Add('PATH=/sbin:/bin:/usr/sbin:/usr/bin');
    S.Add('MAILTO=root');
    S.Add('HOME=/');
    S.Add('');
    S.Add('# SiteBlocker plan-' + DateToStr(Now));
    S.Add(Copy(StartTime.Text, 4, 2) + ' ' + Copy(StartTime.Text, 1, 2) +
      ' * ' + Days + ' * /usr/local/bin/site-blocker.sh');
    S.Add(Copy(StopTime.Text, 4, 2) + ' ' + Copy(StopTime.Text, 1, 2) +
      ' * ' + Days + ' * /usr/local/bin/site-blocker.sh');
    //Пустая строка в конце обязательна! Иначе Cron не понимает...
    S.Add('');

    //RedHat или Debian...
    if DirectoryExists('/var/spool/cron/crontabs') then
    begin
      S.SaveToFile('/var/spool/cron/crontabs/root');
      StartProcess('chmod 600 /var/spool/cron/crontabs/root');
    end
    else
    begin
      S.SaveToFile('/var/spool/cron/root');
      StartProcess('chmod 600 /var/spool/cron/root');
    end;

  finally
    S.Free;
  end;

  StartProcess(
    '[[ $(systemctl list-units | grep "crond.service") ]] && systemctl restart crond.service || systemctl restart cron.service');
end;

//Состояние панели управления
procedure TMainForm.DaysCheck;
begin
  if (MondayCheck.Checked or TuesDayCheck.Checked or WednesDayCheck.Checked or
    ThursDayCheck.Checked or FridayCheck.Checked or SaturDayCheck.Checked or
    SunDayCheck.Checked) and ((LanEdit.Text <> '') and (WanEdit.Text <> '')) and
    (ListBox1.Count <> 0) then
    GroupBox3.Enabled := True
  else
    GroupBox3.Enabled := False;
end;

procedure TMainForm.StartSpinEditKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  key := $0;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  MainForm.Caption := Application.Title;

  //Рабочая директория в профиле
  if not DirectoryExists('/root/.siteblocker') then
    MkDir('/root/.siteblocker');

  MainFormStorage.FileName := '/root/.siteblocker/settings.ini';

  if FileExists('/root/.siteblocker/blacklist') then
    ListBox1.Items.LoadFromFile('/root/.siteblocker/blacklist');

  //Состояние кнопки Restore
  RestoreCheck;
end;

procedure TMainForm.LoadFromFileItemClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    ListBox1.Items.LoadFromFile(OpenDialog1.FileName);
    ListBox1.Items.SaveToFile('/root/.siteblocker/blacklist');

    DaysCheck;
  end;
end;

procedure TMainForm.MondayCheckChange(Sender: TObject);
begin
  DaysCheck;
end;

procedure TMainForm.RemoveItemClick(Sender: TObject);
var
  i: integer;
begin
  if MessageDlg(SDeleteConfiguration, mtConfirmation, [mbYes, mbNo], 0) = mrYes then

    //Удаление записей
    for i := -1 + ListBox1.Items.Count downto 0 do
      if ListBox1.Selected[i] then
        ListBox1.Items.Delete(i);

  ListBox1.Items.SaveToFile('/root/.siteblocker/blacklist');

  DaysCheck;
end;

procedure TMainForm.RestoreBtnClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  //Удаляем настройки планировщика (RedHat или Debian)
  if DirectoryExists('/var/spool/cron/crontabs') then
    DeleteFile('/var/spool/cron/crontabs/root')
  else
    DeleteFile('/var/spool/cron/root');

  StartProcess(
    '[[ $(systemctl list-units | grep "crond.service") ]] && systemctl restart crond.service || systemctl restart cron.service');

  //Удаляем сервис автозапуска и скрипт правил iptables
  StartProcess('systemctl disable site-blocker.service');
  StartProcess('rm -f /etc/systemd/system/site-blocker.service /usr/local/bin/site-blocker.sh');
  StartProcess('systemctl daemon-reload');

  //Включаем IPv6 (default)
  StartProcess('sysctl -w net.ipv6.conf.all.disable_ipv6=0; ' +
    'sysctl -w net.ipv6.conf.default.disable_ipv6=0; ' +
    'sysctl -w net.ipv6.conf.lo.disable_ipv6=0');

  //Возвращаем iptables в default, удаляем SET BLACKLIST (очистка и выключение форвардинга)
  StartProcess(
    'iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X; ' +
    'iptables -t mangle -F; iptables -t mangle -X; ipset -X blacklist; sysctl -w net.ipv4.ip_forward=0');

  StartProcess('iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT');

  //Проверка состояния кнопки Restore
  RestoreCheck;
  Screen.Cursor := crDefault;
end;

procedure TMainForm.SaveToFileItemClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
    ListBox1.Items.SaveToFile(SaveDialog1.FileName);
end;

//Добавление в список
procedure TMainForm.AddItemClick(Sender: TObject);
var
  Value: string;
begin
  Value := '';
  repeat
    if not InputQuery(SAppendRecord, '', Value) then
      Exit;
  until Trim(Value) <> '';

  ListBox1.Items.Append(Trim(Value));

  ListBox1.Items.SaveToFile('/root/.siteblocker/blacklist');

  DaysCheck;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  if ListBox1.Count > 0 then
    ListBox1.ItemIndex := 0;
end;

procedure TMainForm.RestartBtnClick(Sender: TObject);
var
  i: integer;
  Days: string;
  output: ansistring;
  S: TStringList;
begin
  //Перечитываем время (валидность, если ввод был ручным)
  StartTime.Refresh;
  StopTime.Refresh;

  //Проверяем время Начала < Окончания блокировки
  if StartTime.Time >= StopTime.Time then
  begin
    MessageDlg(STimeWrong, mtWarning, [mbOK], 0);
    Exit;
  end;

  //Показываем метку-прогресс
  WorkLabel.Visible := True;
  RestartBtn.Enabled := False;

  try
    Days := '';
    S := TStringList.Create;

    S.Add('#!/bin/bash');
    S.Add('');

    S.Add('#Параметры -----//------------------');
    S.Add('hstart="' + StartTime.Text + '"' +
      ' #Начало блокировки (час)');
    S.Add('hend="' + StopTime.Text + '"' +
      ' #Окончание блокировки (час)');
    S.Add('');

    S.Add('#Интерфейсы и пути');
    S.Add('wan="' + WanEdit.Text + '"');
    S.Add('lan="' + LanEdit.Text + '"');
    S.Add('#-----------------//----------------');
    S.Add('');

    S.Add('#Загрузка нужных модулей ядра');
    S.Add('modprobe ip_set; modprobe xt_string');
    S.Add('');

    S.Add('#Отключаем протокол IPv6');
    S.Add('sysctl -w net.ipv6.conf.all.disable_ipv6=1');
    S.Add('sysctl -w net.ipv6.conf.default.disable_ipv6=1');
    S.Add('sysctl -w net.ipv6.conf.lo.disable_ipv6=1');
    S.Add('');

    S.Add('#Включаем форвардинг пакетов IPv4');
    S.Add('sysctl -w net.ipv4.ip_forward=1');
    S.Add('');

    S.Add('#Текущий день недели находится в списке блокировки?');

    if MondayCheck.Checked then
      Days := Days + ' 1';
    if TuesdayCheck.Checked then
      Days := Days + ' 2';
    if WednesdayCheck.Checked then
      Days := Days + ' 3';
    if ThursdayCheck.Checked then
      Days := Days + ' 4';
    if FridayCheck.Checked then
      Days := Days + ' 5';
    if SaturdayCheck.Checked then
      Days := Days + ' 6';
    if SundayCheck.Checked then
      Days := Days + ' 7';

    S.Add('block_day="no"; for i in' + Days +
      '; do [[ "$i" = "$(date +%u)" ]] && block_day="yes"; done');
    S.Add('');

    S.Add('#Очистка iptables');
    S.Add('iptables -F; iptables -X');
    S.Add('iptables -t nat -F; iptables -t nat -X');
    S.Add('iptables -t mangle -F; iptables -t mangle -X');
    S.Add('');

    S.Add('#Всё, кроме INPUT');
    S.Add('iptables -P INPUT DROP; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT');
    S.Add('');

    S.Add('#Разрешаем lo и уже установленные соединения');
    S.Add('iptables -A INPUT -i lo -j ACCEPT');
    S.Add('iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT');
    S.Add('');

    S.Add('#Разрешаем пинг');
    S.Add('iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT');
    S.Add('iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT');
    S.Add('');

    S.Add('#Открываем SSH:22 + защита от брутфорса (3 попытки подключения => бан атакующего на 60 сек)');
    S.Add('iptables -A INPUT -p tcp --syn --dport 22 -m recent --name sshport --set');
    S.Add('iptables -A INPUT -p tcp --syn --dport 22 -m recent --name sshport --update --seconds 60 --hitcount 4 -j DROP');
    S.Add('');

    S.Add('#Разрешаем Samba, DHCP/DNS и SSH:22 (dnsmasq и openssh-server, если они будут)');
    S.Add('iptables -A INPUT -i $lan -p tcp -m multiport --dports 22,137:139,445 -j ACCEPT');
    S.Add('iptables -A INPUT -i $lan -p udp -m multiport --dports 137:139,445,53,67,68,1024:65535 -j ACCEPT');
    S.Add('');

    S.Add('#С XX:XX часов утра до NN:NN часов вечера пускать с ограничениями');
    S.Add('if [[ "$(date +%T)" > "$hstart" && "$(date +%T)" < "$hend" && "$block_day" = "yes" ]]; then');
    S.Add('');

    //Только Web-серфинг (блокировка VPN, Torrent, Jabber etc...)
    if OnlyWebCheck.Checked then
    begin
      S.Add('#Только Web-серфинг (блокировка VPN, Torrent Skype и т.д.)');
      S.Add('iptables -A FORWARD -i $lan -p udp ! --dport domain -j DROP');
      S.Add('iptables -A FORWARD -i $lan -p tcp -m multiport ! --dports http,https -j DROP');
      S.Add('');
    end;

    S.Add('#Блокировка IPSET по множеству IP-адресов');
    S.Add('[[ $(ipset -L) ]] || ipset -N blacklist iphash; ipset -F blacklist');
    S.Add('for site in $(cat /root/.siteblocker/blacklist); do');
    S.Add('   for ip in $(host $site | grep "has address" | cut -d " " -f4); do');
    S.Add('     ipset -A blacklist $ip');
    S.Add('   done');
    S.Add('done;');
    S.Add('iptables -A FORWARD -i $lan -m set --match-set blacklist dst -j REJECT');

    if DictionaryCheck.Checked then
    begin
      S.Add('');
      S.Add('#Блокировка STRING (словарная фильтрация)');
      for i := 0 to ListBox1.Count - 1 do
        S.Add('iptables -A FORWARD -i $lan -m string --string "' +
          ListBox1.Items[i] + '" --algo bm -j REJECT');
    end;
    S.Add('fi;');

    S.Add('');
    S.Add('#Секция маскардинга');
    S.Add('iptables -A FORWARD -i $wan -o $lan -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT');
    S.Add('iptables -A FORWARD -i $lan -o $wan -j ACCEPT');
    S.Add('iptables -t nat -A POSTROUTING -o $wan -j MASQUERADE');
    S.Add('');

    S.Add('exit 0;');

    //Сохраняем файл site-blocker.sh
    S.SaveToFile('/usr/local/bin/site-blocker.sh');

  finally;
    S.Free;
  end;

  //Проверяем PING (сеть доступна?)
  Application.ProcessMessages;
  RunCommand('bash', ['-c',
    'ERR=$(ping google.com -c 2 2>&1 > /dev/null) && echo "yes" || echo "no"'], output);

  //Ловим результат ping
  if Trim(output) <> 'yes' then
  begin
    MessageDlg(SNoPing, mtWarning, [mbOK], 0);
    WorkLabel.Visible := False;
    RestartBtn.Enabled := True;
    Exit;
  end
  else
  begin
    //Создаём новый план CRON
    CreateCrontab;

    //Создан ли сервис автозапуска? (возможно был Reset, пересоздать)
    CreateServices;

    //Делаем исполняемым и запускаем /usr/local/bin/site-blocker.sh
    StartProcess('chmod +x /usr/local/bin/site-blocker.sh; /usr/local/bin/site-blocker.sh');

    WorkLabel.Visible := False;
    RestartBtn.Enabled := True;
  end;
end;

end.
