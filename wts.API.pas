unit wts.API;

interface

uses
   Winapi.Windows,
   Winapi.Messages,
   System.SysUtils,
   System.Variants,
   System.Classes,
   Vcl.Graphics,
   Vcl.Controls,
   Vcl.Forms,
   Vcl.Dialogs,
   Vcl.ExtCtrls,
   IdComponent,
   IdTCPConnection,
   IdTCPClient,
   IdHTTP,
   IdMultipartFormData,
   IdAuthentication,
   System.NetEncoding,
   System.JSON,
   Vcl.StdCtrls,
   System.MaskUtils,
   Soap.EncdDecd;

type

   TEventoAoConectar = procedure(const msg: String) of object;
   TEventoAoReceberMensagem = procedure(const id: Integer;const pushname,nome,contato,
   tipo,token,data,hora,mimetype,caption,mensagem: String) of object;
   TEventoAoReceberContatos= procedure(const contato,agenda,pushname: String;const meucontato: Boolean) of object;

   TWTSApi = class
      private
         FToken: String;
         FWebhook: String;
         FPorta: Integer;
         FEndpoint: String;
         FAoConectar: TEventoAoConectar;
         FAoReceberMensagem: TEventoAoReceberMensagem;
         FAoReceberContatos: TEventoAoReceberContatos;
         procedure SetEndpoint(const Value: String);
         procedure SetPorta(const Value: Integer);
         procedure SetToken(const Value: String);
         procedure SetWebhook(const Value: String);
         procedure OnFormShow(Sender: TObject);
         function wtsGET(Endereco: String): String;
         function wtsPOST(endpoint,contato,mensagem,filename,base64,webhook:String):String;
         function SoNumero(fField : String): String;
         function CampoJSON(json, Tag: String): String;
         procedure CriarQRCode(Codigo: String);
         procedure OnImgPaint(Sender: TObject);
         procedure FinalizarT(Sender: TObject);
         procedure OnTrmTimer(Sender: TObject);
         procedure OnFrmClose(Sender: TObject; var Action: TCloseAction);
         function MaskCelular(mumero: String): String;
         function EncodeFile(const FileName: String): String;
         procedure OnTmsTimer(Sender: TObject);
         procedure VerificaConexao(Sender: TObject);
         var
            Frm : TForm;
            Img : TPaintBox;
            Pnl : TPanel;
            Tmr : TTimer;
            Lbl : TLabel;
            tMs : TTimer;
            tSC : TTimer;
            QRCodeBitmap: TBitmap;
      protected

      public
         property Endpoint: String read FEndpoint write SetEndpoint;
         property Porta: Integer read FPorta write SetPorta;
         property Token: String read FToken write SetToken;
         property Webhook: String read FWebhook write SetWebhook;
         procedure Conectar();
         procedure Desconectar();
         procedure Reiniciar();
         function ObterNumeroConectado(): String;
         function ObterNivelBateria(): String;
         function EstaConectado: Boolean;
         function EnviarMensagem(contato,arquivo,mensagem: String): String;
         procedure VerificaMensagens(Ativar: Boolean);
         procedure ObterContatos();
         function DefinirWebHook(webhook: String): String;
      published
         property AoConectar: TEventoAoConectar read FAoConectar write FAoConectar;
         property AoReceberMensagem: TEventoAoReceberMensagem read FAoReceberMensagem write FAoReceberMensagem;
         property AoReceberContatos: TEventoAoReceberContatos read FAoReceberContatos write FAoReceberContatos;
   end;

implementation

{ TWTSApi }

uses
   DelphiZXIngQRCode;



{ TWTSApi }

function TWTSApi.CampoJSON(json, Tag: String): String;
var
   LJSONObject: TJSONObject;
function TrataObjeto(jObj:TJSONObject):string;
var
   i:integer;
   jPar: TJSONPair;
begin
   result := '';
   for i := 0 to jObj.Count - 1 do
   begin
      jPar := jObj.Pairs[i];
      if jPar.JsonValue Is TJSONObject then
         result := TrataObjeto((jPar.JsonValue As TJSONObject)) else
      if sametext(trim(jPar.JsonString.Value),Tag) then
      begin
         Result := jPar.JsonValue.Value;
         break;
      end;
      if result <> '' then
         break;
   end;
end;
begin
   try
      LJSONObject := nil;
      LJSONObject := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(json),0)
      as TJSONObject;
      result := TrataObjeto(LJSONObject);
   finally
      LJSONObject.Free;
   end;
end;

procedure TWTSApi.CriarQRCode(Codigo: String);
var
   QRCode: TDelphiZXingQRCode;
   Row, Column: Integer;
begin

   try
      QRCode := TDelphiZXingQRCode.Create;
      try
         QRCode.Data := Codigo;
         QRCode.Encoding := TQRCodeEncoding(0);
         QRCode.QuietZone := StrToIntDef('4', 4);
         QRCodeBitmap.SetSize(QRCode.Rows, QRCode.Columns);
         for Row := 0 to QRCode.Rows - 1 do
         begin
            for Column := 0 to QRCode.Columns - 1 do
            begin
               if (QRCode.IsBlack[Row, Column]) then
               begin
                  QRCodeBitmap.Canvas.Pixels[Column, Row] := clBlack;
               end else
               begin
                  QRCodeBitmap.Canvas.Pixels[Column, Row] := clWhite;
               end;
            end;
         end;
      finally
         QRCode.Free;
      end;
      Img.Repaint;
   except
   end;
end;

function TWTSApi.DefinirWebHook(webhook: String): String;
var
   url : String;
begin
   url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/webhook';
   result := wtsPOST(url,'','','','',webhook);
end;

procedure TWTSApi.Desconectar();
var
   stJSON: String;
   url   : String;
begin
   url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/desconectar';
   stJSON := wtsGET(url);
   if stJSON = '' then
   begin
      raise Exception.Create('Não foi possível conectar!');
   end;
   FAoConectar('Não conectado');
end;

function TWTSApi.EncodeFile(const FileName: String): String;
var
  stream: TMemoryStream;
begin
  stream := TMemoryStream.Create;
  try
    stream.LoadFromFile(Filename);
    result := EncodeBase64(stream.Memory, stream.Size);
  finally
    stream.Free;
  end;
end;

function TWTSApi.EnviarMensagem(contato, arquivo, mensagem: String): String;
var
   jsonRetorno ,
   url         : String;
   fileName    ,
   fileBase64  : String;
begin

   url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/msg';

   //Remove quebras para evitar erros;
   mensagem := StringReplace(mensagem, #13, '\n', [rfReplaceAll] );
   mensagem := StringReplace(mensagem, #10, '', [rfReplaceAll] );

   //envio de mensagem;
   if arquivo = '' then
   begin
      url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/msg';
      jsonRetorno := wtsPOST(url, contato, mensagem,'','','');
      result := jsonRetorno;
   end
   else
   begin
      url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/arquivo';
      fileName   := ExtractFileName(arquivo);
      fileBase64 := EncodeFile(arquivo);
      fileBase64 := StringReplace(fileBase64, #13, '', [rfReplaceAll] );
      fileBase64 := StringReplace(fileBase64, #10, '', [rfReplaceAll] );
      jsonRetorno := wtsPOST(url, contato, mensagem, fileName, fileBase64,'');
      result := jsonRetorno;
   end;
end;

function TWTSApi.EstaConectado: Boolean;
var
   stJson : String;
   url    : String;
begin
   try
      url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/situacao';
      stJson := wtsGET(url);
      if stJSON = '' then
         result := false
      else
      if campoJSON(stJson,'retorno') = 'true' then
      begin
         FAoConectar('Conectado');
         if Assigned(tSC) then
            FreeAndNil(tSC);
         result := true;
      end
      else
      begin
         FAoConectar('Não conectado');
         result := false;
      end;
   except
      FAoConectar('Não conectado');
      result := false;
   end;
end;


procedure TWTSApi.FinalizarT(Sender: TObject);
begin
    if Assigned(TThread(Sender).FatalException) then
    begin
        lbl.Caption := Exception(TThread(Sender).FatalException).Message;
    end;
end;

function TWTSApi.MaskCelular(mumero: String): String;
begin
   Delete(mumero,ansipos('-',mumero),1);
   Delete(mumero,ansipos('-',mumero),1);
   Delete(mumero,ansipos('(',mumero),1);
   Delete(mumero,ansipos(')',mumero),1);
   if mumero.Length = 11 then
      Result:= FormatmaskText('\(00\)00000\-0000;0;',mumero)
   else
      Result:= FormatmaskText('\(00\)0000\-0000;0;',mumero);
end;

procedure TWTSApi.Conectar();
begin

   if EstaConectado then
   begin
      raise Exception.Create('API já conectada');
      abort;
   end;

   QRCodeBitmap := TBitmap.Create;

   Frm := TForm.Create(nil);
   Frm.Height      := 313;
   Frm.Width       := 270;
   Frm.BorderIcons := [biSystemMenu];
   Frm.BorderStyle := bsSingle;
   Frm.Position    := poMainFormCenter;
   Frm.Caption     := 'QrCode';
   Frm.OnShow      := OnFormShow;
   Frm.OnClose     := OnFrmClose;

   Lbl             := TLabel.Create(Frm);
   Lbl.AutoSize    := false;
   Lbl.Height      := 16;
   Lbl.Width       := 248;
   Lbl.Top         := 268;
   Lbl.Left        := 8;
   Lbl.Font.Size   := 10;
   Lbl.Font.Name   := 'Arial';
   Lbl.Caption     := 'Aguardando...';
   Lbl.Visible     := true;

   Pnl := TPanel.Create(Frm);
   Pnl.Height      := 250;
   Pnl.Width       := 250;
   Pnl.Parent      := Frm;
   Pnl.Top         := 8;
   Pnl.Left        := 8;
   Pnl.Color       := clWhite;
   Pnl.BevelInner  := bvRaised;
   Pnl.BevelOuter  := bvLowered;

   Img             := TPaintBox.Create(Frm);
   Img.Height      := 246;
   Img.Width       := 246;
   Img.Parent      := Pnl;
   Img.Top         := 2;
   Img.Left        := 2;
   Img.OnPaint     := OnImgPaint;

   Tmr             := TTimer.Create(Frm);
   Tmr.Interval    := 1000;
   Tmr.OnTimer     := OnTrmTimer;

   Frm.ShowModal;

end;

procedure TWTSApi.ObterContatos;
var
   T : TThread;
begin

   T := TThread.CreateAnonymousThread(
   procedure()
   var
      stJSON : String;
      jsonObj, jSubObj: TJSONObject;
      ja     : TJSONArray;
      jv     : TJSONValue;
      i      : Integer;
      cJSON  : String;
      url    : String;
      msgs   : String;
      ncont  : String;
   begin

      try

         url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/contatos';
         stJSON := wtsGET(url);
         if stJSON = '' then exit;

         jsonObj := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(stJSON), 0)
         as TJSONObject;

         jv := jsonObj.Get('retorno').JsonValue;
         ja := jv as TJSONArray;

         for i := 0 to ja.Size - 1 do
         begin

            jSubObj := (ja.Get(i) as TJSONObject);
            cJSON   := jSubObj.ToJSON;

            try

               if (SoNumero(CampoJSON(cJSON,'agenda')) =
                   SoNumero(CampoJSON(cJSON,'contato'))) then
                  ncont := ''
               else
                  ncont := CampoJSON(cJSON,'agenda');

               FAoReceberContatos(
                  MaskCelular(COPY(CampoJSON(cJSON,'contato'),3,11)),
                  ncont,
                  CampoJSON(cJSON,'pushname'),
                  StrToBool(CampoJSON(cJSON,'meucontato'))
               );

            except
            end;

         end;

      except
      end;

   end);
   T.Start;
end;

function TWTSApi.ObterNivelBateria: String;
var
   stJSON: String;
   URL   : String;
   nivel : String;
begin
   url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/bateria';
   stJSON := wtsGET(url);
   if stJSON = '' then
   begin
      result := '0%';
      exit;
   end;
   nivel := campoJSON(stJSON,'retorno');
   result :=  nivel + '%';
end;

function TWTSApi.ObterNumeroConectado: String;
var
   stJSON: String;
   URL   : String;
   numero: String;
begin
   url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/meunumero';
   stJSON := wtsGET(url);
   if stJSON = '' then
   begin
      raise Exception.Create('Não foi possível conectar!');
   end;
   numero := campoJSON(stJSON,'retorno');
   if numero.Length > 10 then
   numero := copy(numero,3,11);
   result :=  MaskCelular(numero);
end;


procedure TWTSApi.OnFormShow(Sender: TObject);
var
   T : TThread;
begin

   T := TThread.CreateAnonymousThread(procedure
   var
      Codigo: String;
      URL   : String;
      stJson: String;
   begin

      URL := FEndpoint + ':' + FPorta.ToString + '/whatsapp/qrcode';
      stJSON := wtsGET(URL);

      Codigo := campoJSON(stJSON,'retorno');

      if stJSON = '' then
      TThread.Synchronize(TThread.CurrentThread,
      procedure()
      begin
         Lbl.Caption := 'NÃO FOI POSSÍVEL CONECTAR';
         Lbl.Font.Color := clRed;
         raise Exception.Create('Não foi possível conectar');
      end);

      if campoJSON(stJSON,'mensagem') = 'Solicitando novo código' then
      begin
         TThread.Synchronize(TThread.CurrentThread,
         procedure()
         begin
            Lbl.Caption := 'Aguardando código...';
            Lbl.Font.Color := clGreen;
            Tmr.Enabled := true;
         end);
      end
      else
      begin
         TThread.Synchronize(TThread.CurrentThread,
         procedure()
         begin

            if (copy(Codigo,0,2) <> '1@') then
            begin
               Frm.Close;
            end
            else
            begin
               CriarQRCode(Codigo);
               Img.Repaint;
               Lbl.Caption := 'QrCode obtido com sucesso!';
               Tmr.Enabled := true;
            end;

         end);
      end;

   end);
   T.OnTerminate := FinalizarT;
   T.Start;

end;

procedure TWTSApi.OnFrmClose(Sender: TObject; var Action: TCloseAction);
begin

   tSC := TTimer.Create(nil);
   tSC.Interval := 1000;
   tSC.OnTimer  := VerificaConexao;
   tSC.Enabled  := true;

   if Assigned(Frm) then
   begin
      try
         EstaConectado;
         Frm.Visible := false;
         if Assigned(Lbl) then
            FreeAndNil(Lbl);
         if Assigned(Tmr) then
            FreeAndNil(Tmr);
         if Assigned(Pnl) then
            FreeAndNil(Pnl);
         if Assigned(Img) then
            FreeAndNil(Img);
         if Assigned(Frm) then
            FreeAndNil(Frm);
         if Assigned(QRCodeBitmap) then
            FreeAndNil(QRCodeBitmap);
         Frm.Close;
      except
         EstaConectado;
      end;
   end;
   EstaConectado;
end;

procedure TWTSApi.OnImgPaint(Sender: TObject);
var
  Scale: Double;
begin
   try
      Img.Canvas.Brush.Color := clWhite;
      Img.Canvas.FillRect(Rect(0, 0, Img.Width, Img.Height));
      if ((QRCodeBitmap.Width > 0) and (QRCodeBitmap.Height > 0)) then
      begin
         if (Img.Width < Img.Height) then
         begin
            Scale := Img.Width / QRCodeBitmap.Width;
         end else
         begin
            Scale := Img.Height / QRCodeBitmap.Height;
         end;
         Img.Canvas.StretchDraw(Rect(0, 0, Trunc(Scale * QRCodeBitmap.Width), Trunc(Scale * QRCodeBitmap.Height)), QRCodeBitmap);
      end;
   except
   end;
end;

procedure TWTSApi.OnTmsTimer(Sender: TObject);
var
   T : TThread;
begin

   T := TThread.CreateAnonymousThread(
   procedure()
   var
      stJSON : String;
      jsonObj, jSubObj: TJSONObject;
      ja     : TJSONArray;
      jv     : TJSONValue;
      i      : Integer;
      cJSON  : String;
      url    : String;
      msgs   : String;
   begin

      try

         url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/mensagens';
         stJSON := wtsGET(url);
         if stJSON = '' then exit;

         jsonObj := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(stJSON), 0)
         as TJSONObject;

         jv := jsonObj.Get('retorno').JsonValue;
         ja := jv as TJSONArray;

         for i := 0 to ja.Size - 1 do
         begin

            jSubObj := (ja.Get(i) as TJSONObject);
            cJSON   := jSubObj.ToJSON;

            try

               FAoReceberMensagem(
                  StrToInt(CampoJSON(cJSON,'id')),
                  CampoJSON(cJSON,'pushname'),
                  CampoJSON(cJSON,'nome'),
                  MaskCelular(COPY(CampoJSON(cJSON,'contato'),3,11)),
                  CampoJSON(cJSON,'tipo'),
                  CampoJSON(cJSON,'token'),
                  CampoJSON(cJSON,'data'),
                  CampoJSON(cJSON,'hora'),
                  CampoJSON(cJSON,'mimetype'),
                  CampoJSON(cJSON,'caption'),
                  CampoJSON(cJSON,'mensagem')
               );

            except
            end;

         end;

      except
      end;

   end);
   T.Start;

end;

procedure TWTSApi.OnTrmTimer(Sender: TObject);
begin
   if Not EstaConectado then
   begin
      OnFormShow(Sender);
   end
   else
   if Assigned(Frm) then
   begin
      Frm.Close;
   end;
end;

procedure TWTSApi.Reiniciar;
var
   stJSON: String;
   url   : String;
begin
   url := FEndpoint + ':' + FPorta.ToString + '/whatsapp/reiniciar';
   stJSON := wtsGET(url);
   if stJSON = '' then
   begin
      raise Exception.Create('Não foi possível reiniciar!');
   end;
end;

procedure TWTSApi.SetEndpoint(const Value: String);
begin
  FEndpoint := Value;
end;

procedure TWTSApi.SetPorta(const Value: Integer);
begin
  FPorta := Value;
end;

procedure TWTSApi.SetToken(const Value: String);
begin
  FToken := Value;
end;

procedure TWTSApi.SetWebhook(const Value: String);
begin
  FWebhook := Value;
end;


function TWTSApi.SoNumero(fField: String): String;
var
   i : Byte;
begin
   Result := '';
   for i := 1 To Length(fField) do
       if fField [I] In ['0'..'9'] Then
          Result := Result + fField [I];

end;

procedure TWTSApi.VerificaConexao(Sender: TObject);
begin
   EstaConectado;
end;

procedure TWTSApi.VerificaMensagens(Ativar: Boolean);
begin

   if Ativar then
   begin
      tMs := TTimer.Create(nil);
      tMs.Interval := 1000;
      tMs.OnTimer  := OnTmsTimer;
      tMs.Enabled  := true;
   end
   else
   begin
      if Assigned(tMs) then
         FreeAndNil(tMs);
   end;

end;

function TWTSApi.wtsGET(Endereco: String): String;
var
   sResponse : String;
   HTTP      : TIdHTTP;
   retorno   : Boolean;
begin
   try
      HTTP := TIdHTTP.Create;
      HTTP.Request.Method := 'GET';
      HTTP.Request.CustomHeaders.Values['token'] := FToken;
      try
         sResponse := HTTP.Get(Endereco);
      except
         on E: Exception do
         begin
            result := '';
         end;
      end;
      HTTP.Free;
      result := sResponse;
  except
      result := '';
  end;
end;

function TWTSApi.wtsPOST(endpoint,contato, mensagem, filename, base64,
  webhook: String): String;
var
   sResponse : String;
   dados: TStringStream;
   HTTP : TIdHTTP;
begin
   contato := SoNumero(Contato);
   if base64='' then
      dados := TStringStream.Create( UTF8Encode(mensagem) )
   else
      dados := TStringStream.Create( UTF8Encode(base64) );
   if webhook <>'' then
      dados := TStringStream.Create( UTF8Encode(webhook) );
   try
      HTTP := TIdHTTP.Create(nil);
      HTTP.Request.Method := 'POST';
      HTTP.Request.Clear;
      HTTP.Request.ContentType := 'text/plain';
      HTTP.Request.CharSet := 'UTF-8';
      HTTP.Request.CustomHeaders.Values['token'] := FToken;
      if filename<>'' then
         HTTP.Request.CustomHeaders.Values['filename'] := filename;
      if base64<>'' then
         HTTP.Request.CustomHeaders.Values['caption'] := UTF8Encode(mensagem);
      if contato <>'' then
         HTTP.Request.CustomHeaders.Values['contato'] := '55'+contato;
      try
         sResponse := HTTP.post(endpoint, dados );
      except
         on E: Exception do
         begin
            raise Exception.Create(e.ToString);
         end;
      end;
      result := CampoJSON(sResponse, 'mensagem');
  finally
      HTTP.Free;
      dados.Free;
  end;
end;




end.
