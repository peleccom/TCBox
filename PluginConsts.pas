unit PluginConsts;

interface

const

  PLUGIN_TITLE_SHORT = 'TCBox';
  PLUGIN_VERSION_TEXT = '0.4beta';

  PLUGIN_HELLO_TITLE_SHORT = PLUGIN_TITLE_SHORT + ' ' + PLUGIN_VERSION_TEXT;
  ACESS_KEY_SIGNATURE_STRING = 'TCBox1_';
  PLUGIN_ACCESS_KEY_FILENAME = 'key.txt';
  PLUGIN_LOG_FILENAME = 'TCBOX.log';
  PLUGIN_SETTINGS_FILENAME = 'settings.ini';

resourcestring
  PLUGIN_TITLE = 'Total Commander Dropbox plugin';

function getPluginHelloTitle(): string;

implementation

function getPluginHelloTitle(): string;
begin
  Result := PLUGIN_TITLE + ' ' + PLUGIN_VERSION_TEXT;
end;

end.
