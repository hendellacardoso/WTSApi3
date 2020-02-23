unit Principal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.Mask, Vcl.Buttons, Vcl.Menus,

  //Classe da API
  wts.API, System.Actions, Vcl.ActnList;

type
  TForm1 = class(TForm)
    Status: TStatusBar;
    TabControl: TPageControl;
    tabMensagem: TTabSheet;
    tabContatos: TTabSheet;
    Label1: TLabel;
    Label2: TLabel;
    botSelecionar: TSpeedButton;
    Label3: TLabel;
    botEnviar: TSpeedButton;
    Label4: TLabel;
    edtArquivo: TEdit;
    edtContato: TMaskEdit;
    edtMensagem: TMemo;
    listMSG: TListView;
    MainMenu1: TMainMenu;
    OpesdaAPI1: TMenuItem;
    Conectar1: TMenuItem;
    DefinirWebhook1: TMenuItem;
    N1: TMenuItem;
    Sair1: TMenuItem;
    OpenDialog1: TOpenDialog;
    Label5: TLabel;
    ListaContatos: TListView;
    botObterContatos: TButton;
    procedure botSelecionarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Conectar1Click(Sender: TObject);
    procedure botEnviarClick(Sender: TObject);
    procedure botObterContatosClick(Sender: TObject);
    procedure DefinirWebhook1Click(Sender: TObject);

  private
    { Private declarations }
    procedure AddMsg(Lista: TListView; Contato, Mensagem: String);
    procedure AddContato(Lista: TListView; Contato, Agenda, Pushname: String;
              MeuContato: Boolean);
    procedure AoConectarAPI(const msg: String);
    procedure AoReceberMSG(const id: Integer;const pushname,nome,contato,
              tipo,token,data,hora,mimetype,caption,mensagem: String);
    procedure AoReceberCT(const contato,agenda,pushname: String;
              const meucontato: Boolean);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
   API : TWTSApi;


implementation

{$R *.dfm}


{$REGION ' ADICIONAR MENSAGEM RECEBIDA NA LISTA '}
procedure TForm1.AddMsg(Lista: TListView; Contato, Mensagem: String);
begin
   With Lista.Items.Add do
   begin
      Caption := Contato;
      SubItems.Add(Mensagem);
   end;
end;
{$ENDREGION}


{$REGION ' ADICIOANR CONTATOS RECEBIDOS '}
procedure TForm1.AddContato(Lista: TListView; Contato, Agenda, Pushname: String;
              MeuContato: Boolean);
var
   S: String;
begin
   if MeuContato then
      S := 'Sim'
   else
      S := 'Não';
   With Lista.Items.Add do
   begin

      Caption := Contato;
      SubItems.Add(Agenda);
      SubItems.Add(Pushname);
      SubItems.Add(S);
   end;
end;
{$ENDREGION}


{$REGION ' SELECIONAR ARQUIVO PARA ENVIO '}
procedure TForm1.botSelecionarClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    if OpenDialog1.FileName <> '' then
    begin
      edtArquivo.Text := OpenDialog1.FileName;
    end;
  end;
end;
{$ENDREGION}


{$REGION ' EVENTO DA API AO CONECTAR API '}
procedure TForm1.AoConectarAPI(const msg: String);
begin

   if msg = 'Conectado' then
   begin
      Status.Panels[1].Text := 'Conectado';
      Status.Panels[3].Text := API.ObterNumeroConectado;
      Status.Panels[5].Text := API.ObterNivelBateria;
      Conectar1.Caption     := 'Desconectar';
      API.VerificaMensagens(true);
   end
   else
   begin
      Status.Panels[1].Text := 'Não conectado';
      Status.Panels[3].Text := '';
      Status.Panels[5].Text := '0%';
      Conectar1.Caption     := 'Conectar';
      API.VerificaMensagens(false);
      listMSG.Clear;
      ListaContatos.Clear;
   end;

end;
{$ENDREGION}


{$REGION ' AO RECEBER MENSAGENS '}
procedure TForm1.AoReceberMSG(const id: Integer; const pushname, nome, contato,
  tipo, token, data, hora, mimetype, caption, mensagem: String);
begin

   if (tipo='mensagem') or (tipo='resposta')  then
      AddMsg(listMSG, contato, mensagem);

end;
{$ENDREGION}


{$REGION ' AO RECEBER LISTA DE CONTATOS '}
procedure TForm1.AoReceberCT(const contato, agenda, pushname: String;
  const meucontato: Boolean);
begin
    AddContato(ListaContatos, contato, agenda, pushname, meucontato);
end;
{$ENDREGION}


{$REGION ' ENVIAR MENSAGEM '}
procedure TForm1.botEnviarClick(Sender: TObject);
var
   stMensagem: String;
begin

   if Application.MessageBox('Confirma o envio da mensagem?', 'Atenção!',
   mb_iconquestion + mb_yesno) = idYes then
   begin
      stMensagem := API.EnviarMensagem(edtContato.Text, edtArquivo.Text, edtMensagem.Text);
      Application.MessageBox(PChar(stMensagem),'Atenção!', MB_ICONINFORMATION);
      edtArquivo.Text  := '';
      edtMensagem.Text := '';
   end;

end;
{$ENDREGION}


{$REGION ' OBTER LISTA DE CONTATOS '}
procedure TForm1.botObterContatosClick(Sender: TObject);
begin
   ListaContatos.Clear;
   API.ObterContatos;
end;
{$ENDREGION}


{$REGION ' DEFINIR WEBHOOK '}
procedure TForm1.DefinirWebhook1Click(Sender: TObject);
var
   msg: String;
begin

   msg := API.DefinirWebHook('');
   Application.MessageBox(PChar(msg),'Atenção',MB_ICONINFORMATION);

end;
{$ENDREGION}


{$REGION ' CONECTAR / DESCONECTAR API '}
//Chama conectar/desconectar;
procedure TForm1.Conectar1Click(Sender: TObject);
begin

   if Status.Panels[1].Text = 'Conectado' then
   begin
      API.Desconectar;
   end
   else
   begin
      API.Conectar;
   end;

end;
{$ENDREGION}


{$REGION ' AO FECHAR O FORMULÁRIO '}
//Finaliza API ao fechar o form;
procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin

   if Assigned(API) then
      FreeAndNil(API);

end;
{$ENDREGION}


{$REGION ' AO CRIAR O FORMULÁRIO '}
//Configura API ao criar formulário;
procedure TForm1.FormCreate(Sender: TObject);
begin

   {$REGION ' CONFIGURAÇÕES DA API '}
      API := TWTSApi.Create;
      API.Endpoint          := '';
      API.Porta             := 0;
      API.Token             := '';
      API.Webhook           := '';
      API.AoConectar        := AoConectarAPI;
      API.AoReceberMensagem := AoReceberMSG;
      API.AoReceberContatos := AoReceberCT;
   {$ENDREGION}


   {$REGION ' VERIFICA SE JÁ ESTA CONECTADO '}
      API.EstaConectado;
   {$ENDREGION}

end;
{$ENDREGION}


end.
