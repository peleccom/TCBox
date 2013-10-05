unit LogInUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TLogInForm = class(TForm)
    SignOut: TButton;
    SignIn: TButton;
    AuthLabel: TLabel;
    Enter: TButton;
    procedure SignOutClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SignInClick(Sender: TObject);
    procedure EnterClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  LogInForm: TLogInForm;

implementation

{$R *.dfm}

procedure TLogInForm.SignInClick(Sender: TObject);
begin
  AuthLabel.Caption := 'Connected';
  SignIn.Visible := False;
  SignOut.Visible := True;
end;

procedure TLogInForm.SignOutClick(Sender: TObject);
begin
  AuthLabel.Caption := 'Disconnected';
  SignIn.Visible := True;
  SignOut.Visible := False;
end;

procedure TLogInForm.EnterClick(Sender: TObject);
begin
  ModalResult :=  mrOk;
end;

procedure TLogInForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

end.
