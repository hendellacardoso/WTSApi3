program Exemplo;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {Form1},
  wts.API in 'wts.API.pas',
  DelphiZXIngQRCode in 'DelphiZXIngQRCode.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
