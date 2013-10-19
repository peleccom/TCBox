unit SettingUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, gnugettext, settings,
  pluginConsts, Vcl.XPMan, Vcl.Buttons, Log4D,DropboxSession;

type
  TSettingsForm = class(TForm)
    LanguagesComboBox: TComboBox;
    Label1: TLabel;
    LogOutButton: TButton;
    BitBtn1: TBitBtn;
    XPManifest1: TXPManifest;
    constructor Create(AOwner: TComponent; session: TDropboxSession;
      accessKeyFilename: string);
    procedure FormCreate(Sender: TObject);
    procedure LanguagesComboBoxChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LogOutButtonClick(Sender: TObject);
  private
    { Private declarations }
    languages: TStrings;
    logger: TLogLogger;
    session: TDropboxSession;
    accessKeyFileName: string;
    procedure fillComboBox();
    procedure loadFormIcon();
    // delete key.txt file
   function deleteKey(): boolean;
  public
    { Public declarations }
  end;

var
  SettingsForm: TSettingsForm;

implementation

{$R *.dfm}

procedure TSettingsForm.LogOutButtonClick(Sender: TObject);
begin
  if not deleteKey() then
    logger.Debug('Log out: key file not deleted');
  session.unlink();
  LogOutButton.Enabled := session.isLinked();
end;

constructor TSettingsForm.Create(AOwner: TComponent; session: TDropboxSession;
  accessKeyFilename: string);
begin
  inherited Create(AOwner);
  logger := TLogLogger.GetLogger('Default');
  self.session := session;
  self.accessKeyFilename := accessKeyFilename;
end;

function TSettingsForm.deleteKey: boolean;
begin
  Result := DeleteFile(accessKeyFilename);
end;

procedure TSettingsForm.fillComboBox;
begin
  LanguagesComboBox.Clear;
  languages.Clear;
  DefaultInstance.GetListOfLanguages('default', languages);
  LanguagesComboBox.Items.Assign(languages);
  DefaultInstance.BindtextdomainToFile('languagecodes',
    'c:\tmp\' + 'languagecodes.mo');
  DefaultInstance.TranslateProperties(LanguagesComboBox, 'languagecodes');
  DefaultInstance.TranslateProperties(LanguagesComboBox, 'languagenames');
  LanguagesComboBox.ItemIndex := languages.IndexOf(GetCurrentLanguage);
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  languages := TStringList.Create;
  TranslateComponent(Self);
  fillComboBox();
  loadFormIcon();
  Caption := PLUGIN_TITLE_SHORT + ' ' + _('settings');
  LogOutButton.Enabled := session.isLinked();
end;

procedure TSettingsForm.FormDestroy(Sender: TObject);
begin
  languages.Free;
end;

procedure TSettingsForm.LanguagesComboBoxChange(Sender: TObject);
var
  lang: string;
begin
  lang := languages[LanguagesComboBox.ItemIndex];
  UseLanguage(lang);
  GetSettings.setLangStr(lang);
  RetranslateComponent(Self);

end;

procedure TSettingsForm.loadFormIcon;
var
  mhIcon: integer;
begin
  mhIcon := LoadIcon(hInstance, 'MAINICON');
  if mhIcon > 0 then
  begin
    mhIcon := SendMessage(Handle, WM_SETICON, ICON_SMALL, mhIcon);
    if mhIcon > 0 then
      DestroyIcon(mhIcon);
  end;
end;

end.
